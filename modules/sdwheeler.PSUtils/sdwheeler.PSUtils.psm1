#-------------------------------------------------------
function Get-CommandSyntax {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $CmdletName,

        [switch]
        $Markdown
    )

    function formatString {
        param(
            $cmd,
            $pstring
        )

        $parts      = $pstring -split ' '
        $parameters = @()
        for ($x = 0; $x -lt $parts.Count; $x++) {
            $p = $parts[$x]
            if ($x -lt $parts.Count - 1) {
                if (!$parts[$x + 1].StartsWith('[')) {
                    $p += ' ' + $parts[$x + 1]
                    $x++
                }
                $parameters += , $p
            } else {
                $parameters += , $p
            }
        }

        $line = $cmd + ' '
        $temp = ''
        for ($x = 0; $x -lt $parameters.Count; $x++) {
            if ($line.Length + $parameters[$x].Length + 1 -lt 100) {
                $line += $parameters[$x] + ' '
            } else {
                $temp += $line + "`r`n"
                $line  = ' ' + $parameters[$x] + ' '
            }
        }
        $temp + $line.TrimEnd()
    }


    try {
        $cmdlet = Get-Command $cmdletname -ea Stop
        if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }
        if ($cmdlet.CommandType -eq 'ExternalScript') {
            $name = $CmdletName
        } else {
            $name = $cmdlet.Name
        }

        $syntax = (Get-Command $name).ParameterSets |
            Select-Object -Property @(
                @{Name = 'Cmdlet'           ; Expression = { $cmdlet.Name } },
                @{Name = 'ParameterSetName' ; Expression = { $_.name } },
                'IsDefault',
                @{Name = 'Parameters'       ; Expression = { $_.ToString() } }
            )
    } catch [System.Management.Automation.CommandNotFoundException] {
        $_.Exception.Message
    }

    $mdHere = @'
### {0}{1}

```
{2}
```

