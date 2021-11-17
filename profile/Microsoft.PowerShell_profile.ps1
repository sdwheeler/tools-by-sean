param(
    [switch]$SkipRepos,
    [switch]$Force
)

########################################################
#region Initialize Environment
########################################################
if ($PSVersionTable.PSVersion.Major -ge 6) {
    #Add-WindowsPSModulePath
    $taglib = "$env:USERPROFILE\Documents\PowerShell\modules\TagLib\Libraries\TagLibSharp.dll"
    $null = [Reflection.Assembly]::LoadFrom($taglib)
    $kusto = "$env:USERPROFILE\Documents\PowerShell\modules\Kusto\Kusto.Data.dll"
    $null = [Reflection.Assembly]::LoadFrom($kusto)
    Add-Type -Path 'C:\Program Files\System.Data.SQLite\netstandard2.0\System.Data.SQLite.dll'
}

[System.Net.ServicePointManager]::SecurityProtocol =
[System.Net.SecurityProtocolType]::Tls11 -bor
[System.Net.SecurityProtocolType]::Tls12 -bor
[System.Net.SecurityProtocolType]::Tls13

Import-Module sdwheeler.ADUtils -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.ContentUtils -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.CryptoTools -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.DataConversion -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.FileManagement -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.GitTools -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.PSUtils -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.ROBTools -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.SqliteTools -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.SystemUtils -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.DocsHelpers -WarningAction SilentlyContinue -Force:$Force

if ($PSVersionTable.PSVersion.ToString() -ge '7.2') {
    $PSStyle.Progress.UseOSCIndicator = $true
}

#endregion
#-------------------------------------------------------
#region Aliases & Globals
#-------------------------------------------------------
if (!(Test-Path HKCR:)) { $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT }
if (!(Test-Path HKU:)) { $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS }

#endregion
#-------------------------------------------------------
#region Git setup
$env:GITHUB_ORG = 'MicrosoftDocs'
$env:GITHUB_USER = 'sdwheeler'

$global:gitRepoRoots = 'C:\Git\My-Repos', 'C:\Git\PS-Docs', 'C:\Git\PS-Src',
'C:\Git\AzureDocs', 'C:\Git\Windows', 'C:\Git\APEX', 'C:\Git\PS-Other'
$d = Get-PSDrive d -ea SilentlyContinue
if ($d) {
    'D:\Git\Community', 'D:\Git\Conferences', 'D:\Git\Conferences\PSConfEU',
    'D:\Git\Leanpub', 'D:\Git\Office', 'D:\Git\PS-Loc', 'D:\Git\SCCM' | ForEach-Object {
        if (Test-Path $_) { $global:gitRepoRoots += $_ }
    }
}

Invoke-Expression -Command $(gh completion -s powershell | Out-String)

Import-Module posh-git
Set-Location C:\Git

if (-not $SkipRepos) {
    Get-MyRepos $gitRepoRoots -TestNetwork
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        Get-RepoStatus
    }
}

function Write-MyGitStatus {
    $Status = Get-GitStatus
    $settings = $global:GitPromptSettings
    $strStatus = ''

    $strStatus += Write-GitBranchStatus $Status -NoLeadingSpace
    if ($settings.EnableFileStatus -and $Status.HasIndex) {
        $strStatus += Write-GitIndexStatus $Status
        if ($Status.HasWorking) {
            $strStatus += Write-Prompt $s.DelimStatus
        }
    }
    if ($settings.EnableFileStatus -and $Status.HasWorking) {
        $strStatus += Write-GitWorkingDirStatus $Status
    }
    $strStatus += Write-GitWorkingDirStatusSummary $Status
    if ($settings.EnableStashStatus -and ($Status.StashCount -gt 0)) {
        $strStatus += Write-GitStashCount $Status
    }
    $location = $ExecutionContext.SessionState.Path.CurrentLocation

    if ($Status) {
        $location = $location -replace [regex]::Escape((Show-Repo $Status.RepoName).path), '[git]:'
    }

    if ($PSVersionTable.PSVersion -like '5.1*') {
        $esc = [char]27
        $strPrompt  = "$esc[40m$esc[94mPS $($PSVersionTable.PSVersion)$esc[94m"
        $strPrompt += "$esc[104m$esc[30m/$($status.RepoName)/$esc[104m$esc[96m"
        $strPrompt += "$esc[106m$esc[30m$($Status.Branch)/$esc[40m$esc[96m"
        $strPrompt += "$esc[33m<$esc[0m$strStatus$esc[33m>$esc[0m`r`n"
        $strPrompt += "$location> "
    } else {
        $strPrompt  = "`e[40m`e[94mPS $($PSVersionTable.PSVersion)`e[94m"
        $strPrompt += "`e[104m`e[30m$($status.RepoName)`e[104m`e[96m"
        $strPrompt += "`e[106m`e[30m$($Status.Branch)`e[40m`e[96m"
        $strPrompt += "`e[33m❮`e[0m$strStatus`e[33m❯`e[0m`r`n"
        $strPrompt += "$location❭ "
    }
    $strPrompt
}
$MyPrompt = {
    $GitStatus = Get-GitStatus
    # Have posh-git display its default prompt
    Write-MyGitStatus

    # Your non-prompt logic here
    if ($GitStatus) {
        $global:lastcommit = git log -n 1 --pretty='format:%s'
    }
    else {
        $global:lastcommit = ''
    }
}

