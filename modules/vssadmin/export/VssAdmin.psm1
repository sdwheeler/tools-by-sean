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
            $kvpairs = ($textBlocks[$i] -split "`r`n").Split(':').Trim()

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
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    $__commandArgs += 'list'
    $__commandArgs += 'providers'
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                $pFmt = "{0}{1}"
                if($value -match "\s") { $pFmt = "{0}""{1}""" }
                $__commandArgs += $pFmt -f $param.OriginalName, $value
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                $__commandArgs += $value | Foreach-Object {$_}
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message $env:Windir/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("$env:Windir/system32/vssadmin.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "$env:Windir/system32/vssadmin.exe")) {
          throw "Cannot find executable '$env:Windir/system32/vssadmin.exe'"
        }
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
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'set ID:' {
                        $id = [guid]$line.Split(':')[1].Trim()
                        $hash.Add('SetId',$id)
                        break
                    }
                    'creation time:' {
                        $datetime = [datetime]($line -split 'time:')[1]
                        $hash.Add('CreateTime',$datetime)
                        break
                    }
                    'Copy ID:' {
                        $id = [guid]$line.Split(':')[1].Trim()
                        $hash.Add('CopyId',$id)
                        break
                    }
                    'Original Volume:' {
                        $value = ($line -split 'Volume:')[1].Trim()
                        if ($value -match '^\((?<name>[A-Z]:)\)(?<path>\\{2}.+\\$)') {
                            $volinfo = [pscustomobject]@{
                                Name = $Matches.name
                                Path = $Matches.path
                            }
                        }
                        $hash.Add('OriginalVolume',$volinfo)
                        break
                    }
                    'Copy Volume:' {
                        $hash.Add('ShadowCopyVolume', $line.Split(':')[1].Trim())
                        break
                    }
                    'Machine:' {
                        $parts = $line.Split(':')
                        $hash.Add($parts[0].Replace(' ',''), $parts[1].Trim())
                        break
                    }
                    'Provider:' {
                        $hash.Add('ProviderName',$line.Split(':')[1].Trim(" '"))
                        break
                    }
                    'Type:' {
                        $hash.Add('Type',$line.Split(':')[1].Trim())
                        break
                    }
                    'Attributes' {
                        $attrlist = $line.Split(': ')[1]
                        $hash.Add('Attributes',$attrlist.Split(', '))
                        break
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
               ApplyToExecutable = $False
               NoGap = $True
               }
         Shadow = @{
               OriginalName = '/Shadow='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               ApplyToExecutable = $False
               NoGap = $True
               }
         Set = @{
               OriginalName = '/Set='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               ApplyToExecutable = $False
               NoGap = $True
               }
    }

    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseShadow' }
    }
}

PROCESS {
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    $__commandArgs += 'list'
    $__commandArgs += 'shadows'
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                $pFmt = "{0}{1}"
                if($value -match "\s") { $pFmt = "{0}""{1}""" }
                $__commandArgs += $pFmt -f $param.OriginalName, $value
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                $__commandArgs += $value | Foreach-Object {$_}
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message $env:Windir/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("$env:Windir/system32/vssadmin.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "$env:Windir/system32/vssadmin.exe")) {
          throw "Cannot find executable '$env:Windir/system32/vssadmin.exe'"
        }
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
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'volume:' {
                        $parts = $line -split 'volume:'
                        $key = $parts[0].Replace(' ','') + 'Volume'
                        $value = $parts[1].Trim()
                        if ($value -match '^\((?<name>[A-Z]:)\)(?<path>\\{2}.+\\$)') {
                            $volinfo = [pscustomobject]@{
                                Name = $Matches.name
                                Path = $Matches.path
                            }
                        }
                        $hash.Add($key,$volinfo)
                        break
                    }
                    'space:' {
                        $parts = $line.Split(':')
                        $key = $parts[0].Split(' ')[0] + 'Space'
                        $data = $parts[1].TrimEnd(')') -split ' \('
                        $space = [PSCustomObject]@{
                            Size = $data[0].Replace(' ','')
                            Percent = $data[1]
                        }
                        $hash.Add($key, $space)
                        break
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
               ApplyToExecutable = $False
               NoGap = $True
               }
         On = @{
               OriginalName = '/On='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               ApplyToExecutable = $False
               NoGap = $True
               }
    }

    $__outputHandlers = @{
        Default = @{ StreamOutput = $False; Handler = 'ParseShadowStorage' }
    }
}

PROCESS {
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    $__commandArgs += 'list'
    $__commandArgs += 'ShadowStorage'
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                $pFmt = "{0}{1}"
                if($value -match "\s") { $pFmt = "{0}""{1}""" }
                $__commandArgs += $pFmt -f $param.OriginalName, $value
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                $__commandArgs += $value | Foreach-Object {$_}
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "c:/windows/system32/vssadmin.exe")) {
          throw "Cannot find executable 'c:/windows/system32/vssadmin.exe'"
        }
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
List volume shadow copy storage associations.

