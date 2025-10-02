#-------------------------------------------------------
#region Private functions
#-------------------------------------------------------
function GetGraphQLQuery {
    param(
        [string]$org,
        [string]$repo,
        [string]$after
    )
    $GraphQLQuery = @"
query {
  repository(name: "$repo", owner: "$org") {
    releases(first: 100, after: $after, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        publishedAt
        name
        tagName
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
"@
    return $GraphQLQuery
}
#-------------------------------------------------------
#endregion module variables
#-------------------------------------------------------
#region Public functions
#-------------------------------------------------------
function Find-PmcPackages {
    param(
        [ValidateSet('debian', 'ubuntu', 'rhel', 'azurelinux')]
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

    $versions =  @{
        stable  = ('7.4*')
        lts     = ('7.4*')
        preview = ('7.6*')
    }

    # DEB-based packages metadata is YAML-like data stored in Packages files
    $debrepos = @(
        [pscustomobject]@{
            distro    = 'debian13'
            processor = 'x64'
            packages  = 'https://packages.microsoft.com/debian/13/prod/dists/trixie/main/binary-amd64/Packages'
        },
        [pscustomobject]@{
            distro    = 'debian13'
            processor = 'arm64'
            packages  = 'https://packages.microsoft.com/debian/13/prod/dists/trixie/main/binary-arm64/Packages'
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
            distro = 'ubuntu2404'
            processor = 'x64'
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
        foreach ($ver in $versions.stable) {
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
        foreach ($ver in $versions.lts) {
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
        foreach ($ver in $versions.preview) {
            $package = $packages |
                Where-Object { $_.Version -like $ver -and $_.Package -eq 'powershell-preview'} |
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
            distro    = 'rhel10'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/rhel/10/prod/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'azurelinux'
            processor = 'arm64'
            mdxml     = 'https://packages.microsoft.com/azurelinux/3.0/prod/ms-oss/aarch64/repodata/repomd.xml'
        },
        [pscustomobject]@{
            distro    = 'azurelinux'
            processor = 'x64'
            mdxml     = 'https://packages.microsoft.com/azurelinux/3.0/prod/ms-oss/x86_64/repodata/repomd.xml'
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
            $_.name -match '^powershell' -and $_.version.ver -match '^7\.[456]'
        }
        # Enumerate stable packages
        foreach ($ver in $versions.stable) {
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
        foreach ($ver in $versions.lts) {
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
        foreach ($ver in $versions.preview) {
            $package = $packages |
                Where-Object { $_.version.ver -like $ver -and $_.name -eq 'powershell-preview'} |
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
}
#-------------------------------------------------------
function Find-DotnetDockerInfo {
    param(
       [string]$Path = 'D:\Git\PS-Src\dotnet-docker\src\sdk'
    )
    $images = Get-ChildItem -Path $Path -Include dockerfile -Recurse |
        Select-String 'powershell_version[\n\s]*=|POWERSHELL_DISTRIBUTION_CHANNEL' |
        Select-Object Path, Line |
        Group-Object Path |
        Where-Object Count -ge 2

    $results = foreach ($image in $images) {
        $psver = $os = ''
        $imagePath = $image.Group.Path[0] -replace [regex]::Escape($Path), ''
        foreach ($line in $image.Group.Line) {
            $parts = $line.trim() -split '='
            if ($parts[0] -like '*powershell_version*') {
                $psver = $parts[1] -replace '[\s'';`\\]',''
            } else {
                $os = ($parts[1] -replace 'PSDocker-DotnetSDK-','') -replace '-',' '
            }
        }

        if ($psver -ge '7.4') {
            $parts = $imagePath -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
            [pscustomobject]@{
                family = switch -wildcard ($parts[2]) {
                    '*mariner*'  { 'Mariner' }
                    '*azure*'  { 'AzureLinux' }
                    '*nano*'     { 'Windows' }
                    '*windows*'  { 'Windows' }
                    '*jammy*'    { 'Ubuntu'  }
                    '*noble*'    { 'Ubuntu'  }
                    '*alpine*'   { 'Alpine'  }
                    '*bookworm*' { 'Debian'  }
                    '*trixie*'   { 'Debian'  }
                }
                os     = if ($os -ne '') { $os} else { $parts[2] }
                arch   = $parts[3]
                psver  = $psver
            }
        }
    }
    $results | Sort-Object family, os, psver, arch
}
#-------------------------------------------------------
function Find-DockerImages {

    param(
        [ValidateSet('debian', 'ubuntu', 'rhel', 'azurelinux', 'alpine', 'windows')]
        [string[]]$Distribution = (
            'debian', 'ubuntu', 'rhel', 'azurelinux', 'alpine', 'windows'
        )
    )

    $baseUrl = 'https://mcr.microsoft.com/api/v1/catalog/powershell'
    $supportedTags = Invoke-RestMethod "$baseUrl/details?reg=mar" |
        Select-Object -ExpandProperty supportedTags
    $allTags = Invoke-RestMethod "$baseUrl/tags?reg=mar"

    $images  = $allTags | Where-Object name -in $supportedTags
    foreach ($i in $images) {
        if ($i.operatingSystem -eq 'linux') {
            switch -Regex ($i.name) {
                'alpine'     { $i.operatingSystem = 'alpine'     }
                'debian'     { $i.operatingSystem = 'debian'     }
                'ubuntu'     { $i.operatingSystem = 'ubuntu'     }
                'azurelinux' { $i.operatingSystem = 'azurelinux' }
                'ubi'        { $i.operatingSystem = 'rhel'       }
            }
        }
    }

    $images |
        Where-Object operatingSystem -in $Distribution |
        Sort-Object -Property operatingSystem, name |
        Select-Object -Property name, operatingSystem, architecture,
            @{n='modifiedDate';e={'{0:yyyy-MM-dd}' -f $_.lastModifiedDate}}
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
    param(
        [switch]$AllVersions
    )
    $query = GetGraphQLQuery -org 'PowerShell' -repo 'DSC' -after 'null'
    $irmSplat = @{
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Uri     = 'https://api.github.com/graphql'
        Body    = @{ query = $query } | ConvertTo-Json -Compress
        Method  = 'POST'
    }
    $hasNextPage = $true

    $history = while ($hasNextPage) {
        $result = Invoke-RestMethod @irmSplat
        $result.data.repository.releases.nodes |
            Select-Object @{n = 'Version'; e = { $_.tagName.Substring(0, 4) } },
            @{n = 'Tag'; e = { $_.tagName } },
            @{n = 'Date'; e = { '{0:yyyy-MM-dd}' -f $_.publishedAt } }
        $hasNextPage = $result.data.repository.releases.pageInfo.hasNextPage
        $after = '"',$result.data.repository.releases.pageInfo.endCursor,'"' -join ''
        $query = GetGraphQLQuery -org 'PowerShell' -repo 'PowerShell' -after $after
        $irmSplat.Body = @{ query = $query} | ConvertTo-Json -Compress
    }

    if ($AllVersions) {
        $history
    } else {
        $history |
            Group-Object Version |
            Sort-Object Name -Descending |
            ForEach-Object { $_.Group | Select-Object -First 1 }
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

    $history = @()
    $lifecycle = Get-Content -Path PowerShellLifecycle.jsonc | ConvertFrom-Json -AsHashtable
    $query = GetGraphQLQuery -org 'PowerShell' -repo 'PowerShell' -after 'null'
    $irmSplat = @{
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Uri     = 'https://api.github.com/graphql'
        Body    = @{ query = $query} | ConvertTo-Json -Compress
        Method  = 'POST'
    }
    $hasNextPage = $true

    while ($hasNextPage) {
        $irmSplat.Body = @{ query = $query} | ConvertTo-Json -Compress
        $result = Invoke-RestMethod @irmSplat
        $result.data.repository.releases.nodes |
            Where-Object tagName -gt 'v5.1' |
            ForEach-Object {
                $history += [pscustomobject]@{
                    PSTypeName = 'ReleaseInfoData'
                    Version = $_.tagName.Substring(0, 4)
                    Tag = $_.tagName
                    ReleaseDate = '{0:yyyy-MM-dd}' -f $_.publishedAt
                    DotnetVersion = $lifecycle[$_.tagName.Substring(0, 4)].Dotnet
                    EndOfSupport = $lifecycle[$_.tagName.Substring(0, 4)].EndOfSupport
                }
            }
        $hasNextPage = $result.data.repository.releases.pageInfo.hasNextPage
        $after = '"',$result.data.repository.releases.pageInfo.endCursor,'"' -join ''
        $query = GetGraphQLQuery -org 'PowerShell' -repo 'PowerShell' -after $after
    }

    switch ($PSCmdlet.ParameterSetName) {
        'ByVersion' {
            if ($Version -eq '') {
                $groupedByVersion = $history |
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
#endregion Public functions
#-------------------------------------------------------