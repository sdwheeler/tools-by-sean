function Format-TableAuto {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [psobject]
        ${InputObject})

    begin {
        $PSBoundParameters['AutoSize'] = $true
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Format-Table', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    }

    process {
        $steppablePipeline.Process($_)
    }

    end {
        $steppablePipeline.End()
    }
    <#
  .ForwardHelpTargetName Format-Table
  .ForwardHelpCategory Cmdlet
  #>
}
Set-Alias fta Format-TableAuto
#-------------------------------------------------------
function Format-TableWrapped {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [psobject]
        ${InputObject})

    begin {
        $PSBoundParameters['Wrap'] = $true
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Format-Table', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    }

    process {
        $steppablePipeline.Process($_)
    }

    end {
        $steppablePipeline.End()
    }
    <#
  .ForwardHelpTargetName Format-Table
  .ForwardHelpCategory Cmdlet
  #>
}
Set-Alias ftw Format-TableWrapped
#-------------------------------------------------------
function Get-Constructors ([type]$type) {
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
    Param([string]$enum)
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
function Get-LinuxDistroStatus {
    param(
        [ValidateSet('stable', 'preview', 'lts')]
        [string[]]$Channel
    )
    $distros = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell-Docker/master/assets/matrix.json

    if ($null -eq $Channel) {
        $channels = 'stable', 'preview', 'lts'
    } else {
        $channels = $Channel
    }
    . { foreach ($ch in $channels) {
        $distros.$ch |
            Select-Object OsVersion,
            Channel,
            DistributionState,
            @{n = 'EndOfLife'; e = { Get-Date $_.EndOfLife -f 'yyyy-MM-dd' } },
            UseInCI,
            @{n = 'Tags'; e = { $_.TagList -split ';' } }
        }
    } | Sort-Object OsVersion
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
function Get-PSReleaseHistory {
    [CmdletBinding(DefaultParameterSetName='ByVersion')]
    param(
        [Parameter(ParameterSetName='ByVersion', Position=0)]
        [string]$Version,

        [Parameter(ParameterSetName='Current')]
        [switch]$Current,

        [Parameter(ParameterSetName='ByVersion')]
        [Parameter(ParameterSetName='Current')]
        [Alias('GA')]
        [switch]$GeneralAvailability,

        [Parameter(ParameterSetName='ShowAll')]
        [switch]$All
    )

    $restparams = @{
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Uri     = 'https://api.github.com/graphql'
        Body    = '{ "query" : "query { repository(name: \"PowerShell\", owner: \"PowerShell\") { releases(first: 100, orderBy: {field: CREATED_AT, direction: DESC}) { nodes { publishedAt name tagName } pageInfo { hasNextPage endCursor } } } }" }'
    }
    $result = Invoke-RestMethod @restparams -Method POST -FollowRelLink
    $history = $result.data.repository.releases.nodes |
        Select-Object @{n = 'Version'; e = { $_.tagName.Substring(0, 4) } },
        @{n = 'Tag'; e = { $_.tagName } },
        @{n = 'Date'; e = { '{0:yyyy-MM-dd}' -f $_.publishedAt } }

    $history += while ($result.data.repository.releases.pageInfo.hasNextPage -eq 'true') {
        $after = 'first: 100, after: \"{0}\"' -f $result.data.repository.releases.pageInfo.endCursor
        $restparams.body = $restparams.body -replace 'first: 100', $after
        $result = Invoke-RestMethod @restparams -Method POST
        $result.data.repository.releases.nodes |
            Select-Object @{n = 'Version'; e = { $_.tagName.Substring(0, 4) } },
            @{n = 'Tag'; e = { $_.tagName } },
            @{n = 'Date'; e = { '{0:yyyy-MM-dd}' -f $_.publishedAt } }
    }
    switch ($PSCmdlet.ParameterSetName) {
        'ByVersion' {
            if ($Version -eq '') {
                $groupedByVersion = $history |
                    Where-Object Version -gt 'v5.1' |
                    Group-Object Version |
                    Sort-Object Name -Descending
                if ($GeneralAvailability) {
                    $groupedByVersion | ForEach-Object {
                        $_.Group | Where-Object Tag -like '*.0'
                    }
                } else {
                    $groupedByVersion | ForEach-Object {
                        $_.Group | Select-Object -First 1
                    }
                }
            } else {
                if ($GeneralAvailability) {
                    $history | Where-Object Version -EQ $Version | Where-Object Tag -like '*.0'
                } else {
                    $history | Where-Object Version -EQ $Version
                }
            }
            break
        }
        'Current' {
            $Version = ('v{0}' -f $PSVersionTable.PSVersion.ToString().SubString(0,3))
            if ($GeneralAvailability) {
                $history | Where-Object Version -EQ $Version | Where-Object Tag -like '*.0'
            } else {
                $history | Where-Object Version -EQ $Version
            }
            break
        }
        'ShowAll' {
            $history
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
function Save-History {
    $date = Get-Date -f 'yyyy-MM-dd'
    $oldlog = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    $newlog = "$env:USERPROFILE\Documents\PowerShell\History\ConsoleHost_history_$date.txt"
    Copy-Item $oldlog $newlog -Force
    Get-History |
        Select-Object -ExpandProperty CommandLine |
        Sort-Object -Unique |
        Out-File $oldlog -Force
}
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
    $cmdsyntax = Get-Syntax $CmdletName
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