.DESCRIPTION
List volume shadow copy storage associations. With no parameters, all associations are listed by default.

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
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'path:' {
                        $hash.Add('Path',($line -split ': ')[1].Trim("'"))
                        break
                    }
                    'name:' {
                        $hash.Add('Name',($line -split ': ')[1].Trim("'"))
                        # Output the object and create a new empty hash
                        [pscustomobject]$hash
                        $hash = [ordered]@{}
                        break
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
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    $__commandArgs += 'list'
    $__commandArgs += 'volumes'
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                $pFmt = "{0}{1}"
                if($value -match "\s") { $pFmt = "{0}""{1}""" }
                $__commandArgs += $pFmt -f $param.OriginalName, $value
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                $__commandArgs += $value | Foreach-Object {$_}
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "c:/windows/system32/vssadmin.exe")) {
          throw "Cannot find executable 'c:/windows/system32/vssadmin.exe'"
        }
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
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'name:' {
                        $hash.Add('Name',($line -split ': ')[1].Trim("'"))
                        break
                    }
                    'Id:' {
                        $parts = $line -split ': '
                        $key = $parts[0].Replace(' ','')
                        $id = [guid]$parts[1].Trim()
                        $hash.Add($key,$id)
                        break
                    }
                    'State:' {
                        $hash.Add('State', ($line -split ': ')[1].Trim())
                        break
                    }
                    'error:' {
                        $hash.Add('LastError', ($line -split ': ')[1].Trim())
                        break
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
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    $__commandArgs += 'list'
    $__commandArgs += 'writers'
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                $pFmt = "{0}{1}"
                if($value -match "\s") { $pFmt = "{0}""{1}""" }
                $__commandArgs += $pFmt -f $param.OriginalName, $value
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                $__commandArgs += $value | Foreach-Object {$_}
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "c:/windows/system32/vssadmin.exe")) {
          throw "Cannot find executable 'c:/windows/system32/vssadmin.exe'"
        }
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
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName='ByMaxSize')]

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
               ApplyToExecutable = $False
               NoGap = $True
               }
         On = @{
               OriginalName = '/On='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               ApplyToExecutable = $False
               NoGap = $True
               }
         MaxSize = @{
               OriginalName = '/MaxSize='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Int64'
               ApplyToExecutable = $False
               NoGap = $True
               }
         MaxPercent = @{
               OriginalName = '/MaxSize='
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'string'
               ApplyToExecutable = $False
               NoGap = $True
               }
         Unbounded = @{
               OriginalName = '/MaxSize=UNBOUNDED'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'switch'
               ApplyToExecutable = $False
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
    $__boundParameters = $PSBoundParameters
    $__defaultValueParameters = $PSCmdlet.MyInvocation.MyCommand.Parameters.Values.Where({$_.Attributes.Where({$_.TypeId.Name -eq "PSDefaultValueAttribute"})}).Name
    $__defaultValueParameters.Where({ !$__boundParameters["$_"] }).ForEach({$__boundParameters["$_"] = get-variable -value $_})
    $__commandArgs = @()
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $__boundParameters[$_.Name]}).ForEach({$__boundParameters[$_.Name] = [switch]::new($false)})
    if ($__boundParameters["Debug"]){wait-debugger}
    $__commandArgs += 'Resize'
    $__commandArgs += 'ShadowStorage'
    foreach ($paramName in $__boundParameters.Keys|
            Where-Object {!$__PARAMETERMAP[$_].ApplyToExecutable}|
            Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $__boundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ($value -is [switch]) {
                 if ($value.IsPresent) {
                     if ($param.OriginalName) { $__commandArgs += $param.OriginalName }
                 }
                 elseif ($param.DefaultMissingValue) { $__commandArgs += $param.DefaultMissingValue }
            }
            elseif ( $param.NoGap ) {
                $pFmt = "{0}{1}"
                if($value -match "\s") { $pFmt = "{0}""{1}""" }
                $__commandArgs += $pFmt -f $param.OriginalName, $value
            }
            else {
                if($param.OriginalName) { $__commandArgs += $param.OriginalName }
                $__commandArgs += $value | Foreach-Object {$_}
            }
        }
    }
    $__commandArgs = $__commandArgs | Where-Object {$_ -ne $null}
    if ($__boundParameters["Debug"]){wait-debugger}
    if ( $__boundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message c:/windows/system32/vssadmin.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("c:/windows/system32/vssadmin.exe $__commandArgs")) {
    # check for the application and throw if it cannot be found
        if ( -not (Get-Command -ErrorAction Ignore "c:/windows/system32/vssadmin.exe")) {
          throw "Cannot find executable 'c:/windows/system32/vssadmin.exe'"
        }
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


