[CmdletBinding()]
param([string]$folder)

function getGroup {
  param($cmdletname)
  $group = ''
  $matchedrules = @($rules | where { $cmdletname -cmatch ".*$($_.Regex).*" })
  $matchweight = 0
    
  foreach ($rule in $matchedrules) {
    if ($rule.regex.length -ge $matchweight) {
      $group = $rule.alias
      $matchweight = $rule.regex.length
    }
  }
  Write-Output $group
}

Write-Host 'Load group mapping rules'
$rules = gc 'C:\Git\CSIStuff\tools-by-sean\migrate-scripts\mapping-scripts\CreateMappings_rules.json' | ConvertFrom-Json

Write-Host 'Find all modules'
$modules = @()
$psd1files = dir "C:\temp\psgallery\$folder" -rec -inc *.psd1
foreach ($modfile in $psd1files) {
  $modules += Get-Module -FullyQualifiedName $modfile.fullname -ListAvailable
}

$map = @{}

Write-Host 'Map cmdlets to groups'
foreach ($module in $modules) {
  $modname = ($module.Name -split '\.')[-1]
  foreach ($cmd in $module.ExportedCmdlets.Keys) {
    if (!$map.ContainsKey($cmd)) { 
      $map.Add($cmd,$modname)
    }
    $group = getGroup $cmd
    if ($group -ne '') {
      $map[$cmd]=$group
    } else {
      write-host $cmd
    }
  }
}

$sorted = [ordered]@{}
$map.GetEnumerator() | sort Name | %{ $sorted.Add($_.name,$_.value) }
$sorted | convertto-json | out-file .\groupMapping-$folder.json -force -enc ascii