'@

    if ($Markdown) {
        foreach ($s in $syntax) {
            $string = $s.Cmdlet, $s.Parameters -join ' '
            if ($s.IsDefault) { $default = ' (Default)' } else { $default = '' }
            if ($string.Length -gt 100) {
                $string = formatString $s.Cmdlet $s.Parameters
            }
            $mdHere -f $s.ParameterSetName, $default, $string
        }
    } else {
        $syntax
    }

}
#-------------------------------------------------------
function Get-Constructors {
    param([type]$type)
    foreach ($constr in $type.GetConstructors()) {
        $params = @()
        foreach ($parameter in $constr.GetParameters()) {
            $params += '{0} {1}' -f $parameter.ParameterType.FullName, $parameter.Name
        }
        Write-Host $($constr.DeclaringType.Name) "($($params -join ', '))"
    }
}
#-------------------------------------------------------
function Get-EnumValues {
    param([string]$enum)
    $enumValues = @{}
    [enum]::GetValues([type]$enum) |
        ForEach-Object { $enumValues.add($_, $_.value__) }
    $enumValues
}
#-------------------------------------------------------
function Get-ExtendedTypeData {
    (Get-TypeData).Where({ $_.members.count -gt 0 }).ForEach({
            '::: {0} :::' -f $_.typeName
            $_.Members.Values |
                Group-Object { $_.gettype().name } |
                ForEach-Object {
                    $_.group | Format-List Name,
                    @{L = 'Type'; E = { $_.gettype().name -replace 'Data' } },
                    *referenc*,
                    *script*
                }
        })
}
#-------------------------------------------------------
function Get-FunctionDefinition {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )
    $cmdInfo = Get-Command $Name
    if ($null -eq $cmdInfo) {
        Write-Error "Function $Name not found"
        return
    }
    if ($cmdInfo.CommandType -ne 'Function') {
        Write-Error "$Name is not a function"
        return
    }
    $function = @()
    $function += 'function {0} {{' -f $cmdInfo.Name
    $function += $cmdInfo.Definition
    $function += '}'
    $function -join [environment]::NewLine
}
#-------------------------------------------------------
function Get-InputType {
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string[]]$Command
    )
    process {
        foreach ($cmd in $Command) {
            $cmdInfo = Get-Command $cmd
            $params = $cmdInfo.Parameters.Values | Where-Object {
                $_.Attributes.ValueFromPipeline -eq $true -or
                $_.Attributes.ValueFromPipelineByPropertyName -eq $true
            }
            foreach ($param in $params) {
                $result = [pscustomobject]@{
                    PSTypeName    = 'PipelineValueType'
                    Command       = $cmdInfo.Name
                    Name          = $param.Name
                    Aliases       = $param.Aliases -join ', '
                    ParameterType = $param.ParameterType.FullName -replace '\[\]',''
                    ByValue       = $false
                    ByName        = $false
                }
                foreach ($v in $param.Attributes.ValueFromPipeline) {
                    if ($v -eq $true) {
                        $result.ByValue = $true
                        break
                    }
                }
                foreach ($v in $param.Attributes.ValueFromPipelineByPropertyName) {
                    if ($v -eq $true) {
                        $result.ByName = $true
                        break
                    }
                }
                $result
            }
        }
    }
}
#-------------------------------------------------------
function Get-OutputType {
    param([string]$cmd)
    Get-PSDrive | Sort-Object Provider -Unique | ForEach-Object {
        Push-Location $($_.name + ':')
        [pscustomobject] @{
            Provider   = $_.Provider.Name
            OutputType = (Get-Command $cmd).OutputType.Name | Select-Object -uni
        }
        Pop-Location
    }
}
#-------------------------------------------------------
function Get-PSHelpInfoUri {
    $pattern = 'HelpInfoUri\s*=\s*("|'')(.+)("|'')'
    $urilist = Get-ChildItem $PSHOME\*.psd1 -Recurse |
        Select-String -Pattern $pattern
    foreach ($item in $urilist) {
        [pscustomobject]@{
            Module      = Split-Path $item.Path -LeafBase
            HelpInfoUri = ($item.Line -replace $pattern, '$2').Trim()
        }
    }
}
#-------------------------------------------------------
function Get-RuntimeInformation {
    [pscustomobject]@{
        PSVersion            = $PSVersionTable.PSVersion.ToString()
        PSEdition            = $PSVersionTable.PSEdition
        FrameworkDescription = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        OSDescription        = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        OSArchitecture       = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        ProcessArchitecture  = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
        RuntimeIdentifier    = [System.Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
        Modules              = Get-Module | ForEach-Object {
            $mod = '{0} {1}' -f $_.Name, $_.Version
            $pre = $_.PrivateData.PSData.Prerelease
            if ($pre) { $mod += "-$pre" }
            $mod
        }
    }
}
#-------------------------------------------------------
function Get-RuntimeType {
    # https://gist.github.com/JamesWTruher/38ed1ece495800f96b78e7287fc5f9ac
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)][object]$rt,
        [Parameter()][string[]]$Property = 'IsStatic',
        [Parameter()][string[]]$SortBy = 'IsStatic'
    )
    PROCESS {
        if ( $rt -is [system.reflection.typeinfo] ) {
            $TypeName = $_.FullName
            if ( $_.IsAbstract ) { $TypeName += ' (Abstract)' }
            $properties = .{ $Property; { "$_" } }
            $sorting = .{ $SortBy; 'name' }
            $rt.GetMembers() |
                Sort-Object $sorting |
                Format-Table -group @{ L = 'Name'; E = { $TypeName } } $properties -Auto -Wrap |
                Out-String -Stream
        } else {
            Write-Error "'$rt' is not a runtimetype"
        }
    }
}
#-------------------------------------------------------
function Get-TypeHierarchy {
    # https://gist.github.com/JamesWTruher/4fb3b06cb34474714a39b4324c776c6b
    param ( [type]$T )
    foreach ($i in $T.GetInterfaces() ) {
        $i
    }
    $P = $T
    $T
    while ( $P.BaseType ) {
        $P = $P.BaseType
        $P
    }
}
#-------------------------------------------------------
function Get-TypeAccelerators {
    ([PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get).GetEnumerator() | Sort-Object Key
}
#-------------------------------------------------------
function Get-TypeMember {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [object]$InputObject
    )
    [type]$type = $InputObject.GetType()
    "`r`n    TypeName: {0}" -f $type.FullName
    $type.GetMembers() | Sort-Object membertype, name |
        Select-Object Name, MemberType, isStatic, @{ n = 'Definition'; e = { $_ } }
}
Set-Alias -Name gtm -Value Get-TypeMember
#-------------------------------------------------------
function Split-Module {
    param(
        $Module
    )
    Get-Command -Module $module | ForEach-Object {
        $Name = $_.Name
        $Definition = $_.Definition
        Set-Content -Path "$Name.ps1" -Encoding utf8 -Force -Value @"
function $Name {
$Definition
}
"@
    }
}
#-------------------------------------------------------
function Test-Parameter {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$CmdletName,
        [Parameter(Mandatory, Position = 1)]
        [string[]]$Parameter,
        [switch]$Syntax
    )

    $psets = (Get-Command $CmdletName).ParameterSets
    $cmdsyntax = Get-CommandSyntax $CmdletName
    $list = @()
    foreach ($pset in $psets) {
        $foundAll = $true
        Write-Verbose $pset.name
        foreach ($parm in $Parameter) {
            $found = $pset.Parameters.Name -contains $parm
            Write-Verbose ("`t{0}->{1}" -f $parm, $found)
            $foundAll = $foundAll -and $found
        }
        if ($foundAll) {
            $list += $cmdsyntax | Where-Object ParameterSetName -EQ $pset.Name
        }
    }
    Write-Verbose ('Found {0} parameter set(s)' -f $list.count)
    if ($Syntax) {
        $list
    } else {
        ($list.count -gt 0)
    }
}
#-------------------------------------------------------
function Uninstall-ModuleAllVersions {
    param(
        [Parameter(Mandatory)]
        [string]$module,

        [Parameter(Mandatory)]
        [string]$version,

        [switch]$Force
    )
    'Creating list of dependencies...'
    $depmods = Find-Module $module -RequiredVersion $version |
        Select-Object -exp dependencies |
        Select-Object @{l = 'name'; e = { $_.name } },
        @{l = 'version'; e = { $_.requiredversion } }

    $depmods += @{name = $module; version = $version }

    $saveErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    foreach ($mod in $depmods) {
        'Uninstalling {0}' -f $mod.name
        try {
            Uninstall-Module $mod.name -RequiredVersion $mod.version -Force:$Force -ErrorAction Stop
        } catch {
            Write-Host ("`t" + $_.FullyQualifiedErrorId)
        }
    }

    $ErrorActionPreference = $saveErrorPreference
}
#-------------------------------------------------------
function Get-Assemblies {
    [AppDomain]::CurrentDomain.GetAssemblies() |
        Select-Object @{n='Name'; e={($_.FullName -split ',')[0]}},
        Modules, Location
}
#-------------------------------------------------------
function Get-AssemblyTypes {
    param(
        [string]$Name
    )
    [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object FullName -like "$Name*" |
        ForEach-Object {
            $_.GetTypes() |
            Where-Object IsPublic |
            Select-Object Name, BaseType, Module
        }
}
#-------------------------------------------------------
