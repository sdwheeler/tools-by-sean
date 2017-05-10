$mamlFiles = dir 'C:\temp\psgallery\azure-4.0.0' -rec -inc *.dll-help.xml
$map = [ordered]@{}
foreach ($mamlfile in $mamlFiles) {
  $group = $mamlfile.Directory.Name
  if ($group -eq '3.0.0') { $group = $mamlfile.Directory.Parent.Name }
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

$sorted = [ordered]@{}
$map.GetEnumerator() | sort Name | %{ $sorted.Add($_.name,$_.value) }
$sorted | convertto-json | out-file .\groupMapping-azure-4.0.0.json -force -enc ascii