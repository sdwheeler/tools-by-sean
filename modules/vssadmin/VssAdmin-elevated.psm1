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
[PowerShellCustomFunctionAttribute(RequiresElevation=$True)]
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
            & "Invoke-WindowsNativeAppWithElevation"  "$env:Windir/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "Invoke-WindowsNativeAppWithElevation"  "$env:Windir/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List registered volume shadow copy providers

.DESCRIPTION
List registered volume shadow copy providers

.EXAMPLE
PS> Get-VssProvider

Get a list of VSS Providers
Original Command: vssadmin list providers


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
[PowerShellCustomFunctionAttribute(RequiresElevation=$True)]
[CmdletBinding(DefaultParameterSetName='Default')]

param(
[Parameter(ParameterSetName='Default')]
[Parameter(ParameterSetName='byShadowId')]
[Parameter(ParameterSetName='bySetId')]
[string]$For,
[Parameter(Mandatory=$true,ParameterSetName='byShadowId')]
[string]$Shadow,
[Parameter(Mandatory=$true,ParameterSetName='bySetId')]
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
            & "Invoke-WindowsNativeAppWithElevation"  "$env:Windir/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "Invoke-WindowsNativeAppWithElevation"  "$env:Windir/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List existing volume shadow copies. Without any options, all shadow copies on the system are displayed ordered by shadow copy set. Combinations of options can be used to refine the output.

.DESCRIPTION
List existing volume shadow copies.

.PARAMETER For
List the shadow copies for volume name like 'C:'


.PARAMETER Shadow
List shadow copies matching the Id in GUID format: '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'


.PARAMETER Set
List shadow copies matching the shadow set Id in GUID format: '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'



.EXAMPLE
PS> Get-VssShadow

Get a list of VSS shadow copies
Original Command: vssadmin list shadows


.EXAMPLE
PS> Get-VssShadow -For C:

Get a list of VSS shadow copies for volume C:
Original Command: vssadmin list shadows /For=C:


.EXAMPLE
PS> Get-VssShadow -Shadow '{c17ebda1-5da3-4f4a-a3dc-f5920c30ed0f}'

Get a specific shadow copy
Original Command: vssadmin list shadows /Shadow={c17ebda1-5da3-4f4a-a3dc-f5920c30ed0f}


.EXAMPLE
PS> Get-VssShadow -Set '{c17ebda1-5da3-4f4a-a3dc-f5920c30ed0f}'

Get the shadow copies for specific shadow set
Original Command: vssadmin list shadows /Shadow={3872a791-51b6-4d10-813f-64b4beb9f935}


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
[PowerShellCustomFunctionAttribute(RequiresElevation=$True)]
[CmdletBinding(DefaultParameterSetName='ForVolume')]

param(
[Parameter(ParameterSetName='ForVolume')]
[string]$For,
[Parameter(Mandatory=$true,ParameterSetName='OnVolume')]
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
            & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List volume shadow copy storage associations.

.DESCRIPTION
List volume shadow copy storage associations. With no paramters, all associations are listed by default.

.PARAMETER For
List all associations for a given volume. Provide a volume name like 'C:'


.PARAMETER On
List all associations on a given volume. Provide a volume name like 'C:'



.EXAMPLE
PS> Get-VssShadowStorage

List all associations
Original Command: vssadmin list shadowstorage


.EXAMPLE
PS> Get-VssShadowStorage -For C:

List all associations for drive C:
Original Command: vssadmin list shadowstorage /For=C:


.EXAMPLE
PS> Get-VssShadowStorage -On C:

List all associations on drive C:
Original Command: vssadmin list shadowstorage /On=C:


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
[PowerShellCustomFunctionAttribute(RequiresElevation=$True)]
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
            & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List volumes eligible for shadow copies

.DESCRIPTION
List volumes eligible for shadow copies

.EXAMPLE
PS> Get-VssVolume

Get all volumes eligible for shadow copies
Original Command: vssadmin list volumes


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
[PowerShellCustomFunctionAttribute(RequiresElevation=$True)]
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
            & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
List subscribed volume shadow copy writers

.DESCRIPTION
List subscribed volume shadow copy writers

.EXAMPLE
PS> Get-VssWriter

Get all VSS writers on the system
Original Command: vssadmin list writers


#>
}


function ParseResizeShadowStorage {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    if ($textBlocks[1] -like 'Error*') {
        Write-Error $textBlocks[1]
    } elseif ($textBlocks[1] -like 'Success*') {
        Get-VssShadowStorage
    } else {
        $textBlocks[1]
    }

}
function ParseResizeShadowStorage {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    if ($textBlocks[1] -like 'Error*') {
        Write-Error $textBlocks[1]
    } elseif ($textBlocks[1] -like 'Success*') {
        Get-VssShadowStorage
    } else {
        $textBlocks[1]
    }

}
function ParseResizeShadowStorage {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    if ($textBlocks[1] -like 'Error*') {
        Write-Error $textBlocks[1]
    } elseif ($textBlocks[1] -like 'Success*') {
        Get-VssShadowStorage
    } else {
        $textBlocks[1]
    }

}


function Resize-VssShadowStorage
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$True)]
[CmdletBinding(DefaultParameterSetName='ByMaxSize')]

