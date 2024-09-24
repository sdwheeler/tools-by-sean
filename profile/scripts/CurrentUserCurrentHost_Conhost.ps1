#-------------------------------------------------------
#region Important global settings
#-------------------------------------------------------
[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.ServicePointManager]::SecurityProtocol -bor
    [System.Net.SecurityProtocolType]::Tls12 -bor
    [System.Net.SecurityProtocolType]::Tls13

#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Version-specific initialization
#-------------------------------------------------------
if ($PSVersionTable.PSVersion -lt '6.0') {
    Write-Verbose 'Setting up PowerShell 5.x environment...'
    # The $Is* variables are not defined in PowerShell 5.1
    $IsLinux = $IsMacOS = $IsCoreCLR = $false
    $IsWindows = $true

    # Load PSStyle module for compatibility with PS 7.2 and higher
    Import-Module PSStyle

    # Fix the case of the PSReadLine module so that Update-Help works
    Write-Verbose 'Reloading PSReadLine...'
    Remove-Module PSReadLine
    Import-Module PSReadLine

    Set-PSReadLineOption -PredictionSource 'History'
}

if ($PSVersionTable.PSVersion -ge '7.2') {
    Write-Verbose 'Setting up PowerShell 7.2+ environment...'
    Set-PSReadLineOption -PredictionSource 'HistoryAndPlugin'
    Import-Module CompletionPredictor # Requires PSSubsystemPluginModel experimental feature
}

#endregion
#-------------------------------------------------------
#region OS-specific initialization (all versions)
#-------------------------------------------------------
if ($IsWindows) {
    # Create custom PSDrives
    if (!(Test-Path HKCR:)) {
        $null = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
        $null = New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS
    }

    # Check for admin privileges
    & {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal] $identity
        $global:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    }

    # Register the winget argument completer
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
    Set-Location -Path ~
} elseif ($IsLinux) {
    Import-Module -Name Microsoft.PowerShell.UnixTabCompletion
    Import-PSUnixTabCompletion
} elseif ($IsMacOS) {
    Import-Module -Name Microsoft.PowerShell.UnixTabCompletion
    Import-PSUnixTabCompletion
}
#endregion
#-------------------------------------------------------
#region Git configuration
#-------------------------------------------------------
Write-Verbose 'Setting up Git environment...'
$env:GITHUB_ORG = 'MicrosoftDocs'
$env:GITHUB_USER = 'sdwheeler'
$env:GH_DEBUG = 0

Import-Module posh-git
# Global settings for posh-git
$GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $false

