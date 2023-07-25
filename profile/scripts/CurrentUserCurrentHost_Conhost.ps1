[CmdletBinding()]
param(
    [switch]$SkipRepos,
    [switch]$Force
)

#-------------------------------------------------------
#region Initialize Environment
#-------------------------------------------------------
$pkgBase = "$env:ProgramW6432\PackageManagement\NuGet\Packages"
$taglibBase = "$pkgBase\TagLibSharp.2.2.0\lib"
$kustoBase = "$pkgBase\Microsoft.Azure.Kusto.Tools.6.0.3\tools"
$sqliteBase = "$env:ProgramW6432\System.Data.SQLite.1.0.116"
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $taglib = "$taglibBase\netstandard2.0\TagLibSharp.dll"
    $null = [Reflection.Assembly]::LoadFrom($taglib)
    $kusto = "$kustoBase\netcoreapp2.1\Kusto.Data.dll"
    $null = [Reflection.Assembly]::LoadFrom($kusto)
    Add-Type -Path "$sqliteBase\netstandard2.1\System.Data.SQLite.dll"
} else {
    $taglib = "$taglibBase\net45\TagLibSharp.dll"
    $null = [Reflection.Assembly]::LoadFrom($taglib)
    $kusto = "$kustoBase\net472\Kusto.Data.dll"
    $null = [Reflection.Assembly]::LoadFrom($kusto)
    Add-Type -Path "$sqliteBase\net46\System.Data.SQLite.dll"
}

'Loading modules...'
Import-Module sdwheeler.GitTools -Force:$Force
Import-Module sdwheeler.EssentialUtils -Force:$Force
Import-Module sdwheeler.ContentUtils -Force:$Force
Import-Module sdwheeler.PSUtils -Force:$Force
if ($PSVersionTable.PSVersion -gt '6.0') {
    Import-Module Documentarian.MicrosoftDocs -Force:$Force
    Set-Alias bcsync Sync-BeyondCompare
    Set-Alias vscsync Sync-VSCode
}

#endregion
#-------------------------------------------------------
#region Collect repo information
#-------------------------------------------------------
$global:gitRepoRoots = @()
$d = Get-PSDrive d -ea SilentlyContinue
$gitFolders = 'My-Repos', 'PS-Docs', 'PS-Src', 'AzureDocs', 'Learn', 'Windows', 'APEX', 'PS-Other',
'Community', 'Conferences', 'Leanpub', 'Office', 'PS-Loc',
'SCCM'
$gitFolders | ForEach-Object {
    if (Test-Path "C:\Git\$_") { $global:gitRepoRoots += "C:\Git\$_" }
    if ($d) {
        if (Test-Path "D:\Git\$_") { $global:gitRepoRoots += "D:\Git\$_" }
    }
}

function Get-RepoCacheAge {
    if (Test-Path ~/repocache.clixml) {
        ((Get-Date) - (Get-Item ~/repocache.clixml).LastWriteTime).TotalDays
    } else {
        [double]::MaxValue
    }
}

if (-not $SkipRepos) {
    if (Test-Path ~/repocache.clixml) {
        $cacheage = Get-RepoCacheAge
    }
    if ($cacheage -lt 8 -or $null -eq (Test-Connection github.com -ea SilentlyContinue -Count 1)) {
        'Loading repo cache...'
        $global:git_repos = Import-Clixml -Path ~/repocache.clixml
    } else {
        'Scanning repos...'
        Get-MyRepos $gitRepoRoots #-Verbose:$Verbose
    }
}

if (Test-Path C:\Git) {
    Set-Location C:\Git
} elseif (Test-Path D:\Git) {
    Set-Location D:\Git
}

$function:prompt = $Prompts.MyPrompt

#-------------------------------------------------------
#endregion
#-------------------------------------------------------