param(
[Parameter(ParameterSetName='ByMaxSize')]
[Parameter(ParameterSetName='ByMaxPercent')]
[Parameter(ParameterSetName='ByMaxUnbound')]
[string]$For,
[Parameter(Mandatory=$true,ParameterSetName='ByMaxSize')]
[Parameter(Mandatory=$true,ParameterSetName='ByMaxPercent')]
[Parameter(Mandatory=$true,ParameterSetName='ByMaxUnbound')]
[string]$On,
[ValidateScript({$_ -ge 320MB})]
[Parameter(Mandatory=$true,ParameterSetName='ByMaxSize')]
[Int64]$MaxSize,
[ValidatePattern('[0-9]+%')]
[Parameter(Mandatory=$true,ParameterSetName='ByMaxPercent')]
[string]$MaxPercent,
[Parameter(Mandatory=$true,ParameterSetName='ByMaxUnbound')]
[switch]$Unbounded
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
         MaxSize = @{
               OriginalName = '/MaxSize='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Int64'
               NoGap = $True
               }
         MaxPercent = @{
               OriginalName = '/MaxSize='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               NoGap = $True
               }
         Unbounded = @{
               OriginalName = '/MaxSize=UNBOUNDED'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'switch'
               NoGap = $False
               }
    }

    $__outputHandlers = @{
        ByMaxSize = @{ StreamOutput = $False; Handler = 'ParseResizeShadowStorage' }
        ByMaxPercent = @{ StreamOutput = $False; Handler = 'ParseResizeShadowStorage' }
        ByMaxUnbound = @{ StreamOutput = $False; Handler = 'ParseResizeShadowStorage' }
    }
}

PROCESS {
    $__commandArgs = @(
        'Resize'
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
            & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "Invoke-WindowsNativeAppWithElevation"  "c:/windows/system32/vssadmin.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS
Resize the maximum size of a shadow copy storage association.

.DESCRIPTION
Resizes the maximum size for a shadow copy storage association between ForVolumeSpec and OnVolumeSpec. Resizing the storage association may cause shadow copies to disappear. As certain shadow copies are deleted, the shadow copy storage space will then shrink.

.PARAMETER For
Provide a volume name like 'C:'


.PARAMETER On
Provide a volume name like 'C:'


.PARAMETER MaxSize
New maximum size in bytes. Must be 320MB or more.


.PARAMETER MaxPercent
A percentage string like '20%'.


.PARAMETER Unbounded
Sets the maximum size to UNBOUNDED.



.EXAMPLE
PS> Resize-VssShadowStorage -For C: -On C: -MaxSize 900MB

Set the new storage size to 900MB
Original Command: vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=900MB


.EXAMPLE
PS> Resize-VssShadowStorage -For C: -On C: -MaxPercent '20%'

Set the new storage size to 20% of the OnVolume size
Original Command: vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=20%


.EXAMPLE
PS> Resize-VssShadowStorage -For C: -On C: -Unbounded

Set the new storage size to unlimited
Original Command: vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=UNBOUNDED


#>
}


function Invoke-WindowsNativeAppWithElevation
{
    [CmdletBinding(DefaultParameterSetName="username")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$command,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$cArguments
    )

    $app = "cmd.exe"
    $nargs = @("/c","cd","/d","%CD%","&&")
    $nargs += $command
    if ( $cArguments.count ) {
        $nargs += $cArguments
    }
    $__OUTPUT = Join-Path ([io.Path]::GetTempPath()) "CrescendoOutput.txt"
    $__ERROR  = Join-Path ([io.Path]::GetTempPath()) "CrescendoError.txt"

    $spArgs = @{
        Verb = 'RunAs'
        File = $app
        ArgumentList = $nargs
        RedirectStandardOutput = $__OUTPUT
        RedirectStandardError = $__ERROR
        WindowStyle = "Minimized"
        PassThru = $True
        ErrorAction = "Stop"
    }
    $timeout = 10000
    $sleepTime = 500
    $totalSleep = 0
    try {
        $p = start-process @spArgs
        while(!$p.HasExited) {
            Start-Sleep -mill $sleepTime
            $totalSleep += $sleepTime
            if ( $totalSleep -gt $timeout )
            {
                throw "'$(cArguments -join " ")' has timed out"
            }
        }
    }
    catch {
        # should we report error output?
        # It's most likely that there will be none if the process can't be started
        # or other issue with start-process. We catch actual error output from the
        # elevated command below.
        if ( Test-Path $__OUTPUT ) { Remove-Item $__OUTPUT }
        if ( Test-Path $__ERROR ) { Remove-Item $__ERROR }
        $msg = "Error running '{0} {1}'" -f $command,($cArguments -join " ")
        throw "$msg`n$_"
    }

    try {
        if ( test-path $__OUTPUT ) {
            $output = Get-Content $__OUTPUT
        }
        if ( test-path $__ERROR ) {
            $errorText = (Get-Content $__ERROR) -join "`n"
        }
    }
    finally {
        if ( $errorText ) {
            $exception = [System.Exception]::new($errorText)
            $errorRecord = [system.management.automation.errorrecord]::new(
                $exception,
                "CrescendoElevationFailure",
                "InvalidOperation",
                ("{0} {1}" -f $command,($cArguments -join " "))
                )
            # errors emitted during the application are not fatal
            Write-Error $errorRecord
        }
        if ( Test-Path $__OUTPUT ) { Remove-Item $__OUTPUT }
        if ( Test-Path $__ERROR ) { Remove-Item $__ERROR }
    }
    # return the output to the caller
    $output
}
