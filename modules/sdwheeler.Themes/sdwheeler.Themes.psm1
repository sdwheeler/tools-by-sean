#-------------------------------------------------------
#region module variables
#-------------------------------------------------------
$script:VSCodeUserPath     = "$HOME/.vscode/extensions"
$script:VSCodeExtPath      = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\resources\app\extensions"
$script:WTSettingsPath     = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$script:VSCodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
$script:VSCodeThemeCache   = @()
#-------------------------------------------------------
#endregion Global variables
#-------------------------------------------------------
#region Theme definitions
#-------------------------------------------------------
$MyPSStyles = @{
    Dark = [pscustomobject]@{
        Name        = 'Dark theme'
        PSTypeName    = 'ThemeType'
        Formatting  = [pscustomobject]@{
            FormatAccent           = $PSStyle.Foreground.Green + $PSStyle.Bold
            ErrorAccent            = $PSStyle.Foreground.Cyan + $PSStyle.Bold
            Error                  = $PSStyle.Foreground.Red + $PSStyle.Bold
            Warning                = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            Verbose                = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            Debug                  = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            TableHeader            = $PSStyle.Foreground.Green + $PSStyle.Bold
            CustomTableHeaderLabel = $PSStyle.Foreground.Green + $PSStyle.Bold + $PSStyle.Italic
            FeedbackName           = $PSStyle.Foreground.Yellow
            FeedbackText           = $PSStyle.Foreground.BrightCyan
            FeedbackAction         = $PSStyle.Foreground.BrightWhite
        }
        Progress    = [pscustomobject]@{
            PSTypeName             = 'ThemeType.Progress'
            Style                  = $PSStyle.Foreground.Yellow + $PSStyle.Bold
        }
        FileInfo    = [pscustomobject]@{
            PSTypeName             = 'ThemeType.FileInfo'
            Directory              = $PSStyle.Background.FromRgb(0x2f6aff) +
                                     $PSStyle.Foreground.BrightWhite
            SymbolicLink           = $PSStyle.Foreground.Cyan + $PSStyle.Bold
            Executable             = $PSStyle.Foreground.Green + $PSStyle.Bold
            Extension              = @{
                '.zip'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.tgz'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.gz'      = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.tar'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.nupkg'   = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.cab'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.7z'      = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.ps1'     = $PSStyle.Foreground.Yellow + $PSStyle.Bold
                '.psd1'    = $PSStyle.Foreground.Yellow + $PSStyle.Bold
                '.psm1'    = $PSStyle.Foreground.Yellow + $PSStyle.Bold
                '.ps1xml'  = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            }
        }
        PSReadLine  = [pscustomobject]@{
            PSTypeName             = 'ThemeType.PSReadline'
            Command                = $PSStyle.Foreground.BrightYellow
            Comment                = $PSStyle.Foreground.Green
            ContinuationPrompt     = $PSStyle.Foreground.White
            Default                = $PSStyle.Foreground.White
            Emphasis               = $PSStyle.Foreground.BrightCyan
            Error                  = $PSStyle.Foreground.BrightRed
            InlinePrediction       = $PSStyle.Background.BrightBlack
            Keyword                = $PSStyle.Foreground.BrightGreen
            ListPrediction         = $PSStyle.Foreground.Yellow
            ListPredictionSelected = $PSStyle.Foreground.FromRgb(0x444444) # Darker grey
            ListPredictionTooltip  = $PSStyle.Foreground.White + $PSStyle.Dim + $PSStyle.Italic
            Member                 = $PSStyle.Foreground.White
            Number                 = $PSStyle.Foreground.BrightWhite
            Operator               = $PSStyle.Foreground.BrightMagenta
            Parameter              = $PSStyle.Foreground.BrightMagenta
            Selection              = $PSStyle.Foreground.BrightGreen +
                                     $PSStyle.Background.BrightBlack
            String                 = $PSStyle.Foreground.Cyan
            Type                   = $PSStyle.Foreground.White
            Variable               = $PSStyle.Foreground.BrightGreen
        }
    }
    ISE = [pscustomobject]@{
        Name        = 'ISE theme'
        PSTypeName    = 'ThemeType'
        Formatting  = [pscustomobject]@{
            PSTypeName             = 'ThemeType.Formatting'
            CustomTableHeaderLabel = $PSStyle.Foreground.Green + $PSStyle.Bold + $PSStyle.Italic
            Debug                  = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            Error                  = $PSStyle.Foreground.Red + $PSStyle.Bold
            ErrorAccent            = $PSStyle.Foreground.Cyan + $PSStyle.Bold
            FeedbackAction         = $PSStyle.Foreground.BrightWhite
            FeedbackName           = $PSStyle.Foreground.Yellow
            FeedbackText           = $PSStyle.Foreground.BrightCyan
            FormatAccent           = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            TableHeader            = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            Verbose                = $PSStyle.Foreground.Yellow + $PSStyle.Bold
            Warning                = $PSStyle.Foreground.Yellow + $PSStyle.Bold
        }
        Progress    = [pscustomobject]@{
            PSTypeName             = 'ThemeType.Progress'
            Style                  = $PSStyle.Foreground.Yellow + $PSStyle.Bold
        }
        FileInfo    = [pscustomobject]@{
            PSTypeName             = 'ThemeType.FileInfo'
            Directory              = $PSStyle.Background.FromRgb(0x2f6aff) +
                                     $PSStyle.Foreground.BrightWhite
            SymbolicLink           = $PSStyle.Foreground.BrightBlue + $PSStyle.Bold
            Executable             = $PSStyle.Foreground.BrightMagenta + $PSStyle.Bold
            Extension              = @{
                '.zip'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.tgz'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.gz'      = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.tar'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.nupkg'   = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.cab'     = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.7z'      = $PSStyle.Foreground.Red + $PSStyle.Bold
                '.ps1'     = $PSStyle.Foreground.Cyan + $PSStyle.Bold
                '.psd1'    = $PSStyle.Foreground.Cyan + $PSStyle.Bold
                '.psm1'    = $PSStyle.Foreground.Cyan + $PSStyle.Bold
                '.ps1xml'  = $PSStyle.Foreground.Cyan + $PSStyle.Bold
            }
        }
        PSReadLine  = [pscustomobject]@{
            PSTypeName             = 'ThemeType.PSReadline'
            Command                = $PSStyle.Foreground.FromRGB(0x0000FF)
            Comment                = $PSStyle.Foreground.FromRGB(0x006400)
            ContinuationPrompt     = $PSStyle.Foreground.FromRGB(0x0000FF)
            Default                = $PSStyle.Foreground.FromRGB(0x0000FF)
            Emphasis               = $PSStyle.Foreground.FromRGB(0x287BF0)
            Error                  = $PSStyle.Foreground.FromRGB(0xE50000)
            InlinePrediction       = $PSStyle.Foreground.FromRGB(0x93A1A1)
            Keyword                = $PSStyle.Foreground.FromRGB(0x00008b)
            ListPrediction         = $PSStyle.Foreground.FromRGB(0x06DE00)
            Member                 = $PSStyle.Foreground.FromRGB(0x000000)
            Number                 = $PSStyle.Foreground.FromRGB(0x800080)
            Operator               = $PSStyle.Foreground.FromRGB(0x757575)
            Parameter              = $PSStyle.Foreground.FromRGB(0x000080)
            String                 = $PSStyle.Foreground.FromRGB(0x8b0000)
            Type                   = $PSStyle.Foreground.FromRGB(0x008080)
            Variable               = $PSStyle.Foreground.FromRGB(0xff4500)
            ListPredictionSelected = $PSStyle.Background.FromRGB(0x93A1A1)
            Selection              = $PSStyle.Background.FromRGB(0x00BFFF)
        }
    }
}
#-------------------------------------------------------
#endregion Theme definitions
#-------------------------------------------------------
#region Shell theme functions
#-------------------------------------------------------
function Get-ShellTheme {
    param(
        [string[]]$Theme = $MyPSStyles.Keys
    )

    foreach ($item in $Theme) {
        $MyPSStyles[$item]
    }
}

