[CmdletBinding()]
param(
    [switch]$SkipRepos,
    [switch]$Force
)

#-------------------------------------------------------
#region Initialize Environment
#-------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $taglib = "$HOME\Documents\PowerShell\modules\TagLib\Libraries\TagLibSharp.dll"
    $null = [Reflection.Assembly]::LoadFrom($taglib)
    $kusto = "$HOME\Documents\PowerShell\modules\Kusto\Kusto.Data.dll"
    $null = [Reflection.Assembly]::LoadFrom($kusto)
    Add-Type -Path 'C:\Program Files\System.Data.SQLite\netstandard2.0\System.Data.SQLite.dll'
}

[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.SecurityProtocolType]::Tls11 -bor
    [System.Net.SecurityProtocolType]::Tls12 -bor
    [System.Net.SecurityProtocolType]::Tls13

'Loading modules...'
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
    $PSStyle.OutputRendering = 'Host'
}

#endregion
#-------------------------------------------------------
#region Aliases & Globals
#-------------------------------------------------------
if (!(Test-Path HKCR:)) {
    $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
    $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS
}

#endregion
#-------------------------------------------------------
#region Git setup
#-------------------------------------------------------
$env:GITHUB_ORG = 'MicrosoftDocs'
$env:GITHUB_USER = 'sdwheeler'

#-------------------------------------------------------
# GitHub CLI
#-------------------------------------------------------
$gh = where.exe gh.exe
if ($gh) {
    Invoke-Expression -Command $(gh completion -s powershell | Out-String)
}

#-------------------------------------------------------
# Collect repo information
#-------------------------------------------------------
$global:gitRepoRoots = @()
$d = Get-PSDrive d -ea SilentlyContinue
$gitFolders = 'My-Repos', 'PS-Docs', 'PS-Src', 'AzureDocs', 'Learn', 'Windows', 'APEX', 'PS-Other',
              'Community','Conferences', 'Conferences\PSConfEU', 'Leanpub', 'Office', 'PS-Loc',
              'SCCM'
$gitFolders | ForEach-Object {
    if (Test-Path "C:\Git\$_") { $global:gitRepoRoots += "C:\Git\$_" }
    if ($d) {
        if (Test-Path "D:\Git\$_") { $global:gitRepoRoots += "D:\Git\$_" }
    }
}

if (-not $SkipRepos) {
    'Scanning repos...'
    Get-MyRepos $gitRepoRoots -TestNetwork #-Verbose:$Verbose
    if ($PSVersionTable.PSVersion.Major -ge 6) {
    	'Getting status...'
        Get-RepoStatus
    }
}

if (Test-Path C:\Git) {
    Set-Location C:\Git
}
elseif (Test-Path D:\Git) {
    Set-Location D:\Git
}

#-------------------------------------------------------
# Posh-Git settings
#-------------------------------------------------------
Import-Module posh-git

$esc = [char]27
$GitPromptSettings.WindowTitle = {
    param($GitStatus, [bool]$IsAdmin)
    "$(if ($IsAdmin) {'Admin: '})$(if ($GitStatus) {
            "$($GitStatus.RepoName) [$($GitStatus.Branch)]"
        } else {
            Get-PromptPath
        }) ~ PSv$($PSVersionTable.PSVersion) $([IntPtr]::Size * 8)-bit ($PID)"
}
$GitPromptSettings.PathStatusSeparator = ''
$GitPromptSettings.BeforeStatus = "$esc[33m❮$esc[0m"
$GitPromptSettings.AfterStatus = "$esc[33m❯$esc[0m"

