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

function Get-ThemeColors {
    param(
        [string[]]$Theme = $MyPSStyles.Keys
    )

    foreach ($item in $Theme) {
        $MyPSStyles[$item]
    }
}

function Set-ThemeColors {
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

$registerArgumentCompleterSplat = @{
    CommandName = 'Set-ThemeColors','Get-ThemeColors'
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
Register-ArgumentCompleter @registerArgumentCompleterSplat
