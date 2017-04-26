[CmdletBinding()]
param([string]$folder)

function getGroup {
  param($cmdletname)
  $group = ''
  foreach ($regex in $rules.Keys) {
    if ($cmdletname.Contains($regex)) {
      $group = $rules[$regex]
      break
    }
  }
  Write-Output $group
}

# Load group mapping rules
$rules = [ordered]@{}
$r = gc C:\temp\psgallery\CreateMappings_rules.json | ConvertFrom-Json
$r | %{ $rules.Add($_.regex,$_.alias) }

# Load cmdlet names from modules
$modules = @()
$psd1files = dir "C:\temp\psgallery\$folder" -rec -inc *.psd1
foreach ($modfile in $psd1files) {
#  if ($modfile.Directory.Parent.Name -eq $modfile.basename) {
  if ($modfile.Directory.Name -eq $modfile.basename) {
    $modules += Get-Module -FullyQualifiedName $modfile.fullname -ListAvailable
  }
}

$map = [ordered]@{}

foreach ($module in $modules) {
  $modname = ($module.Name -split '\.')[-1]
  foreach ($cmd in $module.ExportedCmdlets.Keys) {
    $map.Add($cmd,$modname)
    $group = getGroup $cmd
    if ($group -ne '') {
      $map[$cmd]=$group
    } else {
      write-host $cmd
    }
  }
}

$map | convertto-json | out-file .\groupMapping-$folder.json -force -enc ascii