#-------------------------------------------------------
$GitPromptSettings.WindowTitle = {
    param($GitStatus, [bool]$IsAdmin)
    "$(if ($IsAdmin) {'Admin: '})$(if ($GitStatus) {
            "$($GitStatus.RepoName) [$($GitStatus.Branch)]"
        } else {
            Get-PromptPath
        }) ~ PSv$($PSVersionTable.PSVersion) $([IntPtr]::Size * 8)-bit ($PID)"
}
# $GitPromptSettings.DefaultPromptPath = '[PSv$($PSVersionTable.PSVersion)]'
# $GitPromptSettings.DefaultPromptWriteStatusFirst = $false
# $GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`nPS $(Get-PromptPath)'
# $GitPromptSettings.DefaultPromptBeforeSuffix.ForegroundColor = 'White'
# $GitPromptSettings.DefaultPromptSuffix = '$(">" * ($nestedPromptLevel + 1)) '
$function:prompt = $MyPrompt

# PSReadLine settings
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSROptions = @{
        ContinuationPrompt = '  '
        Colors             = @{
            Operator         = "`e[95m"
            Parameter        = "`e[95m"
            Selection        = "`e[92;7m"
            InLinePrediction = "`e[48;5;238m"
        }
        PredictionSource   = 'History'
    }
    Set-PSReadLineOption @PSROptions
}

function Swap-Prompt {
    if ($function:prompt.tostring().length -gt 100) {
        $function:prompt = { 'PS> ' }
    }
    else {
        $function:prompt = $MyPrompt
    }
}
#endregion
#-------------------------------------------------------
#region Helper functions
#-------------------------------------------------------
function epro {
    Copy-Item $env:USERPROFILE\AppData\Roaming\Code\User\settings.json C:\Git\My-Repos\tools-by-sean\profile
    Copy-Item $env:USERPROFILE\AppData\Roaming\Code\User\keybindings.json C:\Git\My-Repos\tools-by-sean\profile
    Copy-Item $env:USERPROFILE\textlintrc.json C:\Git\My-Repos\tools-by-sean\profile
    code C:\Git\My-Repos\tools-by-sean
}
#-------------------------------------------------------
function Update-Profile {
    Push-Location C:\Git\My-Repos\tools-by-sean\modules
    dir sdwheeler* -dir | %{
        robocopy $_ "$env:USERPROFILE\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
        robocopy $_ "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
    }
    Copy-Item -Verbose C:\Git\My-Repos\tools-by-sean\profile\Microsoft.PowerShell_profile.ps1 $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
    Copy-Item -Verbose C:\Git\My-Repos\tools-by-sean\profile\Microsoft.VSCode_profile.ps1 $env:USERPROFILE\Documents\PowerShell\Microsoft.VSCode_profile.ps1
    Copy-Item -Verbose C:\Git\My-Repos\tools-by-sean\profile\settings.json $env:USERPROFILE\AppData\Roaming\Code\User\settings.json
    Copy-Item -Verbose C:\Git\My-Repos\tools-by-sean\profile\keybindings.json $env:USERPROFILE\AppData\Roaming\Code\User\keybindings.json
    Copy-Item -Verbose C:\Git\My-Repos\tools-by-sean\profile\textlintrc.json $env:USERPROFILE\textlintrc.json
    Pop-Location
}
#-------------------------------------------------------
function ver {
    param([switch]$full)

    if ($full) {
        $PSVersionTable
    }
    else {
        $version = 'PowerShell {0} v{1}' -f $PSVersionTable.PSEdition,
        $PSVersionTable.PSVersion.ToString()
        if ($PSVersionTable.OS) {
            $version += ' [{0}]' -f $PSVersionTable.OS
        }
        $version
    }
}
#-------------------------------------------------------
function Push-MyLocation {
    param($targetlocation)
    if ($null -eq $targetlocation) {
        Get-Location -Stack
    }
    else {
        if (Test-Path $targetlocation -PathType Container) {
            Push-Location $targetlocation
        }
        elseif (Test-Path $targetlocation) {
            $location = Get-Item $targetlocation
            Push-Location $location.PSParentPath
        }
        else {
            Write-Error "Invalid path: $targetlocation"
        }
    }
}
Set-Alias -Name cdd -Value Push-MyLocation
Set-Alias -Name pop -Value Pop-Location
#-------------------------------------------------------
function Get-IpsumLorem {
    Invoke-RestMethod https://loripsum.net/api/ul/code/headers/ol
}
#-------------------------------------------------------
function Get-WeekNumber {
    param($date = (Get-Date))

    $Calendar = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $Calendar.GetWeekOfYear($date, [System.Globalization.CalendarWeekRule]::FirstFullWeek,
        [System.DayOfWeek]::Sunday)
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Applications
#-------------------------------------------------------
Set-Alias rss $env:USERPROFILE\Desktop\QuiteRSS\QuiteRSS.exe
Set-Alias qrss $env:USERPROFILE\QuiteRSS\QuiteRSS.exe
Set-Alias ed "${env:ProgramFiles(x86)}\NoteTab 7\NotePro.exe"
Set-Alias fview "$env:ProgramW6432\Maze Computer\File View\FView.exe"
Set-Alias 7z 'C:\Program Files\7-Zip\7z.exe'
Set-Alias testexe C:\Git\PS-Src\PowerShell\test\tools\TestExe\bin\testexe.exe
#-------------------------------------------------------
function soma {
    & "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe" http://ice1.somafm.com/illstreet-128-aac
}
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
    param([switch]$exclusions = $false)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        $web = Get-Service webclient
        if ($web.status -ne 'Running') { 'Starting webclient...'; Start-Service webclient }
        $web = Get-Service webclient
        while ($web.status -ne 'Running') { Start-Sleep -Seconds 1 }
        if ($exclusions) {
            robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db /xf strings.exe /xf sysmon.exe /xf psexec.exe
        }
        else {
            robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db
        }
    }
    else {
        'Updating Sysinternals tools requires elevation.'
    }
}
#-------------------------------------------------------
#endregion
