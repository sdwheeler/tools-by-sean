$version = '3.8.0'
$jsonFile = ".\monikerMapping-azurerm-3.8.0.json"
$map = [ordered]@{}

$modules = @()
#$modules += Find-Module azurestack -RequiredVersion $version
#$modules += Find-Module AzureRM.Bootstrapper -RequiredVersion 0.1.0
$modules += Find-Module azurerm -RequiredVersion $version

$modMap = [ordered]@{}

foreach ($module in $modules) {

  $module | Select-Object Name,Version

  $modMap.Add($module.Name,([ordered]@{_displayName=$module.name;_version=$module.Version.toString()}))

  $module.Dependencies | %{
    if (([hashtable]$_).ContainsKey('RequiredVersion')) {
      $mver = $_.RequiredVersion
    } else {
      $mver = $_.MinimumVersion
    }
    if (!($modMap.Contains($_.Name))) {
      $modMap.Add($_.Name,([ordered]@{_displayName=$_.name;_version=$mver}))
    }
    $submodule = Find-Module $_.Name -RequiredVersion $mver
    foreach ($subdepend in $submodule.Dependencies) {
      if (([hashtable]$subdepend).ContainsKey('RequiredVersion')) {
        $submver = $_.RequiredVersion
      } else {
        $submver = $_.MinimumVersion
      }
      if (!($modMap.Contains($submodule.Name))) {
        $modMap.Add($subdepend.Name,([ordered]@{_displayName=$subdepend.name;_version=$submver}))
      }
    }
  }
}
$map.Add("azurerm-$version",@{'azure-docs-powershell/azureps-cmdlets-docs/reourcemanager'=$modMap})

$map | ConvertTo-Json -Depth 4 | Out-File $jsonFile -Force -Encoding ascii