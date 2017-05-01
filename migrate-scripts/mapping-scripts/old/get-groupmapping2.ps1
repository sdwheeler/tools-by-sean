[CmdletBinding()]
param([string]$folder)

$rules = [ordered]@{}
$r = gc C:\temp\psgallery\CreateMappings_rules.json | ConvertFrom-Json
$r | %{ $rules.Add($_.regex,$_.alias) }

function getGroup {
    param($cmdletname)
    foreach ($regex in $rules.Keys) {
        if ($cmdletname.Contains($regex)) {
            $group = $rules[$regex]
            break
        }
    }
    Write-Output $group
}

$mamlFiles = dir "C:\temp\psgallery\$folder" -rec -inc *.dll-help.xml
$map = [ordered]@{}
foreach ($mamlfile in $mamlFiles) {
  $cmdfolder = $mamlfile.Directory.Parent.Name.Replace('Azure.','')
  $cmdfolder = $cmdfolder.Replace('AzureRM.','')
  $maml = [xml](gc $mamlfile)
  foreach ($cmd in $maml.helpItems.command) {
    $group = ''
    $cmdletname = $cmd.details.name.trim()
    $group = getGroup $cmdletname
    if ($group -eq '') { $group = $cmdfolder }
    if ($map.Contains($cmdletname)) {
      $map[$cmdletname]=$group
    } else {
      $map.Add($cmdletname,$group)
    }
  }
}

$map | convertto-json | out-file .\groupMapping-$folder.json -force -enc ascii
