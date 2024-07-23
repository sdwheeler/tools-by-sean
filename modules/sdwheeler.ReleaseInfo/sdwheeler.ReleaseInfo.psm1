#-------------------------------------------------------
function Find-PmcPackages {
    param(
        [ValidateSet('debian', 'ubuntu', 'rhel', 'cbl')]
        [string[]]$Distribution
    )
    if ($IsWindows) {
        $gitcmd = Get-Command git -ErrorAction SilentlyContinue
        $gitroot = $gitcmd.Path -replace 'cmd\\git.exe', ''
        $toolpath = Join-Path $gitroot 'usr\bin\gzip.exe'
        $gzipcmd = Get-Command $toolpath -ErrorAction SilentlyContinue
    } else {
        $gzipcmd = Get-Command gzip -ErrorAction SilentlyContinue
    }
    if ($null -eq $gzipcmd) {
        Write-Error 'gzip command not found'
        return
    }

    if (Test-Path "$env:temp\repodata") {
        $null = Remove-Item -Path "$env:temp\repodata" -Recurse -Force
        $null = New-Item -ItemType Directory -Path "$env:temp\repodata"
    } else {
        $null = New-Item -ItemType Directory -Path "$env:temp\repodata"
    }

    $verpatterns =  ('7.5*','7.4*','7.2*')

    # DEB-based packages metadata is YAML-like data stored in Packages files
    $debrepos = @(
        [pscustomobject]@{
            distro    = 'debian11'
            processor = 'x64'
            packages  = 'https://packages.microsoft.com/debian/11/prod/dists/bullseye/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro    = 'debian11'
            processor = 'arm64'
            packages  = 'https://packages.microsoft.com/debian/11/prod/dists/bullseye/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro    = 'debian11'
            processor = 'armhf'
            packages  = 'https://packages.microsoft.com/debian/11/prod/dists/bullseye/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro    = 'debian12'
            processor = 'x64'
            packages  = 'https://packages.microsoft.com/debian/12/prod/dists/bookworm/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro    = 'debian12'
            processor = 'arm64'
            packages  = 'https://packages.microsoft.com/debian/12/prod/dists/bookworm/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro    = 'debian12'
            processor = 'armhf'
            packages  = 'https://packages.microsoft.com/debian/12/prod/dists/bookworm/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2004'
            processor = 'x64'
            packages  = 'https://packages.microsoft.com/ubuntu/20.04/prod/dists/focal/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2004'
            processor = 'arm64'
            packages  = 'https://packages.microsoft.com/ubuntu/20.04/prod/dists/focal/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2004'
            processor = 'armhf'
            packages  = 'https://packages.microsoft.com/ubuntu/20.04/prod/dists/focal/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2204'
            processor = 'x64'
            packages  = 'https://packages.microsoft.com/ubuntu/22.04/prod/dists/jammy/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2204'
            processor = 'arm64'
            packages  = 'https://packages.microsoft.com/ubuntu/22.04/prod/dists/jammy/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2204'
            processor = 'armhf'
            packages  = 'https://packages.microsoft.com/ubuntu/22.04/prod/dists/jammy/main/binary-armhf/Packages'
        },
        [pscustomobject]@{
            distro = 'ubuntu2404x64'
            packages  = 'https://packages.microsoft.com/ubuntu/24.04/prod/dists/noble/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2404'
            processor = 'arm64'
            packages  = 'https://packages.microsoft.com/ubuntu/24.04/prod/dists/noble/main/binary-arm64/Packages'
        },
        [pscustomobject]@{
            distro    = 'ubuntu2404'
            processor = 'armhf'
            packages  = 'https://packages.microsoft.com/ubuntu/24.04/prod/dists/noble/main/binary-armhf/Packages'
        }
    )
    if ($null -ne $Distribution) {
        $repolist = foreach ($distro in $Distribution) {
            $debrepos | Where-Object { $_.distro -like "$distro*" }
        }
    } else {
        $repolist = $debrepos
    }

    # Download and parse DEB package information
    foreach ($repo in $repolist) {
        # Get package metadata
        $lines = (Invoke-RestMethod -Uri $repo.packages) -split '\n' |
            Select-String -Pattern 'Package:|Version:|Filename:' |
            Select-Object -ExpandProperty Line
        # Filter and select package information
        $packages = @()
        for ($i = 0; $i -lt $lines.Count; $i += 3) {
            $pkg = [pscustomobject]($lines[$i..($i + 2)] | ConvertFrom-Yaml)
            if ($pkg.Package -match '^powershell' -and $pkg.Version -match '^7\.[245]') {
                $packages += $pkg
           }
        }
        # Normalize version strings
        $packages | ForEach-Object {
            $_.Version = $_.Version -replace '-1.ubuntu.\d\d.\d\d|-1.deb', ''
        }
        # Enumerate stable packages
        foreach ($ver in $verpatterns) {
            $package = $packages |
                Where-Object { $_.Version -like $ver -and $_.Package -eq 'powershell'} |
                Sort-Object {[semver]($_.Version)} -Descending |
                Select-Object -First 1
            if ($package) {
                [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = $package.Version
                    channel    = 'stable'
                    processor  = $repo.processor
                    package    = ($package.Filename -split '/')[-1]
                }
            }
        }
        # Enumerate lts packages
        foreach ($ver in ('7.4*','7.2*')) {
            $package = $packages |
                Where-Object { $_.Version -like $ver -and $_.Package -eq 'powershell-lts'} |
                Sort-Object {[semver]($_.Version)} -Descending |
                Select-Object -First 1
            if ($package) {
                [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = $package.Version
                    channel    = 'lts'
                    processor  = $repo.processor
                    package    = ($package.Filename -split '/')[-1]
                }
            }
        }
        # Enumerate preview packages
        $package = $packages |
            Where-Object { $_.Version -like '7.5*' -and $_.Package -eq 'powershell-preview'} |
            Sort-Object {[semver]($_.Version)} -Descending |
            Select-Object -First 1
        if ($package) {
            [pscustomobject]@{
                PSTypeName = 'PmcData'
                distro     = $repo.distro
                version    = $package.Version
                channel    = 'preview'
                processor  = $repo.processor
                package    = ($package.Filename -split '/')[-1]
            }
        }
    }

    # RPM-based packages have XML metadata
    $rpmrepos = @(
        [pscustomobject]@{
            distro    = 'rhel8'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/rhel/8/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'rhel9'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/rhel/9/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'rhel80'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/rhel/8.0/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'rhel90'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/rhel/9.0/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'cbl2'
            processor = 'arm64'
            mdxml     = 'https://packages.microsoft.com/cbl-mariner/2.0/prod/Microsoft/aarch64/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'cbl2'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/cbl-mariner/2.0/prod/Microsoft/x86_64/repodata/repomd.xml'
        }
    )

    if ($null -ne $Distribution) {
        $repolist = foreach ($distro in $Distribution) {
            $rpmrepos | Where-Object { $_.distro -like "$distro*" }
        }
    } else {
        $repolist = $rpmrepos
    }

    # Download and parse RPM package information
    foreach ($repo in $repolist) {
        # Get repo metadata
        $xml = [xml](Invoke-WebRequest -Uri $repo.mdxml).Content
        $primarypath = ($xml.repomd.data | Where-Object type -eq primary).location.href
        # Get package metadata
        $primaryurl = $repo.mdxml -replace 'repodata/repomd.xml', $primarypath
        Invoke-WebRequest -Uri $primaryurl -OutFile "$env:temp\$primarypath"
        $primary = [xml](& $gzipcmd -d -c "$env:temp\$primarypath")
        # Filter and select package information
        $packages = $primary.metadata.package | Where-Object {
            $_.name -match '^powershell' -and $_.version.ver -match '^7\.[245]'
        }
        # Enumerate stable packages
        foreach ($ver in $verpatterns) {
            $package = $packages |
                Where-Object { $_.version.ver -like $ver -and $_.name -eq 'powershell'} |
                Sort-Object {[semver]($_.version.ver -replace '_','-')} -Descending |
                Select-Object -First 1
            if ($package) {
                [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = $package.version.ver
                    channel    = 'stable'
                    processor  = $repo.processor
                    package    = ($package.location.href -split '/')[-1]
                }
            }
        }
        # Enumerate lts packages
        foreach ($ver in ('7.4*','7.2*')) {
            $package = $packages |
                Where-Object { $_.version.ver -like $ver -and $_.name -eq 'powershell-lts'} |
                Sort-Object {[semver]($_.version.ver -replace '_','-')} -Descending |
                Select-Object -First 1
            if ($package) {
                [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = $package.version.ver
                    channel    = 'lts'
                    processor  = $repo.processor
                    package    = ($package.location.href -split '/')[-1]
                }
            }
        }
        # Enumerate preview packages
        $package = $packages |
            Where-Object { $_.version.ver -like '7.5*' -and $_.name -eq 'powershell-preview'} |
            Sort-Object {[semver]($_.version.ver -replace '_','-')} -Descending |
            Select-Object -First 1
        if ($package) {
            [pscustomobject]@{
                PSTypeName = 'PmcData'
                distro     = $repo.distro
                version    = $package.version.ver
                channel    = 'preview'
                processor  = $repo.processor
                package    = ($package.location.href -split '/')[-1]
            }
        }
    }
}
#-------------------------------------------------------
function Find-DockerImages {
    param(
        [ValidateSet('debian', 'ubuntu', 'rhel', 'mariner', 'alpine', 'windows')]
        [string[]]$Distribution = ('debian', 'ubuntu', 'rhel', 'mariner', 'alpine', 'windows')
    )

    $baseUrl = 'https://mcr.microsoft.com/api/v1/catalog/powershell'
    $supportedTags = Invoke-RestMethod "$baseUrl/details" |
        Select-Object -ExpandProperty supportedTags
    $allTags = Invoke-RestMethod "$baseUrl/tags"

    $images  = $allTags | Where-Object name -in $supportedTags
    foreach ($i in $images) {
        if ($i.operatingSystem -eq 'linux') {
            switch -Regex ($i.name) {
                'alpine'  { $i.operatingSystem = 'alpine'  }
                'debian'  { $i.operatingSystem = 'debian'  }
                'ubuntu'  { $i.operatingSystem = 'ubuntu'  }
                'mariner' { $i.operatingSystem = 'mariner' }
                'ubi'     { $i.operatingSystem = 'rhel'    }
            }
        }
    }

    $images |
        Where-Object operatingSystem -in $Distribution |
        Sort-Object -Property operatingSystem, name |
        Select-Object -Property name, operatingSystem, architecture, lastModifiedDate
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
function Get-DSCReleaseHistory {
    $restparams = @{
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Uri     = 'https://api.github.com/graphql'
        Body    = '{ "query" : "query { repository(name: \"DSC\", owner: \"PowerShell\") { releases(first: 100, orderBy: {field: CREATED_AT, direction: DESC}) { nodes { publishedAt name tagName } pageInfo { hasNextPage endCursor } } } }" }'
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
    $history
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