# Check for the gh command and set up completion
if (Get-Command gh -ea SilentlyContinue) {
    Invoke-Expression -Command $(gh completion -s powershell | Out-String)
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region PSReadLine settings
#-------------------------------------------------------
Write-Verbose 'Setting up PSReadLine...'
& {
    $keymap = @{
        BackwardDeleteInput   = 'Ctrl+Home'
        BackwardKillWord      = 'Ctrl+Backspace'
        BackwardWord          = 'Ctrl+LeftArrow'
        BeginningOfLine       = 'Home'
        Copy                  = 'Ctrl+c'
        CopyOrCancelLine      = 'Ctrl+c'
        Cut                   = 'Ctrl+x'
        DeleteChar            = 'Delete'
        EndOfLine             = 'End'
        ForwardWord           = 'Ctrl+f', 'Ctrl+RightArrow' # Ctrl+f is default
        KillWord              = 'Ctrl+Delete'
        MenuComplete          = 'Ctrl+Spacebar',
                                'Ctrl+D2' # needed for Linux/macOS (not Cmd+D2)
        NextWord              = 'Ctrl+RightArrow'
        Paste                 = 'Ctrl+v'
        Redo                  = 'Ctrl+y'
        RevertLine            = 'Escape'
        SelectAll             = 'Ctrl+a'
        SelectBackwardChar    = 'Shift+LeftArrow'
        SelectBackwardsLine   = 'Shift+Home'
        SelectBackwardWord    = 'Shift+Ctrl+LeftArrow'
        SelectCommandArgument = 'Alt+a' # Need to enable Alt key in macOS Terminal or iTerm2
        SelectForwardChar     = 'Shift+RightArrow'
        SelectLine            = 'Shift+End'
        SelectNextWord        = 'Shift+Ctrl+RightArrow'
        ShowCommandHelp       = 'F1'
        ShowParameterHelp     = 'Alt+h' # Need to enable Alt key in macOS Terminal or iTerm2
        SwitchPredictionView  = 'F2'
        TabCompleteNext       = 'Tab'
        TabCompletePrevious   = 'Shift+Tab'
        Undo                  = 'Ctrl+z'
        ValidateAndAcceptLine = 'Enter'
    }

    foreach ($key in $keymap.Keys) {
        foreach ($chord in $keymap[$key]) {
            Set-PSReadLineKeyHandler -Function $key -Chord $chord
        }
    }
}
## Add Dongbo's custom history handler to filter out:
## - Commands with 3 or fewer characters
## - Commands that start with a space
## - Commands that end with a semicolon
## - Start with a space or end with a semicolon if you want the command to be omitted from history
##   - Useful for filtering out sensitive commands you don't want recorded in history
$global:__defaultHistoryHandler = (Get-PSReadLineOption).AddToHistoryHandler
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$line)

    $defaultResult = $global:__defaultHistoryHandler.Invoke($line)
    if ($defaultResult -eq "MemoryAndFile") {
        if ($line.Length -gt 3 -and $line[0] -ne ' ' -and $line[-1] -ne ';') {
            return "MemoryAndFile"
        } else {
            return "MemoryOnly"
        }
    }
    return $defaultResult
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Color theme settings
#-------------------------------------------------------
Write-Verbose 'Color theme settings...'
$PSStyle.Progress.UseOSCIndicator = $true
$PSStyle.OutputRendering = 'Host'
$PSStyle.FileInfo.Directory = $PSStyle.Background.FromRgb(0x2f6aff) + $PSStyle.Foreground.BrightWhite
& {
    $PSROptions = @{
        Colors             = @{
            Operator         = $PSStyle.Foreground.BrightMagenta
            Parameter        = $PSStyle.Foreground.BrightMagenta
            Selection        = $PSStyle.Foreground.BrightGreen + $PSStyle.Background.BrightBlack
            InLinePrediction = $PSStyle.Background.BrightBlack
        }
    }
    Set-PSReadLineOption @PSROptions
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Prompts
#-------------------------------------------------------
Write-Verbose 'Setting up prompts...'
$global:Prompts = @{
    Current       = 'PoshGitPrompt'
    DefaultPrompt = {
        Set-PSReadLineOption -ContinuationPrompt '>> ' -PromptText @('> ')

        if ((Test-Path Variable:/PSDebugContext) -or
            [runspace]::DefaultRunspace.Debugger.InBreakpoint) {
            "[DBG]: PS $($pwd.Path)$('>' * ($nestedPromptLevel + 1)) "
        } else {
            "PS $($pwd.Path)$('>' * ($nestedPromptLevel + 1)) "
        }
        # .Link
        # https://go.microsoft.com/fwlink/?LinkID=225750
        # .ExternalHelp System.Management.Automation.dll-help.xml
    }
    MyPrompt      = {
        # Prompt-specific settings for posh-git
        Set-PSReadLineOption -ContinuationPrompt '❯❯ ' -PromptText @('❯ ')
        $GitPromptSettings.BeforeStatus = $PSStyle.Foreground.Yellow + '❮' + $PSStyle.Reset
        $GitPromptSettings.AfterStatus = $PSStyle.Foreground.Yellow + '❯' + $PSStyle.Reset

        $ghstatus = Get-GitStatus
        $strPrompt = @(
            { $PSStyle.Foreground.BrightBlue + $PSStyle.Background.Black }
            { "PS $($PSVersionTable.PSVersion)" }
            { $PSStyle.Foreground.Black + $PSStyle.Background.BrightBlue }
            { Get-GitRemoteLink }
            { $PSStyle.Foreground.BrightBlue + $PSStyle.Background.BrightCyan + '' }
            { $PSStyle.Foreground.Black + $PSStyle.Background.BrightCyan }
            { Get-GitRemoteLink -BranchUrl }
            { $PSStyle.Foreground.BrightCyan + $PSStyle.Background.Black + '' }
            { Get-MyGitBranchStatus $ghstatus }
            { $PSStyle.Reset }
            { [System.Environment]::NewLine }
            {
                $uri = "file://$($pwd.Path -replace '\\','/')"
                $path = $PSStyle.FormatHyperlink($pwd.Path, $uri)
                if ($ghstatus) {
                    $repopath = $git_repos[$ghstatus.RepoName].path
                    if ($null -ne $repopath) {
                        $gitpath = $pwd.Path -replace [regex]::Escape($repopath), '[git]:'
                        $path = $PSStyle.FormatHyperlink($gitpath, $uri)
                    }
                }
                if ((Test-Path Variable:/PSDebugContext) -or
                    [runspace]::DefaultRunspace.Debugger.InBreakpoint) {
                    "[DBG]: $path$('❯' * ($nestedPromptLevel + 1)) "
                } else {
                    "$path$('❯' * ($nestedPromptLevel + 1)) "
                }
            }
        )
        -join $strPrompt.Invoke()
    }
    PoshGitPrompt = {
        # Prompt-specific settings for posh-git
        Set-PSReadLineOption -ContinuationPrompt '>> ' -PromptText @('> ')
        $GitPromptSettings.BeforeStatus = $PSStyle.Foreground.BrightYellow + '[' + $PSStyle.Reset
        $GitPromptSettings.AfterStatus = $PSStyle.Foreground.BrightYellow + ']' + $PSStyle.Reset
        (& $GitPromptScriptBlock)
    }
    SimplePrompt  = {
        Set-PSReadLineOption -ContinuationPrompt '>> ' -PromptText @('> ')
        'PS> '
    }
}
$function:prompt = $global:Prompts.PoshGitPrompt
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region DefaultParameterValues
#-------------------------------------------------------
$PSDefaultParameterValues = @{
    'Out-Default:OutVariable'           = 'LastResult'  # Save output to $LastResult
    'Out-File:Encoding'                 = 'utf8'        # PS5.1 defaults to ASCII
    'Export-Csv:NoTypeInformation'      = $true         # PS5.1 defaults to $false
    'ConvertTo-Csv:NoTypeInformation'   = $true         # PS5.1 defaults to $false
    'Receive-Job:Keep'                  = $true         # Prevents accidental loss of output
    'Install-Module:AllowClobber'       = $true         # Default behavior in Install-PSResource
    'Install-Module:Force'              = $true         # Default behavior in Install-PSResource
    'Install-Module:SkipPublisherCheck' = $true         # Default behavior in Install-PSResource
    'Find-Module:Repository'            = 'PSGallery'   # Useful if you have private test repos
    'Install-Module:Repository'         = 'PSGallery'   # Useful if you have private test repos
    'Find-PSResource:Repository'        = 'PSGallery'   # Useful if you have private test repos
    'Install-PSResource:Repository'     = 'PSGallery'   # Useful if you have private test repos
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Helper functions & aliases
#-------------------------------------------------------
# Helper functions for customizing the prompt
function Get-GitRemoteLink {
    param( [switch]$BranchUrl )
    $ghstatus = Get-GitStatus
    if ($ghstatus) {
        $remote = ''
        if ($null -ne $ghstatus.Upstream) {
            $rname = ($ghstatus.Upstream -split '/')[0]
        } else {
            $rname = (git remote)[-1]
        }
        $remote = (git remote get-url $rname) -replace '\.git$'
        if ($BranchUrl) {
            if ($null -ne $ghstatus.Upstream) {
                $remote = "$remote/tree/$($ghstatus.Branch)"
                $PSStyle.FormatHyperlink($ghstatus.Branch, $remote)
            } else {
                $ghstatus.Branch
            }
        } else {
            $PSStyle.FormatHyperlink($ghstatus.RepoName, $remote)
        }
    } else {
        $null
    }
}
#-------------------------------------------------------
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
    $sb | Write-Prompt $s.AfterStatus > $null

    if ($sb.Length -gt 0) {
        $sb.ToString()
    }
}
#-------------------------------------------------------
function Switch-Prompt {
    param(
        [Parameter(Position = 0)]
        [ValidateSet('MyPrompt', 'PoshGitPrompt', 'DefaultPrompt', 'SimplePrompt')]
        [string]$FunctionName
    )

    if ([string]::IsNullOrEmpty($FunctionName)) {
        # Switch to the next prompt in rotation
        switch ($global:Prompts.Current) {
            'MyPrompt' { $FunctionName = 'PoshGitPrompt' }
            'PoshGitPrompt' { $FunctionName = 'DefaultPrompt' }
            'DefaultPrompt' { $FunctionName = 'SimplePrompt' }
            'SimplePrompt' { $FunctionName = 'MyPrompt' }
            Default { $FunctionName = 'MyPrompt' }
        }
    }
    $global:Prompts.Current = $FunctionName
    $function:prompt = $global:Prompts.$FunctionName

}
Set-Alias -Name swp -Value Switch-Prompt
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Initialize Environment
#-------------------------------------------------------
& {
    $pkgBase = "$env:ProgramW6432\PackageManagement\NuGet\Packages"
    $taglibBase = "$pkgBase\TagLibSharp.2.2.0\lib"
    $kustoBase = "$pkgBase\Microsoft.Azure.Kusto.Tools.6.0.3\tools"
    #$sqliteBase = "$env:ProgramW6432\System.Data.SQLite"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $taglib = "$taglibBase\netstandard2.0\TagLibSharp.dll"
        $null = [Reflection.Assembly]::LoadFrom($taglib)
        $kusto = "$kustoBase\netcoreapp2.1\Kusto.Data.dll"
        $null = [Reflection.Assembly]::LoadFrom($kusto)
    #    Add-Type -Path "$sqliteBase\netstandard2.1\System.Data.SQLite.dll"
    } else {
        $taglib = "$taglibBase\net45\TagLibSharp.dll"
        $null = [Reflection.Assembly]::LoadFrom($taglib)
        $kusto = "$kustoBase\net472\Kusto.Data.dll"
        $null = [Reflection.Assembly]::LoadFrom($kusto)
    #    Add-Type -Path "$sqliteBase\net46\System.Data.SQLite.dll"
    }
}
'Loading modules...'
Import-Module sdwheeler.GitTools -Force:$Force
Import-Module sdwheeler.EssentialUtils -Force:$Force
Import-Module sdwheeler.ContentUtils -Force:$Force
Import-Module sdwheeler.PSUtils -Force:$Force
if ($PSVersionTable.PSVersion -gt '6.0') {
    Import-Module Documentarian -Force:$Force
    Import-Module Documentarian.ModuleAuthor -Force:$Force
    Import-Module Documentarian.MicrosoftDocs -Force:$Force
    Set-Alias bcsync Sync-BeyondCompare
    Set-Alias vscsync Sync-VSCode
}

