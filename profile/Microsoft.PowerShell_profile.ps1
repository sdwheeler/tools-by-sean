[CmdletBinding()]
param(
    [switch]$SkipRepos,
    [switch]$Force
)

#-------------------------------------------------------
#region Initialize Environment
#-------------------------------------------------------
$pkgBase = "$env:ProgramW6432\PackageManagement\NuGet\Packages"
$taglibBase = "$pkgBase\TagLibSharp.2.2.0\lib"
$kustoBase = "$pkgBase\Microsoft.Azure.Kusto.Tools.6.0.3\tools"
$sqliteBase = "$env:ProgramW6432\System.Data.SQLite.1.0.116"
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $taglib = "$taglibBase\netstandard2.0\TagLibSharp.dll"
    $null = [Reflection.Assembly]::LoadFrom($taglib)
    $kusto = "$kustoBase\netcoreapp2.1\Kusto.Data.dll"
    $null = [Reflection.Assembly]::LoadFrom($kusto)
    Add-Type -Path "$sqliteBase\netstandard2.1\System.Data.SQLite.dll"
} else {
    $taglib = "$taglibBase\net45\TagLibSharp.dll"
    $null = [Reflection.Assembly]::LoadFrom($taglib)
    $kusto = "$kustoBase\net472\Kusto.Data.dll"
    $null = [Reflection.Assembly]::LoadFrom($kusto)
    Add-Type -Path "$sqliteBase\net46\System.Data.SQLite.dll"
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
    Import-Module CompletionPredictor
    $PSStyle.Progress.UseOSCIndicator = $true
    $PSStyle.OutputRendering = 'Host'
}

if ($PSVersionTable.PSVersion.ToString() -like '5.*') {
    'Reloading PSReadLine...'
    Remove-Module PSReadLine
    Import-Module PSReadLine
}

#endregion
#-------------------------------------------------------
#region Aliases & Globals
#-------------------------------------------------------
if (!(Test-Path HKCR:)) {
    $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
    $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal] $identity
$global:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')

#endregion
#-------------------------------------------------------
#region Git setup
#-------------------------------------------------------
$env:GITHUB_ORG  = 'MicrosoftDocs'
$env:GITHUB_USER = 'sdwheeler'
$env:GH_DEBUG    = 0

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
    'Community', 'Conferences', 'Leanpub', 'Office', 'PS-Loc',
    'SCCM'
$gitFolders | ForEach-Object {
    if (Test-Path "C:\Git\$_") { $global:gitRepoRoots += "C:\Git\$_" }
    if ($d) {
        if (Test-Path "D:\Git\$_") { $global:gitRepoRoots += "D:\Git\$_" }
    }
}

if ((Get-Process -Id $pid).Parent.Name -eq 'Code' -or $IsAdmin) {
    $SkipRepos = $true
}

if (-not $SkipRepos) {
    if (Test-Path ~/repocache.clixml) {
        $cacheage = ((Get-Date) -(Get-Item ~/repocache.clixml).LastWriteTime).TotalDays
    }
    if ($cacheage -lt 1) {
        'Loading repo cache...'
        $global:git_repos = Import-Clixml -Path ~/repocache.clixml
    } else {
        'Scanning repos...'
        Get-MyRepos $gitRepoRoots -TestNetwork #-Verbose:$Verbose
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        'Getting status...'
        Get-RepoStatus
    }
}

if (Test-Path C:\Git) {
    Set-Location C:\Git
} elseif (Test-Path D:\Git) {
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
        $repo = Show-RepoData $Status.RepoName
        if ($null -ne $repo) {
            $location = $location -replace [regex]::Escape($repo.path), '[git]:'
        }
    }

    $strStatus = Get-MyGitBranchStatus $Status
    if ($null -ne $repo.remote.upstream) {
        $repolink = "$esc]8;;$($repo.remote.upstream)$esc\$($status.RepoName)$esc]8;;$esc\"
    } else {
        $repolink = "$esc]8;;$($repo.remote.origin)$esc\$($status.RepoName)$esc]8;;$esc\"
    }
    $strPrompt = @(
        { "$esc[40m$esc[94mPS $($PSVersionTable.PSVersion)$esc[94m" }
        { "$esc[104m$esc[30m$repolink$esc[104m$esc[96m" }
        { "$esc[106m$esc[30m$($Status.Branch)$esc[40m$esc[96m" }
        { "$strStatus`r`n" }
        { "$esc[0m$location❭ " }
    )
    -join $strPrompt.Invoke()
}

$DefaultPrompt = {
    "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
}
$SimplePrompt = { 'PS> ' }

