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
    [enum]::getvalues([type]$enum) |
        ForEach-Object { $enumValues.add($_, $_.value__) }
    $enumValues
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
function Get-TypeAccelerators {
    ([PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get).GetEnumerator() | Sort-Object Key
}
#-------------------------------------------------------
function Kill-Module {
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
        }
        catch {
            Write-Host ("`t" + $_.FullyQualifiedErrorId)
        }
    }

    $ErrorActionPreference = $saveErrorPreference
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
    }
    else {
    ($list.count -gt 0)
    }
}
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
function Get-LinuxDistroStatus {
    param(
        [ValidateSet('stable','preview','lts')]
        [string[]]$Channel
    )
    $distros = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell-Docker/master/assets/matrix.json

    if ($null -eq $Channel) {
        $channels = 'stable','preview','lts'
    } else {
        $channels = $Channel
    }
    foreach ($ch in $channels) {
        $distros.$ch |
            Select-Object Channel,
                          OsVersion,
                          DistributionState,
                          @{n='EndOfLife';e={Get-Date $_.EndOfLife -f 'yyyy-MM-dd'}},
                          @{n='Tags'; e={$_.TagList -split ';'}} |
            Sort-Object osversion
    }
}
#-------------------------------------------------------
