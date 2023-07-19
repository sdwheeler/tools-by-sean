[CmdletBinding()]
param(
    [switch]$SkipRepos,
    [switch]$SkipDocuModules,
    [switch]$Force
)

#-------------------------------------------------------
#region Initialize Environment
#-------------------------------------------------------
$ESC = [char]0x1b
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
Import-Module sdwheeler.GitTools -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.ContentUtils -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.PSUtils -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.ROBTools -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.DataConversion -WarningAction SilentlyContinue -Force:$Force
Import-Module sdwheeler.FileManagement -WarningAction SilentlyContinue -Force:$Force
#Import-Module sdwheeler.SystemUtils -WarningAction SilentlyContinue -Force:$Force
#Import-Module sdwheeler.CryptoTools -WarningAction SilentlyContinue -Force:$Force
#Import-Module sdwheeler.ADUtils -WarningAction SilentlyContinue -Force:$Force
#Import-Module sdwheeler.SqliteTools -WarningAction SilentlyContinue -Force:$Force
#Import-Module sdwheeler.DocsHelpers -WarningAction SilentlyContinue -Force:$Force

if ($PSVersionTable.PSVersion.ToString() -like '5.*') {
    Import-Module PSStyle
    'Reloading PSReadLine...'
    Remove-Module PSReadLine
    Import-Module PSReadLine
}