function Set-ShellTheme {
    param(
        [Parameter(Mandatory)]
        [string]$Theme
    )

    foreach ($key in $MyPSStyles.$Theme.Formatting.Keys) {
        $PSStyle.Formatting.$key = $MyPSStyles.$Theme.Formatting.$key
    }

    $PSStyle.Progress.Style = $MyPSStyles.$Theme.Progress.Style

    $PSStyle.FileInfo.Directory    = $MyPSStyles.$Theme.FileInfo.Directory
    $PSStyle.FileInfo.Executable   = $MyPSStyles.$Theme.FileInfo.Executable
    $PSStyle.FileInfo.SymbolicLink = $MyPSStyles.$Theme.FileInfo.SymbolicLink
    foreach ($key in $MyPSStyles.$Theme.FileInfo.Extension.Keys) {
        $PSStyle.FileInfo.Extension[$key] = $MyPSStyles.$Theme.FileInfo.Extension[$key]
    }
    $psrColors = @{}
    foreach ($key in $MyPSStyles.$Theme.PSReadLine.PSObject.Properties.Name) {
        $psrColors[$key] = $MyPSStyles.$Theme.PSReadLine.$key
    }
    Set-PSReadLineOption -Colors $psrColors
}

$ArgumentCompleterSplat = @{
    CommandName = 'Set-ShellTheme','Get-ShellTheme'
    ParameterName = 'Theme'
    ScriptBlock = {
        param ( $commandName,
                $parameterName,
                $wordToComplete,
                $commandAst,
                $fakeBoundParameters )
        $MyPSStyles.Keys | Where-Object { $_ -like "$wordToComplete*" }
    }
}
Register-ArgumentCompleter @ArgumentCompleterSplat
#-------------------------------------------------------
#endregion Shell theme functions
#-------------------------------------------------------
#region VSCode functions
#-------------------------------------------------------
function Get-VSCodeThemes {
    if ($script:VSCodeThemeCache.Count -eq 0) {
        $pkgs = code --list-extensions | ForEach-Object {
            Get-ChildItem (Join-Path $VSCodeUserPath "$_*" package.json)
        }
        $theme = $pkgs | ForEach-Object {
            (Get-Content $_ | ConvertFrom-Json).contributes.themes.label
        }

        $pkgs = Get-ChildItem (Join-Path $VSCodeExtPath 'theme-*' package.json)
        $theme += $pkgs | ForEach-Object {
            (Get-Content $_ | ConvertFrom-Json -depth 10).contributes.themes.id
        }
        $script:VSCodeThemeCache = $theme | Sort-Object -Unique
    }
    $script:VSCodeThemeCache
}
function Set-VSCodeTheme {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrWhiteSpace()]
        [string]$Theme
    )

    $pattern  = '"workbench\.colorTheme": ".*"'
    $newvalue = '"workbench.colorTheme": "{0}"' -f $Theme

    $settings = Get-Content $VSCodeSettingsPath
    if ($settings -match $pattern) {
        $settings = $settings -replace $pattern, $newvalue
        Set-Content -Value $settings -Path $VSCodeSettingsPath -Force
    } else {
        Write-Error "Could not find 'workbench.colorTheme' in $VSCodeSettingsPath"
    }
}

