$allversions = @()
$allversions += Find-Module azurerm -RequiredVersion 3.7.0
$allversions += Find-Module azure -RequiredVersion 3.7.0
#$allversions += Find-Module AzureAD -RequiredVersion 2.0.0.55
#$allversions += Find-Module MSOnline -RequiredVersion  1.0
#$allversions += Find-Module azurestack -RequiredVersion 1.2.9
#$allversions += Find-Module AADRM -RequiredVersion 2.7.0.0
#$allversions += Find-Module ServiceFabric -RequiredVersion 3.1.0.0
$allversions | %{
  $item = New-Object -type psobject -prop ([ordered]@{
      Package = $_.Name + '-' + $_.Version
      Module  = ''
      Name    = ''
      Version = ''
  })
  $_.Dependencies | %{ 
    $item.Module = $_.Name + '-' + $_.RequiredVersion
    $dep = Find-Module $_.name -RequiredVersion $_.RequiredVersion
    $dep.dependencies | %{ 
      $item.Name    = $_.Name
      $item.Version = $_.RequiredVersion
      $item
    }
    if ($dep.dependencies.count -eq 0) {$item}
  }
  if ($_.dependencies.count -eq 0) {$item}
}