if ($PSVersionTable.PSVersion.ToString() -ge '7.2') {
    Import-Module CompletionPredictor
    if (-not $SkipDocuModules){
        Import-Module Documentarian -Force:$Force
        #Import-Module Documentarian.DevX -Force:$Force
        Import-Module Documentarian.MarkdownBuilder -Force:$Force
        Import-Module Documentarian.MicrosoftDocs -Force:$Force
        Import-Module Documentarian.ModuleAuthor -Force:$Force
        Import-Module Documentarian.Vale -Force:$Force
        Remove-Module Init
    }
    Set-Alias bcsync Sync-BeyondCompare
    Set-Alias vscsync Sync-VSCode
}
if ($PSStyle) {
    $PSStyle.Progress.UseOSCIndicator = $true
    $PSStyle.OutputRendering = 'Host'
    $PSStyle.FileInfo.Directory = $PSStyle.Background.FromRgb(0x2f6aff) + $PSStyle.Foreground.BrightWhite
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
$env:GITHUB_ORG = 'MicrosoftDocs'
$env:GITHUB_USER = 'sdwheeler'
$env:GH_DEBUG = 0

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

<#
if ((Get-Process -Id $pid).Parent.Name -eq 'Code' -or $IsAdmin) {
    $SkipRepos = $true
}
#>

function Get-RepoCacheAge {
    if (Test-Path ~/repocache.clixml) {
        ((Get-Date) - (Get-Item ~/repocache.clixml).LastWriteTime).TotalDays
    } else {
        [double]::MaxValue
    }
}

if (-not $SkipRepos) {
    if (Test-Path ~/repocache.clixml) {
        $cacheage = Get-RepoCacheAge
    }
    if ($cacheage -lt 8 -or $null -eq (Test-Connection github.com -ea SilentlyContinue -Count 1)) {
        'Loading repo cache...'
        $global:git_repos = Import-Clixml -Path ~/repocache.clixml
    } else {
        'Scanning repos...'
        Get-MyRepos $gitRepoRoots #-Verbose:$Verbose
    }
    # Use gh dash instead
    # if ((Get-Process -Id $pid).Parent.Name -ne 'Code' ) {
    #     if ($PSVersionTable.PSVersion.Major -ge 7) {
    #         'Getting status...'
    #         Get-RepoStatus
    #     }
    # }
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
function Write-PoshGitStatus {
    $origDollarQuestion = $global:?
    $origLastExitCode = $global:LASTEXITCODE

    if (!$global:GitPromptValues) {
        $global:GitPromptValues = [PoshGitPromptValues]::new()
    }

    $global:GitPromptValues.DollarQuestion = $origDollarQuestion
    $global:GitPromptValues.LastExitCode = $origLastExitCode
    $global:GitPromptValues.IsAdmin = $IsAdmin

    $settings = $global:GitPromptSettings

    if (!$settings) {
        return "<`$GitPromptSettings not found> "
    }

    if ($settings.DefaultPromptEnableTiming) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
    }

    if ($settings.SetEnvColumns) {
        # Set COLUMNS so git knows how wide the terminal is
        $Env:COLUMNS = $Host.UI.RawUI.WindowSize.Width
    }

    # Construct/write the prompt text
    $prompt = ''

    # Write default prompt prefix
    $prompt += Write-Prompt $settings.DefaultPromptPrefix.Expand()

    # Get the current path - formatted correctly
    $promptPath = $settings.DefaultPromptPath.Expand()

    # Write the delimited path and Git status summary information
    if ($settings.DefaultPromptWriteStatusFirst) {
        $prompt += Write-VcsStatus
        $prompt += Write-Prompt $settings.BeforePath.Expand()
        $prompt += Write-Prompt $promptPath
        $prompt += Write-Prompt $settings.AfterPath.Expand()
    }
    else {
        $prompt += Write-Prompt $settings.BeforePath.Expand()
        $prompt += Write-Prompt $promptPath
        $prompt += Write-Prompt $settings.AfterPath.Expand()
        $prompt += Write-VcsStatus
    }

    # Write default prompt before suffix text
    $prompt += Write-Prompt $settings.DefaultPromptBeforeSuffix.Expand()

    # If stopped in the debugger, the prompt needs to indicate that by writing default prompt debug
    if ((Test-Path Variable:/PSDebugContext) -or [runspace]::DefaultRunspace.Debugger.InBreakpoint) {
        $prompt += Write-Prompt $settings.DefaultPromptDebug.Expand()
    }

    # Get the prompt suffix text
    $promptSuffix = $settings.DefaultPromptSuffix.Expand()

    # When using Write-Host, we return a single space from this function to prevent PowerShell from displaying "PS>"
    # So to avoid two spaces at the end of the suffix, remove one here if it exists
    if (!$settings.AnsiConsole -and $promptSuffix.Text.EndsWith(' ')) {
        $promptSuffix.Text = $promptSuffix.Text.Substring(0, $promptSuffix.Text.Length - 1)
    }

    # If prompt timing enabled, write elapsed milliseconds
    if ($settings.DefaultPromptEnableTiming) {
        $timingInfo = [PoshGitTextSpan]::new($settings.DefaultPromptTimingFormat)
        $sw.Stop()
        $timingInfo.Text = $timingInfo.Text -f $sw.ElapsedMilliseconds
        $prompt += Write-Prompt $timingInfo
    }

    $prompt += Write-Prompt $promptSuffix

    $global:LASTEXITCODE = $origLastExitCode
    $prompt
}
#endregion
#-------------------------------------------------------
#region PSReadLine settings
#-------------------------------------------------------

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
        Operator         = "${ESC}[38;5;164m"
        Parameter        = "${ESC}[38;5;164m"
        Selection        = "${ESC}[92;7m"
        InLinePrediction = "${ESC}[48;5;238m"
    }
    #PredictionSource   = 'HistoryAndPlugin'
}
Set-PSReadLineOption @PSROptions
$keymap = @{
    BackwardDeleteInput       = 'Ctrl+Home'
    BackwardKillWord          = 'Ctrl+Backspace'
    BackwardWord              = 'Ctrl+LeftArrow'
    BeginningOfLine           = 'Home'
    Copy                      = 'Ctrl+c'
    CopyOrCancelLine          = 'Ctrl+c'
    Cut                       = 'Ctrl+x'
    DeleteChar                = 'Delete'
    EndOfLine                 = 'End'
    ForwardWord               = 'Ctrl+f'
    KillWord                  = 'Ctrl+Delete'
    MenuComplete              = 'Ctrl+Spacebar','Ctrl+D2'
    NextWord                  = 'Ctrl+RightArrow'
    Paste                     = 'Ctrl+v'
    Redo                      = 'Ctrl+y'
    RevertLine                = 'Escape'
    SelectAll                 = 'Ctrl+a'
    SelectBackwardChar        = 'Shift+LeftArrow'
    SelectBackwardsLine       = 'Shift+Home'
    SelectBackwardWord        = 'Shift+Ctrl+LeftArrow'
    SelectCommandArgument     = 'Alt+a'
    SelectForwardChar         = 'Shift+RightArrow'
    SelectLine                = 'Shift+End'
    SelectNextWord            = 'Shift+Ctrl+RightArrow'
    ShowCommandHelp           = 'F1'
    ShowParameterHelp         = 'Alt+h'
    SwitchPredictionView      = 'F2'
    TabCompleteNext           = 'Tab'
    TabCompletePrevious       = 'Shift+Tab'
    Undo                      = 'Ctrl+z'
    ValidateAndAcceptLine     = 'Enter'
}

