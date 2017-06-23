$versions = '4.1.0','3.8.0','2.2.0','1.7.0','1.2.9'
$jsonFile = ".\monikerMapping-azurermps.json"
$map = [ordered]@{}

foreach ($version in $versions) {
  $modMap = @{}

  $module = Find-Module azurerm -RequiredVersion $version
  $module | Select-Object Name,Version

  $module.Dependencies | %{
    $modMap.Add($_.Name,([ordered]@{_displayName=$_.name;_version=$_.RequiredVersion}))
  }

  $map.Add("azrmps-$version",@{'azure-docs-powershell/azureps-cmdlets-docs/ResourceManager'=$modMap})
}
$map | ConvertTo-Json -Depth 4 | Out-File $jsonFile -Force -Encoding ascii

$versions = '4.1.0','3.8.0','2.2.0','1.7.0','1.2.9'
$jsonFile = ".\monikerMapping-azuresmps.json"
$map = [ordered]@{}

foreach ($version in $versions) {
  $modMap = @{}

  $module = Find-Module azure -RequiredVersion $version
  $module | Select-Object Name,Version

  $module.Dependencies | %{
    if (([hashtable]$_).ContainsKey('RequiredVersion')) {
      $mver = $_.RequiredVersion
    } else {
      $mver = $_.MinimumVersion
    }

    $modMap.Add($_.Name,([ordered]@{_displayName=$_.name;_version=$mver}))
    $submodule = Find-Module $_.Name -RequiredVersion $mver
    foreach ($subdepend in $submodule.Dependencies) {
      if (([hashtable]$subdepend).ContainsKey('RequiredVersion')) {
        $submver = $_.RequiredVersion
      } else {
        $submver = $_.MinimumVersion
      }
      $modMap.Add($subdepend.Name,([ordered]@{_displayName=$subdepend.name;_version=$submver}))
    }
  }
  $map.Add("azsmps-$version",@{'azure-docs-powershell/azureps-cmdlets-docs/servicemanagement'=$modMap})
}
$map | ConvertTo-Json -Depth 4 | Out-File $jsonFile -Force -Encoding ascii