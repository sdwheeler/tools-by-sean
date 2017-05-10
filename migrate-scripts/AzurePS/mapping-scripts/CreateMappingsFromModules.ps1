# Author: AaRoney.

# Define parameters.
param(
  [string] $folder
)

$scriptPath = (Get-Item $MyInvocation.MyCommand.Path).Directory.FullName
$WarningFile = 'groupMappingWarnings.json'
$RulesFile = "$scriptPath\CreateMappings_rules.json"

# Load rules file from JSON.
$rules = Get-Content -Raw -Path $RulesFile | ConvertFrom-Json

# Initialize variables.
$results = @{}
$warnings = @()

# Find all cmdlet names by help file names in the repository.
$cmdlets = @{}
$psd1files = dir "C:\temp\psgallery\$folder" -rec -inc *.psd1 | where {$_.name -notlike '*.dll-help.psd1' -and $_.name -ne 'AzureRM.psd1'}
foreach ($modfile in $psd1files) {
  $modcmdlet = (Get-Module -FullyQualifiedName $modfile.fullname -ListAvailable).ExportedCmdlets.Keys
  $modname = ($modfile.basename -split '\.')[-1]
  foreach ($cmd in $modcmdlet) {
    if (!$cmdlets.ContainsKey($cmd)) {
      $cmdlets.Add($cmd,$modname)
    }
  }
}

$k = 0
foreach ($cmd in $cmdlets.keys) {
  $cmdletPath = $cmdlets[$cmd]
  $cmdlet = $cmd

  # First, match to module path.
  $matchedRule = @($rules | Where-Object { $cmdletPath -cmatch ".*$($_.Regex).*" })[0]

  # Try to match this cmdlet with at least one rule.
  $possibleBetterMatch = @($rules | Where-Object { $cmdlet -cmatch ".*$($_.Regex).*" })[0]

#   $rules | Where-Object { $cmdlet -cmatch ".*$($_.Regex).*" } | ForEach-Object {
#     if ($matchedRule.group -eq $_.group) {
#       if ($possibleBetterMatch.Regex.length -lt $_.Regex.length) {
#         $possibleBetterMatch = $_
#       }
#     }
#   }

  # Look for a better match, but ensure that the groups match.
  if(($matchedRule.Group -ne $null) -and ($matchedRule.Group -eq $possibleBetterMatch.Group)) {
    $matchedRule = $possibleBetterMatch
  }

<#  if ($cmdlet.Contains('AzureRmVmss')) {
    $cmdlet
  }#>

  # Take note of unmatched cmdlets and write to outputs.
  if($matchedRule -eq $null) {
    $warnings += $cmdlet
    $results[$cmdlet] = "Other"
  } else {
    $results[$cmdlet] = $matchedRule.Alias
  }

  # Progress stuff.
  if($k % 100 -eq 0) {
    $percent = [math]::Floor($k / $cmdlets.Count * 100)
    Write-Progress -Activity "Processing cmdlets..." -Status "$($percent)%" -PercentComplete $percent
  }
  $k++
}

# Write to files.
$warnings | ConvertTo-Json | Out-File $WarningFile

$sorted = [ordered]@{}
$results.GetEnumerator() | sort Name | %{ $sorted.Add($_.name,$_.value) }
$sorted | convertto-json | out-file .\groupMapping-$folder.json -force -enc ascii

# Print conclusion.
Write-Host ""
Write-Host "$($results.Count) cmdlets successfully mapped: groupMapping-$folder.json." -ForegroundColor Green
Write-Host "$($warnings.Count) cmdlets could not be mapped and were placed in 'Other': $($WarningFile)." -ForegroundColor Yellow
Write-Host ""
