<#
    Author        = 'Jeff Hicks'
    CompanyName   = 'JDH Information Technology Solutions, Inc.'
    Copyright     = '(c) 2017-2022 JDH Information Technology Solutions, Inc.'
    ProjectUrl    = 'https://github.com/jdhitsolutions/PSScriptTools'
#>

function Convert-CommandToHashtable {
    [cmdletbinding()]
    [OutputType('[System.String]')]

    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        #"Enter a PowerShell expression with full parameter names"
        [string]$Text
    )

    Set-StrictMode -Version latest

    New-Variable astTokens -Force
    New-Variable astErr -Force

    #trim spaces
    $Text = $Text.trim()
    Write-Verbose "Converting $text"

    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$astTokens, [ref]$astErr)

    #resolve the command name
    $cmdType = Get-Command $asttokens[0].text
    if ($cmdType.CommandType -eq 'Alias') {
        $cmd = $cmdType.ResolvedCommandName
    } else {
        $cmd = $cmdType.Name
    }

    #last item is end of input token
    $r = for ($i = 1; $i -lt $astTokens.count - 1 ; $i++) {
        if ($astTokens[$i].ParameterName) {
            $p = $astTokens[$i].ParameterName
            $v = ''
            #check next token
            if ($astTokens[$i + 1].Kind -match 'Parameter|EndOfInput') {
                #the parameter must be a switch
                $v = "`$True"
            } else {
                While ($astTokens[$i + 1].Kind -notmatch 'Parameter|EndOfInput') {
                    $i++
                    #test if value is a string and if it is quoted, if not include quotes
                    #if ($astTokens[$i].Kind -eq "Identifier" -AND $astTokens[$i].Text -notmatch """\w+.*""" -AND $astTokens[$i].Text -notmatch "'\w+.*'") {
                    if ($astTokens[$i].Text -match '\D' -AND $astTokens[$i].Text -notmatch '"\w+.*"' -AND $astTokens[$i].Text -notmatch "'\w+.*'") {
                        #ignore commas and variables
                        if ($astTokens[$i].Kind -match 'Comma|Variable') {
                            $value = $astTokens[$i].Text
                        } else {
                            #Assume text and quote it
                            $value = """$($astTokens[$i].Text)"""
                        }
                    } else {
                        $value = $astTokens[$i].Text
                    }
                    $v += $value
                } #while
            }
            #don't add a line return if this is going to be the last item
            if ($i + 1 -ge $astTokens.count - 1) {
                "  $p = $v"
            } else {
                "  $p = $v`n"
            }
        } #if ast parameter name

    } #for

    $hashtext = @"
`$paramHash = @{
$r
}
$cmd @paramHash
"@

    $hashtext
}
