########################################################
#region Initialize Environment
########################################################
if ($PSVersionTable.PSVersion.Major -ge 6) {
  Add-WindowsPSModulePath
  $taglib = "$env:USERPROFILE\Documents\PowerShell\modules\TagLib\Libraries\TagLibSharp.dll"
  $null = [Reflection.Assembly]::LoadFrom($taglib)
}
Add-Type -Path 'C:\Program Files\System.Data.SQLite\netstandard2.0\System.Data.SQLite.dll'
Import-Module $env:USERPROFILE\Documents\PowerShell\modules\sdwheeler.utilities -WarningAction SilentlyContinue

#endregion
#-------------------------------------------------------
#region Aliases & Globals
#-------------------------------------------------------
if (!(Test-Path HKCR:)) { $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT }
if (!(Test-Path HKU:)) { $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS }

$global:ps2onWin7    = 'ps2onWin7.usdodeast.cloudapp.usgovcloudapi.net'     # 52.181.177.2
$global:ps3onWin2012 = 'ps3onWin2012.usdodeast.cloudapp.usgovcloudapi.net'  # 52.181.181.173
$global:ps4onwin8    = 'ps4onwin8.usdodeast.cloudapp.usgovcloudapi.net'     # 52.181.177.106
$global:ps5onwin10   = 'ps5onwin10.usdodeast.cloudapp.usgovcloudapi.net'    # 52.181.183.136
$global:ps51onwin10  = 'ps5-1onwin10.usdodeast.cloudapp.usgovcloudapi.net'  # 52.181.201.19
$global:psvmcred     = New-Object pscredential -ArgumentList "xAdministrator", ('Gh0$t!nTh3$h3ll' | ConvertTo-SecureString -AsPlainText -Force)
function psvm {
  param(
    [ValidateSet('ps2onWin7', 'ps3onWin2012', 'ps4onwin8', 'ps5onwin10', 'ps5-1onwin10', ignorecase=$true)]
    [Parameter(Mandatory=$true)]
    [string]$hostname
  )
  $s = New-PSSession -ComputerName "$hostname.usdodeast.cloudapp.usgovcloudapi.net" -Credential $psvmcred -UseSSL
  $s
}
#endregion
#-------------------------------------------------------
#region Git setup
$env:GITHUB_ORG     = 'MicrosoftDocs'
$env:GITHUB_USER    = 'sdwheeler'

$global:gitRepoRoots = 'C:\Git\My-Repos', 'C:\Git\PS-Docs', 'C:\Git\PS-Loc', 'C:\Git\PS-Src',
  'C:\Git\AzureDocs', 'C:\Git\Windows', 'C:\Git\APEX', 'C:\Git\PS-Other'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module posh-git
Set-Location C:\Git