function Write-MyGitStatus {

    function Get-MyGitBranchStatus {
        param(
            # The Git status object that provides the status information to be written.
            # This object is retrieved via the Get-GitStatus command.
            [Parameter(Position = 0)]
            $Status
        )

        $s = $global:GitPromptSettings
        if (!$Status -or !$s) {
            return
        }

        $sb = [System.Text.StringBuilder]::new(150)

        # When prompt is first (default), place the separator before the status summary
        if (!$s.DefaultPromptWriteStatusFirst) {
            $sb | Write-Prompt $s.PathStatusSeparator.Expand() > $null
        }

        $sb | Write-Prompt $s.BeforeStatus > $null
        $sb | Write-GitBranchStatus $Status -NoLeadingSpace > $null

        $sb | Write-Prompt $s.BeforeIndex > $null

        if ($s.EnableFileStatus -and $Status.HasIndex) {
            $sb | Write-GitIndexStatus $Status > $null
            if ($Status.HasWorking) {
                $sb | Write-Prompt $s.DelimStatus > $null
            }
        }

        if ($s.EnableFileStatus -and $Status.HasWorking) {
            $sb | Write-GitWorkingDirStatus $Status > $null
        }

        $sb | Write-GitWorkingDirStatusSummary $Status > $null

        if ($s.EnableStashStatus -and ($Status.StashCount -gt 0)) {
            $sb | Write-GitStashCount $Status > $null
        }

        $sb | Write-Prompt $s.AfterStatus > $null

        if ($sb.Length -gt 0) {
            $sb.ToString()
        }
    }

    $Status = Get-GitStatus
    $location = $ExecutionContext.SessionState.Path.CurrentLocation
    if ($Status) {
        $repo = Show-Repo $Status.RepoName
        if ($null -ne $repo) {
            $location = $location -replace [regex]::Escape($repo.path), '[git]:'
        }
    }

    $strStatus = Get-MyGitBranchStatus $Status
    $repolink = "$esc]8;;$($repo.remote.origin)$esc\$($status.RepoName)$esc]8;;$esc\"
    $strPrompt = @(
        { "$esc[40m$esc[94mPS $($PSVersionTable.PSVersion)$esc[94m" }
        { "$esc[104m$esc[30m$repolink$esc[104m$esc[96m" }
        { "$esc[106m$esc[30m$($Status.Branch)$esc[40m$esc[96m" }
        { "$strStatus`r`n" }
        { "$esc[0m$location❭ " }
    )
    -join $strPrompt.Invoke()
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
$function:prompt = $MyPrompt

#-------------------------------------------------------
# PSReadLine settings
#-------------------------------------------------------

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
        Operator         = "$([char]0x1b)[38;5;164m"
        Parameter        = "$([char]0x1b)[38;5;164m"
        Selection        = "$([char]0x1b)[92;7m"
        InLinePrediction = "$([char]0x1b)[48;5;238m"
    }
    PredictionSource   = 'History'
}
Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine
#endregion

#-------------------------------------------------------
#region Helper functions
#-------------------------------------------------------
function Swap-Prompt {
    if ($function:prompt.tostring().length -gt 100) {
        $function:prompt = { 'PS> ' }
    }
    else {
        $function:prompt = $MyPrompt
    }
}

function epro {
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        Copy-Item $HOME\AppData\Roaming\Code\User\settings.json "$repoPath\profile"
        Copy-Item $HOME\AppData\Roaming\Code\User\keybindings.json "$repoPath\profile"
        Copy-Item $HOME\textlintrc.json "$repoPath\profile"
        code "$repoPath"
    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
#-------------------------------------------------------
function Update-Profile {
    $repoPath = $git_repos['tools-by-sean'].path
    $toolsPath = $git_repos['DocsTools'].path
    if ($repoPath) {
        Push-Location "$toolsPath"
        dir sdwheeler* -dir | %{
            robocopy $_ "$HOME\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
            robocopy $_ "$HOME\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
        }
        Pop-Location
        Push-Location "$repoPath\modules"
        dir sdwheeler* -dir | %{
            robocopy $_ "$HOME\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
            robocopy $_ "$HOME\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
        }
        Copy-Item -Verbose "$repoPath\profile\Microsoft.PowerShell_profile.ps1" $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
        Copy-Item -Verbose "$repoPath\profile\Microsoft.VSCode_profile.ps1" $HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1
        Copy-Item -Verbose "$repoPath\profile\settings.json" $HOME\AppData\Roaming\Code\User\settings.json
        Copy-Item -Verbose "$repoPath\profile\keybindings.json" $HOME\AppData\Roaming\Code\User\keybindings.json
        Copy-Item -Verbose "$repoPath\profile\textlintrc.json" $HOME\textlintrc.json
        Pop-Location
    } else {
        Write-Error '$git_repos does not contain repo.'
    }
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
Set-Alias qrss "${env:ProgramFiles(x86)}\QuiteRSS\QuiteRSS.exe"
Set-Alias ed "${env:ProgramFiles(x86)}\NoteTab 7\NotePro.exe"
Set-Alias fview "$env:ProgramW6432\Maze Computer\File View\FView.exe"
Set-Alias 7z 'C:\Program Files\7-Zip\7z.exe'
Set-Alias testexe C:\Git\PS-Src\PowerShell\test\tools\TestExe\bin\testexe.exe
#-------------------------------------------------------
function soma {
    & "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" http://ice1.somafm.com/illstreet-128-aac
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
function Update-Sysinternals {
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
