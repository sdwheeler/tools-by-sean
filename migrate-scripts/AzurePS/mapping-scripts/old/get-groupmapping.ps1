$mamlFiles = dir 'C:\temp\psgallery\azurerm-1.2.9' -rec -inc *.dll-help.xml
$map = [ordered]@{}
foreach ($mamlfile in $mamlFiles) {
  $group = $mamlfile.Directory.Parent.Name.Replace('Azure.','')
  $group = $group.Replace('AzureRM.','')
  $maml = [xml](gc $mamlfile)
  foreach ($cmd in $maml.helpItems.command) {
    $cmdletname = $cmd.details.name.trim()
    if ($map.Contains($cmdletname)) {
      $map[$cmdletname]=$group
    } else {
      $map.Add($cmdletname,$group)
    }
  }
}

$map | convertto-json | out-file .\groupMapping-azurerm-1.2.9.json -force -enc ascii