$MyPrompt = {
    $GitStatus = Get-GitStatus
    # Have posh-git display its default prompt
    Write-MyGitStatus
}
$function:prompt = $MyPrompt
$global:Prompt = 'MyPrompt'
#endregion
#-------------------------------------------------------
#region PSReadLine settings
#-------------------------------------------------------

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
        Operator         = "$([char]0x1b)[38;5;164m"
        Parameter        = "$([char]0x1b)[38;5;164m"
        Selection        = "$([char]0x1b)[92;7m"
        InLinePrediction = "$([char]0x1b)[48;5;238m"
    }
    #PredictionSource   = 'HistoryAndPlugin'
}
Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine
#endregion

#-------------------------------------------------------
#region winget cli settings
#-------------------------------------------------------

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
#endregion

#-------------------------------------------------------
#region Helper functions
#-------------------------------------------------------
function Swap-Prompt {

    switch ($global:Prompt) {
        'MyPrompt' {
            $function:prompt = $DefaultPrompt
            $global:Prompt = 'DefaultPrompt'
        }

        'DefaultPrompt' {
            $function:prompt = $SimplePrompt
            $global:Prompt = 'SimplePrompt'
        }

        'SimplePrompt' {
            $function:prompt = $MyPrompt
            $global:Prompt = 'MyPrompt'
        }

        Default {
            $function:prompt = $MyPrompt
            $global:Prompt = 'MyPrompt'
        }
    }
}

#-------------------------------------------------------
function edit {
    param(
        [Parameter(Mandatory)]
        [string[]]$Cmdlet,
        [string]$Version = '7.3',
        [string]$basepath = 'D:\Git\PS-Docs\PowerShell-Docs\reference'
    )

    $aboutFolders = '\Microsoft.PowerShell.Core\About', '\Microsoft.PowerShell.Security\About',
                    '\Microsoft.WSMan.Management\About', '\PSReadLine\About'

    $pathlist = @()
    foreach ($c in $Cmdlet) {
        if ($c -like 'about_*') {
            $result = @()
            foreach ($folder in $aboutFolders) {
                $aboutPath = (Join-Path -path $basepath -child $version -add $folder, ($c + '.md'))
                if (Test-Path $aboutPath) { $result += $aboutPath }
            }
            if ($result.Count -gt 0) {
                $pathlist += $result | Sort-Object -Descending | Select-Object -First 1
            }
        } else {
            $cmd = Get-Command $c
            if ($cmd) {
                $pathParams = @{
                    Path = $basepath
                    ChildPath = $Version
                    AdditionalChildPath = $cmd.Source, ($cmd.Name + '.*')
                    Resolve = $true
                }
                $path = Join-Path @pathParams
                if ($path) { $pathlist += $path }
            }
        }
    }
    if ($pathlist.Count -gt 0) {
        code ($pathlist -join ' ')
    }
}
#-------------------------------------------------------
function epro {
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        Copy-Item $HOME\AppData\Roaming\Code\User\settings.json "$repoPath\profile"
        Copy-Item $HOME\AppData\Roaming\Code\User\keybindings.json "$repoPath\profile"
        robocopy "$HOME\.vale\" "$repoPath\vale" /s /e
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
        Get-ChildItem sdwheeler* -dir | ForEach-Object {
            robocopy $_ "$HOME\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
            robocopy $_ "$HOME\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
        }
        Pop-Location
        Push-Location "$repoPath\modules"
        Get-ChildItem sdwheeler* -dir | ForEach-Object {
            robocopy $_ "$HOME\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
            robocopy $_ "$HOME\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
        }
        Copy-Item -Verbose "$repoPath\profile\Microsoft.PowerShell_profile.ps1" $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
        Copy-Item -Verbose "$repoPath\profile\Microsoft.VSCode_profile.ps1" $HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1
        Copy-Item -Verbose "$repoPath\profile\Microsoft.PowerShell_profile.ps1" $HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
        Copy-Item -Verbose "$repoPath\profile\Microsoft.VSCode_profile.ps1" $HOME\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1
        Copy-Item -Verbose "$repoPath\profile\settings.json" $HOME\AppData\Roaming\Code\User\settings.json
        Copy-Item -Verbose "$repoPath\profile\keybindings.json" $HOME\AppData\Roaming\Code\User\keybindings.json
        robocopy "$repoPath\vale" "$HOME\.vale\" /s /e
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
    } else {
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
    } else {
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
Set-Alias testexe C:\Public\Toolbox\TestExe\testexe.exe
#-------------------------------------------------------
function soma {
    #& "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" http://ice1.somafm.com/illstreet-128-aac
    & "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" 'C:\Users\sewhee\OneDrive - Microsoft\Documents\WIP\soma.m3u'
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
    if ($IsAdmin) {
        $web = Get-Service webclient
        if ($web.status -ne 'Running') { 'Starting webclient...'; Start-Service webclient }
        $web = Get-Service webclient
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
#-------------------------------------------------------
#endregion