#endregion
#-------------------------------------------------------
#region Collect repo information
#-------------------------------------------------------
# Check for Git folder in the root of each drive
# If found, add it to the list of possible repo roots
$global:gitRepoRoots = @()
& {
    $gitFolders = 'My-Repos', 'PS-Docs', 'PS-Src', 'AzureDocs', 'AzureSrc', 'Learn', 'Windows',
        'APEX', 'PS-Other', 'Community', 'Conferences', 'Collabs', 'MAGIC', 'Other'
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $gitPath = Join-Path $drive.Root 'Git'
        if (Test-Path $gitPath) {
            $gitFolders | ForEach-Object {
                $gitFolder = Join-Path $gitPath $_
                if (Test-Path $gitFolder) { $global:gitRepoRoots += $gitFolder }
            }
        }
    }
}
function Get-RepoCacheAge {
    if (Test-Path ~/repocache.clixml) {
        ((Get-Date) - (Get-Item ~/repocache.clixml).LastWriteTime).TotalDays
    } else {
        [double]::MaxValue
    }
}

& {
    if (Test-Path ~/repocache.clixml) {
        $cacheage = Get-RepoCacheAge
    }
    if ($cacheage -lt 8 -or
        $null -eq (Test-Connection github.com -ea SilentlyContinue -Count 1)) {
        'Loading repo cache...'
        $global:git_repos = Import-Clixml -Path ~/repocache.clixml
    } else {
        'Scanning repos...'
        Get-MyRepos $gitRepoRoots #-Verbose:$Verbose
    }
}

Set-Location (Get-Item $gitRepoRoots[0]).Parent.FullName

$function:prompt = $Prompts.MyPrompt

#-------------------------------------------------------
#endregion
#-------------------------------------------------------

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
if ($PSVersionTable.PSVersion.ToString() -ge '7.4.0') {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
#f45873b3-b655-43a6-b217-97c00aa0db58
