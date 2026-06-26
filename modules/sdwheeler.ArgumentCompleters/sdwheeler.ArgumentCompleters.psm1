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
function Get-ArgumentCompleter {
    param(
        [switch]$Native,
        [switch]$Custom
    )
    $flags = [Reflection.BindingFlags]'Instance,NonPublic'
    $field = [System.Management.Automation.EngineIntrinsics].GetField('_context', $flags)
    $internalExecutionContext = $field.GetValue($ExecutionContext)
    $customCompletersObject = $internalExecutionContext.GetType().GetProperty('CustomArgumentCompleters', $flags)
    $customCompleters = $customCompletersObject.GetValue($internalExecutionContext)
    $argumentCompleters = foreach ($completer in $customCompleters.GetEnumerator()) {
        [pscustomobject]@{
            PSTypeName  = 'ArgumentCompleterInfo'
            Collection  = 'Custom'
            Binding     = $completer.Key
            Source      = $completer.Value.Module.Name
            Location    = $completer.Value.Module.Path
            ScriptBlock = $completer.Value
        }
    }
    $nativeCompletersObject = $internalExecutionContext.GetType().GetProperty('NativeArgumentCompleters', $flags)
    $nativeCompleters = $nativeCompletersObject.GetValue($internalExecutionContext)
    $argumentCompleters += foreach ($completer in $nativeCompleters.GetEnumerator()) {
        [pscustomobject]@{
            PSTypeName  = 'ArgumentCompleterInfo'
            Collection  = 'Native'
            Binding     = $completer.Key
            Source      = $completer.Value.Module.Name
            Location    = $completer.Value.Module.Path
            ScriptBlock = $completer.Value
        }
    }
    if ($Native -and -not $Custom) {
        $argumentCompleters = $argumentCompleters | Where-Object Collection -eq 'Native'
    } elseif ($Custom -and -not $Native) {
        $argumentCompleters = $argumentCompleters | Where-Object Collection -eq 'Custom'
    }
    $argumentCompleters | Sort-Object Collection, Source, Binding
}
