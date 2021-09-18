# Module created by Microsoft.PowerShell.Crescendo
class PowerShellCustomFunctionAttribute : System.Attribute { 
    [bool]$RequiresElevation
    [string]$Source
    PowerShellCustomFunctionAttribute() { $this.RequiresElevation = $false; $this.Source = "Microsoft.PowerShell.Crescendo" }
    PowerShellCustomFunctionAttribute([bool]$rElevation) {
        $this.RequiresElevation = $rElevation
        $this.Source = "Microsoft.PowerShell.Crescendo"
    }
}

function ParseProvider {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )

    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i+=2) {
        if ($textBlocks[$i] -ne '') {
            $hash = @{}
            $kvpairs = $textBlocks[$i].Split("`r`n").Split(':').Trim()

            for ($x = 0; $x -lt $kvpairs.Count; $x++) {
                switch ($kvpairs[$x]) {
                    'Provider name' {
                        $hash.Add('Name',$kvpairs[$x+1].Trim("'"))
                    }
                    'Provider type' {
                        $hash.Add('Type',$kvpairs[$x+1])
                    }
                    'Provider Id' {
                        $hash.Add('Id',([guid]($kvpairs[$x+1])))
                    }
                    'Version' {
                        $hash.Add('Version',[version]$kvpairs[$x+1])
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}


function Get-VssProvider
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding()]

param(    )

BEGIN {
    $__PARAMETERMAP = @{}
    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseProvider' }
    }
}

PROCESS {
    $__commandArgs = @(
        'list'
        'providers'
    )
    $__boundparms = $PSBoundParameters
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})
    if ($PSBoundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $PSBoundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }
            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }
            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}
        }
    }
    $__commandArgs = $__commandArgs|Where-Object {$_}
    if ($PSBoundParameters["Debug"]){wait-debugger}
    if ( $PSBoundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message $env:Windir/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("$env:Windir/system32/vssadmin.exe $__commandArgs")) {
        if ( $__handlerInfo.StreamOutput ) {
            & "$env:Windir/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "$env:Windir/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List registered volume shadow copy providers

.DESCRIPTION
List registered volume shadow copy providers

#>
}


function ParseShadow {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = $textBlocks[$i].Split("`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'set ID:' {
                        $id = [guid]$line.Split(':')[1].Trim()
                        $hash.Add('SetId',$id)
                    }
                    'creation time:' {
                        $datetime = [datetime]$line.Split('time:')[1]
                        $hash.Add('CreateTime',$datetime)
                    }
                    'Copy ID:' {
                        $id = [guid]$line.Split(':')[1].Trim()
                        $hash.Add('CopyId',$id)
                    }
                    'Original Volume:' {
                        $value = $line.split('Volume:')[1].Trim()
                        if ($value -match '^\((?<name>[A-Z]:)\)(?<path>\\{2}.+\\$)') {
                            $volinfo = [pscustomobject]@{
                                Name = $Matches.name
                                Path = $Matches.path
                            }
                        }
                        $hash.Add('OriginalVolume',$volinfo)
                    }
                    'Copy Volume:' {
                        $hash.Add('ShadowCopyVolume', $line.Split(':')[1].Trim())
                    }
                    'Machine:' {
                        $parts = $line.Split(':')
                        $hash.Add($parts[0].Replace(' ',''), $parts[1].Trim())
                    }
                    'Provider:' {
                        $hash.Add('ProviderName',$line.Split(': ')[1].Trim("'"))
                    }
                    'Type:' {
                        $hash.Add('Type',$line.Split(':')[1].Trim())
                    }
                    'Attributes' {
                        $attrlist = $line.Split(': ')[1]
                        $hash.Add('Attributes',$attrlist.Split(', '))
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}


function Get-VssShadow
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding(DefaultParameterSetName='Default')]

param(
[Parameter(ParameterSetName='Default')]
[string]$For,
[Parameter(ParameterSetName='Default')]
[string]$Shadow,
[Parameter(ParameterSetName='Default')]
[string]$Set
    )

BEGIN {
    $__PARAMETERMAP = @{
         For = @{
               OriginalName = '/For='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               NoGap = $True
               }
         Shadow = @{
               OriginalName = '/Shadow='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               NoGap = $True
               }
         Set = @{
               OriginalName = '/Set='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               NoGap = $True
               }
    }

    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseShadow' }
    }
}