if ($env:SKIPREPOS -ne 'True') {
  get-myrepos
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    get-repostatus
  }
}
$env:SKIPREPOS = $True
#-------------------------------------------------------
$GitPromptSettings.WindowTitle = {
  param($GitStatus, [bool]$IsAdmin)
  "$(if ($IsAdmin) {'Admin: '})$(if ($GitStatus) {
    "$($GitStatus.RepoName) [$($GitStatus.Branch)]"
  } else {
    Get-PromptPath
  }) ~ PSv$($PSVersionTable.PSVersion) $([IntPtr]::Size * 8)-bit ($PID)"
}
$GitPromptSettings.DefaultPromptPath = '[$(get-date -format "ddd hh:mm:sstt")]'
$GitPromptSettings.DefaultPromptWriteStatusFirst = $false
$GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`nPS $(Get-PromptPath)'
$GitPromptSettings.DefaultPromptBeforeSuffix.ForegroundColor = 'White'
$GitPromptSettings.DefaultPromptSuffix = '$(">" * ($nestedPromptLevel + 1)) '

# PSReadLine settings

Set-PSReadLineOption -ContinuationPrompt "  " -Colors @{ Operator = "`e[95m"; Parameter = "`e[95m" }

function Swap-Prompt {
  if ($function:prompt.tostring().length -gt 100) {
    $function:prompt = { 'PS> ' }
  } else {
    $function:prompt = $GitPromptScriptBlock
  }
}
#endregion
#-------------------------------------------------------
#region Helper functions
#-------------------------------------------------------
function epro {
  copy $env:USERPROFILE\AppData\Roaming\Code\User\settings.json C:\Git\My-Repos\tools-by-sean\modules
  copy $env:USERPROFILE\AppData\Roaming\Code\User\keybindings.json C:\Git\My-Repos\tools-by-sean\modules
  copy $env:USERPROFILE\textlintrc.json C:\Git\My-Repos\tools-by-sean\modules
  code C:\Git\My-Repos\tools-by-sean\modules
}
function update-profile {
  pushd C:\Git\My-Repos\tools-by-sean\modules
  robocopy sdwheeler.utilities $env:USERPROFILE\Documents\WindowsPowerShell\Modules\sdwheeler.utilities /NJH /NJS /NP
  robocopy sdwheeler.utilities $env:USERPROFILE\Documents\PowerShell\Modules\sdwheeler.utilities /NJH /NJS /NP
  copy -Verbose C:\Git\My-Repos\tools-by-sean\modules\Microsoft.PowerShell_profile.ps1 $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
  copy -Verbose C:\Git\My-Repos\tools-by-sean\modules\Microsoft.VSCode_profile.ps1 $env:USERPROFILE\Documents\PowerShell\Microsoft.VSCode_profile.ps1
  copy -Verbose C:\Git\My-Repos\tools-by-sean\modules\settings.json $env:USERPROFILE\AppData\Roaming\Code\User\settings.json
  copy -Verbose C:\Git\My-Repos\tools-by-sean\modules\keybindings.json $env:USERPROFILE\AppData\Roaming\Code\User\keybindings.json
  copy -Verbose C:\Git\My-Repos\tools-by-sean\modules\textlintrc.json $env:USERPROFILE\textlintrc.json
  popd
}
#-------------------------------------------------------
function Push-MyLocation {
  param($targetlocation)
  if  ($null -eq $targetlocation) {
    Get-Location -stack
  } else {
    if (Test-Path $targetlocation -PathType Container) {
      Push-Location $targetlocation
    } elseif (Test-Path $targetlocation) {
      $location = Get-Item $targetlocation
      Push-Location $location.PSParentPath
    } else {
      Write-Error "Invalid path: $targetlocation"
    }
  }
}
Set-Alias -Name cdd -Value Push-MyLocation
Set-Alias -Name pop -Value Pop-Location
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Applications
#-------------------------------------------------------
set-alias qrss  $env:USERPROFILE\QuiteRSS\QuiteRSS.exe
set-alias ed    "${env:ProgramFiles(x86)}\NoteTab 7\NotePro.exe"
set-alias fview "$env:ProgramW6432\Maze Computer\File View\FView.exe"
#-------------------------------------------------------
function bc {
  Start-Process "${env:ProgramFiles}\Beyond Compare 4\BComp.exe" -ArgumentList $args
}
#-------------------------------------------------------
function ed {
  Start-Process "${env:ProgramFiles(x86)}\NoteTab 7\notepro.exe" -ArgumentList $args
}
#-------------------------------------------------------
function update-sysinternals {
  param([switch]$exclusions=$false)
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal] $identity
  if($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $web = get-service webclient
    if ($web.status -ne 'Running') { 'Starting webclient...'; start-service webclient }
    $web = get-service webclient
    while ($web.status -ne 'Running') { Start-Sleep -Seconds 1 }
    if ($exclusions) {
      robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db /xf strings.exe /xf sysmon.exe /xf psexec.exe
    } else {
      robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db
    }
  } else {
    'Updating Sysinternals tools requires elevation.'
  }
}
#endregion
