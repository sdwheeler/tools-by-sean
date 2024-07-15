#-------------------------------------------------------
function Find-PmcPackages {
    if (Test-Path "$env:temp\repodata") {
        $null = Remove-Item -Path "$env:temp\repodata" -Recurse -Force
        $null = New-Item -ItemType Directory -Path "$env:temp\repodata"
    } else {
        $null = New-Item -ItemType Directory -Path "$env:temp\repodata"
    }

    $verpatterns =  ('7.5*','7.4*','7.2*')
    # RPM-based packages have XML metadata
    $rpmrepos = @(
        [pscustomobject]@{
            distro = 'rhel8x64'
            mdxml  = 'https://packages.microsoft.com/rhel/8/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro = 'rhel9x64'
            mdxml  = 'https://packages.microsoft.com/rhel/9/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro = 'rhel80x64'
            mdxml  = 'https://packages.microsoft.com/rhel/8.0/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro = 'rhel90x64'
            mdxml  = 'https://packages.microsoft.com/rhel/9.0/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro = 'cbl2arm64'
            mdxml  = 'https://packages.microsoft.com/cbl-mariner/2.0/prod/Microsoft/aarch64/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro = 'cbl2x64'
            mdxml  = 'https://packages.microsoft.com/cbl-mariner/2.0/prod/Microsoft/x86_64/repodata/repomd.xml'
        }
    )

    # DEB-based packages metadata is YAML-like data stored in Packages files
    $debrepos = @(
        [pscustomobject]@{
            distro = 'debian11x64'
            packages  = 'https://packages.microsoft.com/debian/11/prod/dists/bullseye/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro = 'debian11arm64'
            packages  = 'https://packages.microsoft.com/debian/11/prod/dists/bullseye/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro = 'debian11armhf'
            packages  = 'https://packages.microsoft.com/debian/11/prod/dists/bullseye/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro = 'debian12x64'
            packages  = 'https://packages.microsoft.com/debian/12/prod/dists/bookworm/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro = 'debian12arm64'
            packages  = 'https://packages.microsoft.com/debian/12/prod/dists/bookworm/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro = 'debian12armhf'
            packages  = 'https://packages.microsoft.com/debian/12/prod/dists/bookworm/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2004x64'
            packages  = 'https://packages.microsoft.com/ubuntu/20.04/prod/dists/focal/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2004arm64'
            packages  = 'https://packages.microsoft.com/ubuntu/20.04/prod/dists/focal/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2004armhf'
            packages  = 'https://packages.microsoft.com/ubuntu/20.04/prod/dists/focal/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2204x64'
            packages  = 'https://packages.microsoft.com/ubuntu/22.04/prod/dists/jammy/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2204arm64'
            packages  = 'https://packages.microsoft.com/ubuntu/22.04/prod/dists/jammy/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2204armhf'
            packages  = 'https://packages.microsoft.com/ubuntu/22.04/prod/dists/jammy/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2404x64'
            packages  = 'https://packages.microsoft.com/ubuntu/24.04/prod/dists/noble/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2404arm64'
            packages  = 'https://packages.microsoft.com/ubuntu/24.04/prod/dists/noble/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2404armhf'
            packages  = 'https://packages.microsoft.com/ubuntu/24.04/prod/dists/noble/main/binary-armhf/Packages'
        }
    )

    # Download and parse DEB package information
    foreach ($repo in $debrepos) {
        $lines = (Invoke-RestMethod -Uri $repo.packages) -split '\n' |
            Select-String -Pattern 'Package:|Version:|Filename:' |
            Select-Object -ExpandProperty Line

        $packages = @()
        for ($i = 0; $i -lt $lines.Count; $i += 3) {
            $pkg = [pscustomobject]($lines[$i..($i + 2)] | ConvertFrom-Yaml)
            if ($pkg.Package -match '^powershell$|^powershell-preview$' -and
               $pkg.Version -match '^7\.[245]') {
                $packages += $pkg
           }
        }
        $packages | ForEach-Object {
            $_.Version = $_.Version -replace '-1.ubuntu.\d\d.\d\d|-1.deb', ''
        }
        foreach ($ver in $verpatterns) {
            $package = $packages | Where-Object { $_.Version -like $ver } |
                Sort-Object {[semver]($_.Version)} -Descending |
                Select-Object -First 1
            if ($package) {
                [pscustomobject]@{
                    distro  = $repo.distro
                    version = $package.Version
                    package = ($package.Filename -split '/')[-1]
                }
            }
        }
    }

    # Download and parse RPM package information
    foreach ($repo in $rpmrepos) {
        $xml = [xml](Invoke-WebRequest -Uri $repo.mdxml).Content
        $primarypath = ($xml.repomd.data | Where-Object type -eq primary).location.href
        $primaryurl = $repo.mdxml -replace 'repodata/repomd.xml', $primarypath
        Invoke-WebRequest -Uri $primaryurl -OutFile "$env:temp\$primarypath"
        $null = 7z x "$env:temp\$primarypath" -o"$env:temp\repodata" -bd -y
        $primary = [xml](Get-Content ("$env:temp\$primarypath" -replace '.gz', ''))
        $packages = $primary.metadata.package |
            Where-Object {
                $_.name -match '^powershell$|^powershell-preview$' -and
                $_.version.ver -match '^7\.[245]'
            }
        foreach ($ver in $verpatterns) {
            $package = $packages | Where-Object { $_.version.ver -like $ver } |
                Sort-Object {[semver]($_.version.ver -replace '_','-')} -Descending |
                Select-Object -First 1
            if ($package) {
                [pscustomobject]@{
                    distro  = $repo.distro
                    version = $package.version.ver
                    package = ($package.location.href -split '/')[-1]
                }
            }
        }
    }
}
#-------------------------------------------------------
function Find-DockerImages {
    $baseUrl = 'https://mcr.microsoft.com/api/v1/catalog/powershell'
    $supportedTags = Invoke-RestMethod "$baseUrl/details" |
        Select-Object -ExpandProperty supportedTags
    $allTags = Invoke-RestMethod "$baseUrl/tags"

    $allTags | Where-Object name -in $supportedTags |
        Select-Object -Property name, operatingSystem, architecture, lastModifiedDate
}
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
function Get-OSEndOfLife {
    param (
        [Parameter(Position = 0)]
        [ArgumentCompletions('alpine', 'centos', 'centosstream', 'debian', 'macos', 'opensuse', 'oracle', 'rhel', 'sles', 'ubuntu', 'wincli', 'winsrv')]
        [string[]]$OS = ('alpine', 'centos', 'centosstream', 'debian', 'macos', 'opensuse', 'oracle', 'rhel', 'sles', 'ubuntu', 'wincli', 'winsrv')
    )
    $links = [ordered]@{
        alpine       = 'https://endoflife.date/api/alpine.json'
        centos       = 'https://endoflife.date/api/centos.json'
        centosstream = 'https://endoflife.date/api/centos-stream.json'
        debian       = 'https://endoflife.date/api/debian.json'
        macos        = 'https://endoflife.date/api/macos.json'
        opensuse     = 'https://endoflife.date/api/opensuse.json'
        oracle       = 'https://endoflife.date/api/oracle-linux.json'
        rhel         = 'https://endoflife.date/api/rhel.json'
        sles         = 'https://endoflife.date/api/sles.json'
        ubuntu       = 'https://endoflife.date/api/ubuntu.json'
        wincli       = 'https://endoflife.date/api/windows.json'
        winsrv       = 'https://endoflife.date/api/windows-server.json'
    }
    $today = '{0:yyyy-MM-dd}' -f (Get-Date)

    $results = $links.GetEnumerator().Where({$_.Name -in $OS}) | ForEach-Object -Parallel {
        $name = $_.Name
        (Invoke-RestMethod $_.Value) |
            Where-Object { $_.eol -gt $using:today -or $_.eol -eq $false } |
            ForEach-Object {
                [pscustomobject]@{
                    PSTypeName        = 'EolData'
                    os                = $name
                    cycle             = $_.cycle
                    latest            = $_.latest
                    codename          = $_.codename
                    releaseDate       = $_.releaseDate
                    latestReleaseDate = $_.latestReleaseDate
                    support           = $_.support
                    eol               = $_.eol
                    extendedSupport   = $_.extendedSupport
                    lts               = $_.lts
                    link              = $_.link
                }
            }
    }
    $results | Sort-Object os
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
function Get-PSReleaseHistory {
    [CmdletBinding(DefaultParameterSetName = 'ByVersion')]
    param(
        [Parameter(ParameterSetName = 'ByVersion', Position = 0)]
        [string]$Version,

        [Parameter(ParameterSetName = 'Current')]
        [switch]$Current,

        [Parameter(ParameterSetName = 'ByVersion')]
        [Parameter(ParameterSetName = 'Current')]
        [Alias('GA')]
        [switch]$GeneralAvailability,

        [Parameter(ParameterSetName = 'ShowAll')]
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
                    Where-Object Version -GT 'v5.1' |
                    Group-Object Version |
                    Sort-Object Name -Descending
                if ($GeneralAvailability) {
                    $groupedByVersion | ForEach-Object {
                        $_.Group | Where-Object Tag -Like '*.0'
                    }
                } else {
                    $groupedByVersion | ForEach-Object {
                        $_.Group | Select-Object -First 1
                    }
                }
            } else {
                if ($GeneralAvailability) {
                    $history | Where-Object Version -EQ $Version | Where-Object Tag -Like '*.0'
                } else {
                    $history | Where-Object Version -EQ $Version
                }
            }
            break
        }
        'Current' {
            $Version = ('v{0}' -f $PSVersionTable.PSVersion.ToString().SubString(0, 3))
            if ($GeneralAvailability) {
                $history | Where-Object Version -EQ $Version | Where-Object Tag -Like '*.0'
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
function Get-PSReleasePackage {
    param(
        [Parameter(Mandatory)]
        [string[]]$tag,

        [ValidateSet('rpm','tar.gz','zip','msi','pkg','deb')]
        [string]$type = 'msi',

        [string]$pattern = '*-win-x64'
    )
    foreach ($t in $tag) {
        if (-not $pattern.EndsWith($type)) {
            $pattern = '{0}*.{1}' -f $pattern, $type
        }
        gh release download $t --pattern $pattern -D $HOME\Downloads -R PowerShell/PowerShell
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