PROCESS {
    $__commandArgs = @(
        'list'
        'shadows'
    )
    $__boundparms = $PSBoundParameters
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})
    if ($PSBoundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $PSBoundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }
            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }
            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}
        }
    }
    $__commandArgs = $__commandArgs|Where-Object {$_}
    if ($PSBoundParameters["Debug"]){wait-debugger}
    if ( $PSBoundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message $env:Windir/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("$env:Windir/system32/vssadmin.exe $__commandArgs")) {
        if ( $__handlerInfo.StreamOutput ) {
            & "$env:Windir/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "$env:Windir/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List existing volume shadow copies

.DESCRIPTION
List existing volume shadow copies

.PARAMETER For
A volume name like 'C:'


.PARAMETER Shadow
A shadow copy Id in the format of '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'


.PARAMETER Set
A shadow set Id in the format of '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'



#>
}


function ParseShadowStorage {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = $textBlocks[$i].Split("`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'volume:' {
                        $parts = $line.split('volume:')
                        $key = $parts[0].Replace(' ','') + 'Volume'
                        $value = $parts[1].Trim()
                        if ($value -match '^\((?<name>[A-Z]:)\)(?<path>\\{2}.+\\$)') {
                            $volinfo = [pscustomobject]@{
                                Name = $Matches.name
                                Path = $Matches.path
                            }
                        }
                        $hash.Add($key,$volinfo)
                    }
                    'space:' {
                        $parts = $line.Split(':')
                        $key = $parts[0].Split(' ')[0] + 'Space'
                        $data = $parts[1].TrimEnd(')').Split(' (')
                        $space = [PSCustomObject]@{
                            Size = $data[0].Replace(' ','')
                            Percent = $data[1]
                        }
                        $hash.Add($key, $space)
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}


function Get-VssShadowStorage
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding(DefaultParameterSetName='Default')]

param(
[Parameter(ParameterSetName='Default')]
[string]$For,
[Parameter(ParameterSetName='Default')]
[string]$On
    )

BEGIN {
    $__PARAMETERMAP = @{
         For = @{
               OriginalName = '/For='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               NoGap = $True
               }
         On = @{
               OriginalName = '/On='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               NoGap = $True
               }
    }

    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseShadowStorage' }
    }
}

PROCESS {
    $__commandArgs = @(
        'list'
        'ShadowStorage'
    )
    $__boundparms = $PSBoundParameters
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})
    if ($PSBoundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $PSBoundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }
            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }
            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}
        }
    }
    $__commandArgs = $__commandArgs|Where-Object {$_}
    if ($PSBoundParameters["Debug"]){wait-debugger}
    if ( $PSBoundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
        if ( $__handlerInfo.StreamOutput ) {
            & "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List volume shadow copy storage associations

.DESCRIPTION
List volume shadow copy storage associations

.PARAMETER For
A volume name like 'C:'


.PARAMETER On
A volume name like 'C:'



#>
}


function ParseVolume {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = $textBlocks[$i].Split("`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'path:' {
                        $hash.Add('Path',$line.Split(': ')[1].Trim("'"))
                    }
                    'name:' {
                        $hash.Add('Name',$line.Split(': ')[1].Trim("'"))
                        [pscustomobject]$hash
                        $hash = [ordered]@{}
                    }
                }
            }
        }
    }
}


function Get-VssVolume
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding()]

param(    )

BEGIN {
    $__PARAMETERMAP = @{}
    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseVolume' }
    }
}

PROCESS {
    $__commandArgs = @(
        'list'
        'volumes'
    )
    $__boundparms = $PSBoundParameters
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})
    if ($PSBoundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $PSBoundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }
            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }
            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}
        }
    }
    $__commandArgs = $__commandArgs|Where-Object {$_}
    if ($PSBoundParameters["Debug"]){wait-debugger}
    if ( $PSBoundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
        if ( $__handlerInfo.StreamOutput ) {
            & "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List volumes eligible for shadow copies

.DESCRIPTION
List volumes eligible for shadow copies

#>
}


function ParseWriter {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = $textBlocks[$i].Split("`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'name:' {
                        $hash.Add('Name',$line.Split(': ')[1].Trim("'"))
                    }
                    'Id:' {
                        $parts = $line.Split(': ')
                        $key = $parts[0].Replace(' ','')
                        $id = [guid]$parts[1].Trim()
                        $hash.Add($key,$id)
                    }
                    'State:' {
                        $hash.Add('State', $line.Split(': ')[1].Trim())
                    }
                    'error:' {
                        $hash.Add('LastError', $line.Split(': ')[1].Trim())
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}


function Get-VssWriter
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding()]

param(    )

BEGIN {
    $__PARAMETERMAP = @{}
    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseWriter' }
    }
}

PROCESS {
    $__commandArgs = @(
        'list'
        'writers'
    )
    $__boundparms = $PSBoundParameters
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})
    if ($PSBoundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $PSBoundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }
            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }
            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}
        }
    }
    $__commandArgs = $__commandArgs|Where-Object {$_}
    if ($PSBoundParameters["Debug"]){wait-debugger}
    if ( $PSBoundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
        if ( $__handlerInfo.StreamOutput ) {
            & "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List subscribed volume shadow copy writers

.DESCRIPTION
List subscribed volume shadow copy writers

#>
}


