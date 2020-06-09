########################################################
#region Initialize Environment
########################################################
Add-Type -Path 'C:\Program Files\System.Data.SQLite\2015\GAC\System.Data.SQLite.dll'
Import-Module sdwheeler.utilities
Import-Module FXPSYaml
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
$env:_NT_SYMBOL_PATH='srv*D:\Symbols\public*http://msdl.microsoft.com/download/symbols'

If ([System.Windows.Input.Keyboard]::IsKeyDown('Ctrl') -eq $false)
{
   Start-Steroids
}
#endregion
