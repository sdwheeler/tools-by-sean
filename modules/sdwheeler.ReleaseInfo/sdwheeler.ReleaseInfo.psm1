# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
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
        url
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
$eolCategories = (Invoke-RestMethod https://endoflife.date/api/v1/categories).result
#-------------------------------------------------------
#endregion module variables
#-------------------------------------------------------
#region Public functions
#-------------------------------------------------------
function Find-PmcPackage {
    <#
    .SYNOPSIS
    Gets information about PowerShell packages from the Microsoft Package Cache (PMC).
    .DESCRIPTION
    Gets information about PowerShell packages that are published to https://packages.microsoft.com.
    By default, packages for all supported distributions are returned, but you can filter by specific distribution(s) using the -Distribution parameter.
    .PARAMETER Distribution
    The distribution(s) to filter by. Valid values are 'debian', 'ubuntu', 'rhel', 'azurelinux'.
    You can specify multiple values for this parameter. If not specified, packages for all
    supported distributions are returned.
    #>
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

    $pmcVersionInfo = Get-Content -Path "$PSScriptRoot\PmcVersionInfo.jsonc" | ConvertFrom-Json
    $versions =  $pmcVersionInfo.versions
    $debrepos = $pmcVersionInfo.debrepos
    $rpmrepos = $pmcVersionInfo.rpmrepos

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
            Select-String -Pattern '^Package:|^Version:|^Filename:' |
            Select-Object -ExpandProperty Line
        # Filter and select package information
        $packages = @()
        for ($i = 0; $i -lt $lines.Count; $i += 3) {
            $pkg = [pscustomobject]($lines[$i..($i + 2)] | ConvertFrom-Yaml)
            if ($pkg.Package -match '^powershell' -and $pkg.Version -match '^7\.\d+') {
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
                    version    = [semver]$package.Version
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
                    version    = [semver]$package.Version
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
                    version    = [semver]$package.Version
                    channel    = 'preview'
                    processor  = $repo.processor
                    package    = ($package.Filename -split '/')[-1]
                }
            }
        }
    }

    # RPM-based packages have XML metadata

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
            $_.name -match '^powershell' -and $_.version.ver -match '^7\.\d+'
        }
        $results = @()
        # Enumerate stable packages
        foreach ($ver in $versions.stable) {
            $package = $packages |
                Where-Object { $_.version.ver -like $ver -and $_.name -eq 'powershell'} |
                Sort-Object {[semver]($_.version.ver -replace '_','-')} -Descending |
                Select-Object -First 1
            if ($package) {
                $results += [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = [semver]$package.version.ver
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
                $results += [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = [semver]$package.version.ver
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
                $results += [pscustomobject]@{
                    PSTypeName = 'PmcData'
                    distro     = $repo.distro
                    version    = [semver]($package.version.ver -replace '_','-')
                    channel    = 'preview'
                    processor  = $repo.processor
                    package    = ($package.location.href -split '/')[-1]
                }
            }
        }
        $results | Sort-Object distro, version, channel, processor
    }
}
Set-Alias Find-PmcPackages Find-PmcPackage
#-------------------------------------------------------
function Find-DotnetDockerInfo {
    <#
    .SYNOPSIS
    Gets information about .NET SDK Docker images that have PowerShell installed from the
    dotnet/dotnet-docker repository.
    .DESCRIPTION
    Gets information about .NET SDK Docker images that have PowerShell installed from the
    dotnet/dotnet-docker repository. You must have a local clone of the repository to use this
    command, and you must specify the path to the repository with the -Path parameter. The command
    extracts the information from the Dockerfile images in the src/sdk directory.
    .PARAMETER Path
    The path to the local clone of the dotnet/dotnet-docker repository.
    #>
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
            $value = if ($line -match '.+=([^\s]+)') { $Matches[1] }
            if ($line -like '*powershell_version*') {
                $psver = $value
            } else {
                $os = $value -replace 'PSDocker-DotnetSDK-',''
            }
        }

        if ($psver -ge '7.4') {
            $parts = $imagePath -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
            [pscustomobject]@{
                PSTypeName = 'DockerInfo'
                family     = switch -wildcard ($parts[2]) {
                    '*mariner*'  { 'Mariner' }
                    '*azure*'  { 'AzureLinux' }
                    '*nano*'     { 'Windows' }
                    '*windows*'  { 'Windows' }
                    '*jammy*'    { 'Ubuntu' }
                    '*noble*'    { 'Ubuntu' }
                    '*resolute*' { 'Ubuntu' }
                    '*alpine*'   { 'Alpine' }
                    '*bookworm*' { 'Debian' }
                    '*trixie*'   { 'Debian' }
                }
                os         = if ($os -ne '') { $os } else { $parts[2] }
                dotnetver  = [version]$parts[1]
                arch       = $parts[3]
                psver      = $psver
            }
        }
    }
    $results | Sort-Object family, os, dotnetver, arch
}
#-------------------------------------------------------
function Find-DockerImage {
    <#
    .SYNOPSIS
    Gets information about PowerShell-based Docker images from the Microsoft Container Registry
    (MAR).
    .DESCRIPTION
    Gets information about PowerShell-based Docker images from MAR. By default, images for all
    supported distributions are returned, but you can filter by specific distribution(s) using the
    -Distribution parameter.
    .PARAMETER Distribution
    The distribution(s) to filter by. Valid values are 'debian', 'ubuntu', 'rhel', 'azurelinux',
    'alpine', 'windows'. You can specify multiple values for this parameter. If not specified,
    images for all supported distributions are returned.
    .NOTES
    These Docker images are no longer maintained. Use the .NET SDK Docker images instead.
    #>
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
Set-Alias Find-DockerImages Find-DockerImage
#-------------------------------------------------------
function Get-OSEndOfLife {
    <#
    .SYNOPSIS
    Gets end of life information for operating systems supported by PowerShell from
    https://endoflife.date.
    .DESCRIPTION
    Gets end of life information for operating systems supported by PowerShell.By default, all
    supported operating systems are included, but you can filter by specific operating system.

    The command only shows the supported versions. If you want the whole release history, use the
    Get-EndOfLife command.
    .PARAMETER OS
    The operating system to query. You can use tab completion with the parameter to see available
    operating systems.
    .EXAMPLE
    Get-OSEndOfLife ubuntu

    os     cycle latest  codename        endOfSupport endOfLife  endOfExtSupport lts
    --     ----- ------  --------        ------------ ---------  --------------- ---
    ubuntu 25.10 25.10   Questing Quokka 2026-07-01   2026-07-01                 False
    ubuntu 24.04 24.04.4 Noble Numbat    2029-05-31   2029-05-31 2036-05-31      True
    ubuntu 22.04 22.04.5 Jammy Jellyfish 2024-09-30   2027-04-01 2032-04-09      True
    #>
    param (
        [Parameter(Position = 0)]
        [ValidateSet('alpine-linux', 'debian', 'macos', 'rhel', 'ubuntu', 'windows', 'windows-server')]
        [string[]]$OS = ('alpine-linux', 'debian', 'macos', 'rhel', 'ubuntu', 'windows', 'windows-server')
    )
    $links = [ordered]@{
        'alpine-linux'   = 'https://endoflife.date/api/v1/products/alpine'
        debian           = 'https://endoflife.date/api/v1/products/debian'
        macos            = 'https://endoflife.date/api/v1/products/macos'
        rhel             = 'https://endoflife.date/api/v1/products/rhel'
        ubuntu           = 'https://endoflife.date/api/v1/products/ubuntu'
        windows          = 'https://endoflife.date/api/v1/products/windows'
        'windows-server' = 'https://endoflife.date/api/v1/products/windows-server'
    }

    $results = $links.GetEnumerator().Where({$_.Name -in $OS}) |
    ForEach-Object {
        $item = (Invoke-RestMethod $_.Value).result
        foreach ($release in $item.releases) {
            if ($release.isEol -eq $false) {
                [pscustomobject]@{
                    PSTypeName        = 'EolData'
                    product           = $item.name
                    cycle             = $release.name
                    latest            = $release.latest.name
                    codename          = $release.codename
                    releaseDate       = $release.releaseDate
                    latestReleaseDate = $release.latest.date
                    endOfSupport      = $release.eoasFrom
                    endOfLife         = $release.eolFrom
                    endOfExtSupport   = $release.eoesFrom
                    isEol             = $release.isEol
                    isLts             = $release.isLts
                    link              = $release.latest.link
                }
            }
        }
    }
    $results | Sort-Object product,@{Expr={[version]($_.latest)}; Desc=$true}
}
#-------------------------------------------------------
function Get-EndOfLife {
    <#
    .SYNOPSIS
    Gets end of life information for products from https://endoflife.date.
    .DESCRIPTION
    Gets end of life information for products from https://endoflife.date. When you specify a
    Category, the command return a list of products in that category. Use that information to find
    the product name. When you specify a product name, the command returns all of its releases for
    that product.
    .PARAMETER Name
    The name of the product to query. The command uses regular expression matching for that value.
    .PARAMETER Category
    The category to query. The parameter supports wildcards. You can use tab completion with the
    parameter to see available categories.
    .EXAMPLE
    Get-EndOfLife -Category standard

    name    category product   uri
    ----    -------- -------   ---
    pci-dss standard PCI-DSS   https://endoflife.date/api/v1/products/pci-dss
    tls     standard TLS       https://endoflife.date/api/v1/products/tls
    .EXAMPLE
    Get-EndOfLife debian

    product cycle latest    codename endOfSupport endOfLife  endOfExtSupport isEol isLts
    ------- ----- ------    -------- ------------ ---------  --------------- ----- -----
    debian  13    13.4      Trixie                2028-08-09 2030-06-30      False False
    debian  12    12.13     Bookworm              2026-06-10 2028-06-30      False False
    debian  11    11.11     Bullseye              2024-08-14 2026-08-31      True  False
    debian  10    10.13     Buster                2022-09-10 2024-06-30      True  False
    debian  9     9.13      Stretch               2020-07-18 2022-07-01      True  False
    debian  8     8.11      Jessie                2018-06-17 2020-06-30      True  False
    debian  7     7.11      Wheezy                2016-04-25 2018-05-31      True  False
    debian  6     6.0.10    Squeeze               2014-05-31 2016-02-29      True  False
    debian  5     5.0.10    Lenny                 2012-02-06 2012-02-06      True  False
    debian  4     4.0r9     Etch                  2010-02-15 2010-02-15      True  False
    debian  3.1   3.1r8     Sarge                 2008-03-31 2008-03-31      True  False
    debian  3.0   3.0r6     Woody                 2006-06-30 2006-06-30      True  False
    debian  2.2   2.2r7     Potato                2003-06-30 2003-06-30      True  False
    debian  2.1   2.1r5     Slink                 2000-09-30 2000-10-30      True  False
    debian  2.0   2.0r5     Hamm                  1999-02-15 1999-02-15      True  False
    debian  1.3   1.3.1 r.6 Bo                    1998-12-08 1998-12-08      True  False
    debian  1.2   1.2       Rex                   1997-10-23 1997-10-23      True  False
    debian  1.1   1.1       Buzz                  1996-12-12 1996-12-12      True  False
    #>
    [CmdletBinding(DefaultParameterSetName='ByName')]
    param (
        [Parameter(Position = 0, ParameterSetName='ByName')]
        [string[]]$Name,

        [Parameter(ParameterSetName='ListCategories')]
        [SupportsWildcards()]
        [string[]]$Category
    )

    if ($Category.Count -ne 0) {
        $categories = foreach ($cat in $Category) {
            ($eolCategories | Where-Object name -like $cat).uri
        }
        if ($Category -ne '') {
            foreach ($cat in $categories) {
                (Invoke-RestMethod $cat).result |
                Sort-Object -Property label, category |
                Select-Object -Property name, category, @{n='product'; e={$_.label}}, uri
            }
            return
        }
    }

    if ($Name.Count -ne 0) {
        $products = (Invoke-RestMethod https://endoflife.date/api/v1/products).result
        foreach ($n in $Name) {
            $plist = $products | Where-Object name -match $n
            if ($plist.Count -lt 1) {
                Write-Warning "Product '$n' not found."
                continue
            }

            foreach ($p in $plist) {
                $item = (Invoke-RestMethod $p.uri).result
                foreach ($release in $item.releases) {
                    [pscustomobject]@{
                        PSTypeName        = 'EolData'
                        product           = $item.name
                        cycle             = $release.name
                        latest            = $release.latest.name
                        codename          = $release.codename
                        releaseDate       = $release.releaseDate
                        latestReleaseDate = $release.latest.date
                        endOfSupport      = $release.eoasFrom
                        endOfLife         = $release.eolFrom
                        endOfExtSupport   = $release.eoesFrom
                        isEol             = $release.isEol
                        isLts             = $release.isLts
                        link              = $release.latest.link
                    }
                }
            }
        }
    }
}
#-------------------------------------------------------
function Get-DSCReleaseHistory {
    <#
    .SYNOPSIS
    Gets release history for DSC releases.
    .DESCRIPTION
    Gets release history for DSC v3 releases. By default, only the latest release for each major.minor version is returned, but this can be modified with the available parameters.

    This command uses the GitHub GraphQL API to query release information. To use this command, a
    GitHub personal access token is required. The token should be stored in an environment variable
    named GITHUB_TOKEN.
    .PARAMETER AllVersions
    If specified, all releases are returned. Otherwise, only the latest release for each major.minor version is returned.
    #>
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
    <#
    .SYNOPSIS
    Gets release history for PowerShell releases.
    .DESCRIPTION
    Gets release history for PowerShell releases. By default, only the latest release for each major.minor version is returned, but this can be modified with the available parameters.

    This command uses the GitHub GraphQL API to query release information. To use this command, a
    GitHub personal access token is required. The token should be stored in an environment variable
    named GITHUB_TOKEN.
    .PARAMETER Version
    The major.minor version to filter by (e.g. '7.5'). If not specified, the latest release for each major.minor version are returned.
    .PARAMETER Current
    If specified, only releases for the currently running version ofPowerShell are returned.
    .PARAMETER GeneralAvailability
    If specified, only GA releases (i.e. tags that end with '.0') are returned.
    .PARAMETER All
    If specified, all releases are returned.
    .EXAMPLE
    Get-PSReleaseHistory

    Version Tag         ReleaseDate DotnetVersion SupportType EndOfSupport
    ------- ---         ----------- ------------- ----------- ------------
    v7.6    v7.6.0-rc.1 2026-02-20  .NET 10.0     Preview
    v7.5    v7.5.4      2025-10-20  .NET 9.0      STS         2026-05-12
    v7.4    v7.4.13     2025-10-20  .NET 8.0      LTS         2026-11-10
    v7.3    v7.3.12     2024-04-11  .NET 7.0      STS         2024-05-08
    v7.2    v7.2.24     2024-10-22  .NET 6.0      LTS         2024-11-08
    v7.1    v7.1.7      2022-04-26  .NET 5.0      STS         2022-05-08
    v7.0    v7.0.13     2022-10-20  .NET Core 3.1 LTS         2022-12-03
    v6.2    v6.2.7      2020-07-16  .NET Core 2.1 STS         2020-09-04
    v6.1    v6.1.6      2019-09-12  .NET Core 2.1 STS         2019-09-28
    v6.0    v6.0.5      2018-11-13  .NET Core 2.0 STS         2019-02-13
    #>
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
    $lifecycle = Get-Content -Path $PSScriptRoot\PowerShellLifecycle.jsonc -Raw |
        ConvertFrom-Json -AsHashtable
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
                    SupportType = if ($_.tagName -like '*-*') {
                        'Preview'
                    } else {
                        $lifecycle[$_.tagName.Substring(0, 4)].Support
                    }
                    EndOfSupport = $lifecycle[$_.tagName.Substring(0, 4)].EndOfSupport
                    ReleaseUrl = $_.url
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
    <#
    .SYNOPSIS
    Gets release assets for a given PowerShell release tag.
    .DESCRIPTION
    Gets release assets for a given PowerShell release tag. If a file name is specified, only the asset with that name is downloaded. Otherwise, all assets are listed.

    This command uses the GitHub REST API to query release information. To use this command, a
    GitHub personal access token is required. The token should be stored in an environment variable
    named GITHUB_TOKEN.
    .PARAMETER Tag
    The release tag to query.
    .PARAMETER FileName
    The name of the asset to download. If not specified, the command lists the available assets.
    .PARAMETER OutputPath
    The directory to which assets will be downloaded. Defaults to the current directory.
    .EXAMPLE
    Get-PSReleasePackage v7.5.4 PowerShell-7.5.4-win-x64.msi

    This example downloads PowerShell-7.5.4-win-x64.msi to the current directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^v\d\.\d+\.\d+(-\p{L}+\.?\d*)?$')]
        [string]$Tag,

        [Parameter(Position = 1)]
        [string[]]$FileName,

        [Parameter(Position = 2)]
        [string]$OutputPath = '.'
    )
    try {
        $irmSplat = @{
            Headers     = @{
                Accept        = 'application/vnd.github.v4.json'
                Authorization = "bearer $env:GITHUB_TOKEN"
            }
            Uri           = "https://api.github.com/repos/PowerShell/PowerShell/releases/tags/$tag"
            ErrorAction   = 'Stop'
        }
        $release = Invoke-RestMethod @irmSplat
        if ($release.assets.Count -eq 0) {
            Write-Warning "No assets found for release '$Tag'."
            return
        }
    } catch {
        Write-Error ("Error fetching release tag '$Tag'." +
            [Environment]::NewLine + $_.Exception.Message)
    }
    if ($FileName.Count -eq 0) {
        $release.assets | Select-Object name, size, browser_download_url
    } else {
         $release.assets |
            Where-Object name -in $FileName |
            ForEach-Object {
                $outputFile = Join-Path $OutputPath $_.name
                Invoke-WebRequest -Uri $_.browser_download_url -OutFile $outputFile
                Get-Item $outputFile
            }
    }
}
#-------------------------------------------------------
function Get-PSModuleVersion {
    <#
    .SYNOPSIS
        Gets version information for PowerShell modules in a specified path.

    .DESCRIPTION
        The Get-PSModuleVersion function scans a directory for PowerShell modules and retrieves
        version information from their module manifests (.psd1 files). The manifest file is parsed
        using Import-PowerShellDataFile. The module isn't imported into the session, so any
        executable code in the manifest won't be executed. If a manifest file can't be parsed, the
        error type is returned in the ParseStatus property.

    .PARAMETER ModulePath
        The path to the directory containing PowerShell modules. Defaults to the PowerShell modules
        directory ($PSHOME/modules). The command recursively searches for module manifests in the
        specified directory tree.

    .EXAMPLE
        Get-PSModuleVersion

        Name                                 Version    Prerelease   ParseStatus
        ----                                 -------    ----------   -----------
        CimCmdlets                           7.0.0.0                 OK
        Microsoft.PowerShell.Archive         1.2.5                   OK
        Microsoft.PowerShell.Diagnostics     7.0.0.0                 OK
        Microsoft.PowerShell.Host            7.0.0.0                 OK
        Microsoft.PowerShell.Management      7.0.0.0                 OK
        Microsoft.PowerShell.PSResourceGet   1.2.0                   OK
        Microsoft.PowerShell.Security        7.0.0.0                 OK
        Microsoft.PowerShell.ThreadJob       2.2.0                   OK
        Microsoft.PowerShell.Utility         7.0.0.0                 OK
        Microsoft.WSMan.Management           7.0.0.0                 OK
        PackageManagement                    1.4.8.1                 OK
        PowerShellGet                        2.2.5                   OK
        PSDiagnostics                        7.0.0.0                 OK
        PSReadLine                           2.4.5                   OK

        Gets version information for all modules in the default PowerShell installation directory.

    .EXAMPLE
        Get-PSModuleVersion -ModulePath "C:\Users\Username\Documents\PowerShell\Modules"

        Gets version information for all modules in the user's PowerShell modules directory.

    .OUTPUTS
        PSModuleVersionInfo

    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$ModulePath = "$PSHOME/modules"
    )
    $modPaths = Get-ChildItem -Path $ModulePath -Directory
    foreach ($modPath in $modPaths) {
        $result = [pscustomobject]@{
            PSTypeName  = 'PSModuleVersionInfo'
            Name        = $modPath.Name
            Version     = ''
            Prerelease  = ''
            ParseStatus = ''
        }
        $path = Get-ChildItem -Path $modPath.FullName -Include "$($modPath.Name).psd1" -Recurse
        foreach ($p in $path) {
            try {
                $paramSplat = @{
                    Path = $p.FullName
                    SkipLimitCheck = $true
                    ErrorAction = 'Stop'
                }
                $moduleInfo = Import-PowerShellDataFile @paramSplat
                $result.Version = $moduleInfo.ModuleVersion
                $result.Prerelease = $moduleInfo.PrivateData.PSData.Prerelease
                $result.ParseStatus = 'OK'
                $result
            } catch {
                $fullyQualifiedErrorId = $_.FullyQualifiedErrorId.Split(',')[0]
                # Skip non-module manifest files
                if ($fullyQualifiedErrorId -ne 'CouldNotParseAsPowerShellDataFileNoHashtableRoot') {
                    # Manifest files with executable code throw System.InvalidOperationException
                    # Executable code is allowed by Import-Module but not Import-PowerShellDataFile
                    $result.ParseStatus = $fullyQualifiedErrorId
                    $result
                }
            }
        }
    }
}
#-------------------------------------------------------
function Get-DotnetRelease {
    <#
    .SYNOPSIS
    Gets release information for .NET releases from the dotnet/core repository.
    .DESCRIPTION
    Gets release information for .NET releases from the dotnet/core repository. The command extracts
    the information from the releases-index.json file in the repository, which contains information
    about all .NET releases, including the latest release for each channel and the latest SDK
    version for each release.
    .EXAMPLE
    Get-DotnetRelease

    product   channel type support eolDate    version          sdkVersion
    -------   ------- ---- ------- -------    -------          ----------
    .NET      11.0    sts  preview            11.0.0-preview.2 11.0.100-preview.2.26159.112
    .NET      10.0    lts  active  2028-11-14 10.0.5           10.0.201
    .NET      9.0     sts  active  2026-11-10 9.0.14           9.0.312
    .NET      8.0     lts  active  2026-11-10 8.0.25           8.0.419
    .NET      7.0     sts  eol     2024-05-14 7.0.20           7.0.410
    .NET      6.0     lts  eol     2024-11-12 6.0.36           6.0.428
    .NET      5.0     sts  eol     2022-05-10 5.0.17           5.0.408
    .NET Core 3.1     lts  eol     2022-12-13 3.1.32           3.1.426
    .NET Core 3.0     sts  eol     2020-03-03 3.0.3            3.0.103
    .NET Core 2.1     lts  eol     2021-08-21 2.1.30           2.1.818
    .NET Core 2.2     sts  eol     2019-12-23 2.2.8            2.2.207
    .NET Core 2.0     sts  eol     2018-10-01 2.0.9            2.1.202
    .NET Core 1.1     lts  eol     2019-06-27 1.1.13           1.1.14
    .NET Core 1.0     lts  eol     2019-06-27 1.0.16           1.1.14
    #>
    $releases = Invoke-RestMethod https://raw.githubusercontent.com/dotnet/core/refs/heads/main/release-notes/releases-index.json
    foreach ($release in $releases.'releases-index') {
        [PSCustomObject]@{
            PSTypeName = 'DotnetReleaseInfo'
            product    = $release.'product'
            channel    = $release.'channel-version'
            type       = $release.'release-type'
            support    = $release.'support-phase'
            eolDate    = $release.'eol-date'
            version    = $release.'latest-release'
            sdkVersion = $release.'latest-sdk'
        }
    }
}
#-------------------------------------------------------
#endregion Public functions
#-------------------------------------------------------
#region Argument completers
#-------------------------------------------------------
$sbEOLCategories = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $eolCategories |
        Where-Object { $_.name -like "$wordToComplete*" } |
        Select-Object -ExpandProperty name
}
Register-ArgumentCompleter -CommandName Get-EndOfLife -ParameterName Category -ScriptBlock $sbEOLCategories
#-------------------------------------------------------
#endregion Argument completers
#-------------------------------------------------------
