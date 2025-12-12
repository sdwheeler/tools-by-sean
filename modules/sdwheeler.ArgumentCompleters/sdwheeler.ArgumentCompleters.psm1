#-------------------------------------------------------
$pwshParams = (pwsh -h | Select-String '^-').Line |
    Sort-Object |
    ForEach-Object {
        $line = $_
        $params = $line.split('|').split(',').Trim()
        foreach ($p in $params) {
            if ($params.Count -gt 1) {
                [System.Management.Automation.CompletionResult]::new($params[0], $p, 'ParameterValue', $line)
            } else {
                [System.Management.Automation.CompletionResult]::new($p, $p, 'ParameterValue', $line)
            }
        }
    }
#-------------------------------------------------------
$powershellParams = (powershell -h | Select-String '^-').Line |
    Sort-Object |
    ForEach-Object {
        $line = $_
        $params = $line.split('|').split(',').Trim()
        foreach ($p in $params) {
            if ($params.Count -gt 1) {
                [System.Management.Automation.CompletionResult]::new($params[0], $p, 'ParameterValue', $line)
            } else {
                [System.Management.Automation.CompletionResult]::new($p, $p, 'ParameterValue', $line)
            }
        }
    }
#-------------------------------------------------------
$nativeCommands = @{
    pwsh       = {
        param($wordToComplete, $commandAst, $cursorPosition)
        $pwshParams | Where-Object { $_.CompletionText -like "$wordToComplete*" }
    }
    powershell = {
        param($wordToComplete, $commandAst, $cursorPosition)
        $powershellParams | Where-Object { $_.CompletionText -like "$wordToComplete*" }
    }
    winget    = {
        param($wordToComplete, $commandAst, $cursorPosition)
            [Console]::InputEncoding =
                [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
            $Local:word = $wordToComplete.Replace('"', '""')
            $Local:ast = $commandAst.ToString().Replace('"', '""')
            winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }
}
#-------------------------------------------------------
foreach ($cmd in $nativeCommands.Keys) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName $cmd -ScriptBlock $nativeCommands[$cmd]
    }
}
Invoke-Expression -Command $(gh completion -s powershell | Out-String)
#-------------------------------------------------------
function Get-MyArgumentCompleter {
    [CmdletBinding()]

    param(
        [SupportsWildcards()]
        [string]$NativeCommand = '*'
    )

    $nativeCommands | Where-Object { $_.Name -like $NativeCommand }
}