foreach ($key in $keymap.Keys) {
    foreach ($chord in $keymap[$key]) {
        Set-PSReadLineKeyHandler -Function $key -Chord $chord
    }
}
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
$global:Prompts = @{
    Current = 'MyPrompt'

    DefaultPrompt = {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
    }

    SimplePrompt = { 'PS> ' }

    MyPrompt = {
        #$GitStatus = Get-GitStatus
        $GitPromptSettings.PathStatusSeparator = ''
        $GitPromptSettings.BeforeStatus = "$esc[33m❮$esc[0m"
        $GitPromptSettings.AfterStatus = "$esc[33m❯$esc[0m"
        Write-MyGitStatus
    }

    PoshGitPrompt = {
        $GitPromptSettings.PathStatusSeparator = ' '
        $GitPromptSettings.BeforeStatus = "$esc[93m[$esc[39m"
        $GitPromptSettings.AfterStatus = "$esc[93m]$esc[39m"
        Write-PoshGitStatus
    }
}
$function:prompt = $Prompts.MyPrompt

function Switch-Prompt {
    param(
        [Parameter(Position=0)]
        [ValidateSet('MyPrompt', 'PoshGitPrompt', 'DefaultPrompt', 'SimplePrompt')]
        [string]$FunctionName
    )

    if ([string]::IsNullOrEmpty($FunctionName)) {
        # Switch to the next prompt in rotation
        switch ($global:Prompts.Current) {
            'MyPrompt'      { $FunctionName = 'PoshGitPrompt' }
            'PoshGitPrompt' { $FunctionName = 'DefaultPrompt' }
            'DefaultPrompt' { $FunctionName = 'SimplePrompt'  }
            'SimplePrompt'  { $FunctionName = 'MyPrompt'      }
            Default         { $FunctionName = 'MyPrompt'      }
        }
    }
    $global:Prompts.Current = $FunctionName
    $function:prompt = $global:Prompts.$FunctionName

}
Set-Alias -Name swp -Value Switch-Prompt
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
                $aboutPath = (Join-Path -Path $basepath -child $version -add $folder, ($c + '.md'))
                if (Test-Path $aboutPath) { $result += $aboutPath }
            }
            if ($result.Count -gt 0) {
                $pathlist += $result | Sort-Object -Descending | Select-Object -First 1
            }
        } else {
            $cmd = Get-Command $c
            if ($cmd) {
                $pathParams = @{
                    Path                = $basepath
                    ChildPath           = $Version
                    AdditionalChildPath = $cmd.Source, ($cmd.Name + '.*')
                    Resolve             = $true
                }
                $path = Join-Path @pathParams
                if ($path) { $pathlist += $path }
            }
        }
    }
    if ($pathlist.Count -gt 0) {
        code ($pathlist)
    }
}
#-------------------------------------------------------
function epro {
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        Copy-Item $HOME\AppData\Roaming\Code\User\settings.json $repoPath\profile
        Copy-Item $HOME\AppData\Roaming\Code\User\keybindings.json $repoPath\profile
        Copy-Item $HOME\.vale\vale.ini $repoPath\vale /s /e
        Copy-Item $HOME\.vale\allrules.ini $repoPath\vale /s /e
        robocopy $HOME\.vale\styles\Vocab\Docs $repoPath\vale\styles\Vocab\Docs /s /e
        robocopy $HOME\.vale\styles\PowerShell-Docs $repoPath\vale\styles\PowerShell-Docs /s /e
        robocopy $HOME\.config\gh-dash $repoPath\config\gh-dash /s /e
        code "$repoPath"
    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
#-------------------------------------------------------
function Update-Profile {
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        Push-Location "$repoPath\modules"
        Get-ChildItem sdwheeler* -dir | ForEach-Object {
            robocopy $_ "$HOME\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
            robocopy $_ "$HOME\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
        }
        Copy-Item -Verbose $repoPath\profile\Microsoft.PowerShell_profile.ps1 $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
        Copy-Item -Verbose $repoPath\profile\Microsoft.VSCode_profile.ps1 $HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1
        Copy-Item -Verbose $repoPath\profile\Microsoft.PowerShell_profile.ps1 $HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
        Copy-Item -Verbose $repoPath\profile\Microsoft.VSCode_profile.ps1 $HOME\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1
        Copy-Item -Verbose $repoPath\profile\settings.json $HOME\AppData\Roaming\Code\User\settings.json
        Copy-Item -Verbose $repoPath\profile\keybindings.json $HOME\AppData\Roaming\Code\User\keybindings.json
        robocopy $repoPath\vale $HOME\.vale /s /e
        robocopy $repoPath\config\gh-dash $HOME\.config\gh-dash /s /e
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
    & "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" '$HOME\OneDrive - Microsoft\Documents\WIP\soma.m3u'
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
function Find-CLI {
    param(
        [CmdletBinding()]
        [Parameter(Position = 0)]
        [ValidateSet('dash', 'gh', 'vale', 'pandoc')]
        [string[]]$Tools = @('dash', 'gh', 'vale', 'pandoc'),
        [switch]$ShowReleaseNotes
    )
    $tooldata = @{
        dash = @{
            repo = 'dlvhdr/gh-dash'
            versioncmd = 'gh dash --version | findstr version'
        }
        gh = @{
            repo = 'cli/cli'
            versioncmd = 'gh --version | findstr version'
        }
        vale = @{
            repo = 'errata-ai/vale'
            versioncmd = 'vale --version | findstr version'
        }
        pandoc = @{
            repo = 'jgm/pandoc'
            versioncmd = 'pandoc --version | findstr exe'
        }
    }

    foreach ($tool in $Tools) {
        $release = gh release view -R $($tooldata[$tool].repo) --json name,tagName,publishedAt,body | ConvertFrom-Json
        $info = [pscustomobject]@{
            Installed    = $(Invoke-Expression $tooldata[$tool].versioncmd)
            Current      = "$($release.name) ($('{0:yyyy-MM-dd}' -f $release.publishedAt))"
            ReleaseNotes = $release.body
        }
        if ($ShowReleaseNotes) {
            $info  | Format-List
        } else {
            $info | Select-Object Installed, Current | Format-List
        }

    }
}
#-------------------------------------------------------
function Update-CLI {
    param(
        [switch]$dash,
        [switch]$gh,
        [switch]$vale,
        [switch]$pandoc
    )

    if (-not ($dash -or $gh -or $vale)) {
        $dash = $gh = $vale = $true
    }
    if ($dash) {
        $v = (gh release view -R dlvhdr/gh-dash --json tagName,assets| ConvertFrom-Json)
        "Downloading gh-dash $($v.tagName)..."
        $f = ($v.assets | Where-Object Name -like 'windows-amd64.exe').name
        gh release download -R dlvhdr/gh-dash -p windows-amd64.exe -O "$HOME\Downloads\$($v.tagName)-gh-dash.exe" --skip-existing
        "Installing gh-dash $($v.tagName)..."
        Copy-Item "$HOME\Downloads\$($v.tagName)-gh-dash.exe" "$HOME\AppData\Local\GitHub CLI\extensions\gh-dash\gh-dash.exe" -Force
    }
    if ($gh) {
        $v = (gh release view -R cli/cli --json tagName  --json assets | ConvertFrom-Json)
        "Downloading gh $($v.tagName)..."
        $f = ($v.assets | Where-Object Name -like '*windows_amd64.msi').name
        gh release download -R cli/cli -p $f -D $HOME\Downloads --skip-existing
        "Installing gh $($v.tagName)..."
        Invoke-Item $HOME\Downloads\$f
    }
    if ($vale) {
        $v = (gh release view -R errata-ai/vale --json tagName,assets | ConvertFrom-Json)
        "Downloading vale $($v.tagName)..."
        $f = ($v.assets | Where-Object Name -like 'vale*Windows_64-bit.zip').name
        gh release download -R errata-ai/vale -p $f -D $HOME\Downloads --skip-existing
        "Installing vale $($v.tagName)..."
        7z e $HOME\Downloads\$f vale.exe -oC:\Public\Toolbox -y
    }
    if ($pandoc) {
        $v = (gh release view -R jgm/pandoc --json tagName,assets | ConvertFrom-Json)
        "Downloading pandoc $($v.tagName)..."
        $f = ($v.assets | Where-Object Name -like '*windows-x86_64.msi').name
        gh release download -R jgm/pandoc -p $f -D $HOME\Downloads --skip-existing
        "Installing pandoc $v..."
        Invoke-Item $HOME\Downloads\$f
    }
}
#-------------------------------------------------------
#endregion