$ArgumentCompleterSplat = @{
    CommandName = 'Set-VSCodeTheme'
    ParameterName = 'Theme'
    ScriptBlock = {
        param ( $commandName,
                $parameterName,
                $wordToComplete,
                $commandAst,
                $fakeBoundParameters )
        Get-VSCodeThemes | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { "'$_'" }
    }
}
Register-ArgumentCompleter @ArgumentCompleterSplat
#-------------------------------------------------------
#endregion VSCode functions
#-------------------------------------------------------
#region Windows Terminal functions
function Get-WindowsTerminalThemes {
    [CmdletBinding()]
    param(
        [SupportsWildcards()]
        [string]$Theme = '*',

        [switch]$ShowColors
    )
    $settings = Get-Content $WTSettingsPath | ConvertFrom-Json
    if ($ShowColors) {
        $settings.schemes | ForEach-Object {
            $_.pstypenames.Insert(0, 'WTSchemeType')
        }
        $settings.schemes | Where-Object name -like $Theme
    } else {
        $settings.schemes | Where-Object name -like $Theme | Select-Object -ExpandProperty name
    }
}

function Get-WindowsTerminalProfiles {
    $settings = Get-Content $WTSettingsPath | ConvertFrom-Json
    $settings.profiles.list | Select-Object name, colorScheme, guid
}

function Set-WindowsTerminalTheme {
    param(
        [Parameter(Position = 0, ParameterSetName = 'byProfileId')]
        [Parameter(Position = 0, ParameterSetName = 'byProfileName')]
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrWhiteSpace()]
        [string]$Theme,

        [Parameter(Position = 1, ParameterSetName = 'byProfileId')]
        [ValidateNotNullOrWhiteSpace()]
        [string]$ProfileId = $env:WT_PROFILE_ID,

        [Parameter(ParameterSetName = 'byProfileName')]
        [ValidateNotNullOrWhiteSpace()]
        [string]$ProfileName
    )
    $settings = Get-Content $WTSettingsPath | ConvertFrom-Json

    if ($PSCmdlet.ParameterSetName -eq 'byProfileName') {
        $ProfileId = ($settings.profiles.list | Where-Object name -eq $ProfileName).guid
    }

    $vscprofile = $settings.profiles.list | Where-Object guid -eq $ProfileId
    if ($vscprofile.psobject.Properties.Name -contains 'colorScheme') {
        $vscprofile.colorScheme = $Theme
    } else {
        $vscprofile | Add-Member -MemberType NoteProperty -Name colorScheme -Value $Theme
    }
    $settings | ConvertTo-Json -Depth 20 | Out-File $WTSettingsPath -Force -Encoding utf8BOM
}

$ArgumentCompleterSplat = @{
    CommandName = 'Set-WindowsTerminalTheme', 'Get-WindowsTerminalThemes'
    ScriptBlock = {
        param ( $commandName,
                $parameterName,
                $wordToComplete,
                $commandAst,
                $fakeBoundParameters )
        switch ($parameterName) {
            'ProfileId' {
                Get-WindowsTerminalProfiles |
                    Where-Object { $_.guid -like "$wordToComplete*" } |
                    Select-Object -ExpandProperty guid |
                    ForEach-Object { "'$_'" }
            }
            'ProfileName' {
                Get-WindowsTerminalProfiles |
                    Where-Object { $_.name -like "$wordToComplete*" } |
                    Select-Object -ExpandProperty name |
                    ForEach-Object { "'$_'" }
            }
            'Theme' {
                Get-WindowsTerminalThemes |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object { "'$_'" }
            }
        }
    }
}
foreach ($ParameterName in 'Theme', 'ProfileId', 'ProfileName') {
    Register-ArgumentCompleter -ParameterName $ParameterName @ArgumentCompleterSplat
}
#-------------------------------------------------------
#endregion Windows Terminal functions
#-------------------------------------------------------
