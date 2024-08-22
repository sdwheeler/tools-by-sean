#-------------------------------------------------------
#region Initialize Environment
#-------------------------------------------------------
& {
    $pkgBase = "$env:ProgramW6432\PackageManagement\NuGet\Packages"
    $taglibBase = "$pkgBase\TagLibSharp.2.2.0\lib"
    $kustoBase = "$pkgBase\Microsoft.Azure.Kusto.Tools.6.0.3\tools"
    #$sqliteBase = "$env:ProgramW6432\System.Data.SQLite"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $taglib = "$taglibBase\netstandard2.0\TagLibSharp.dll"
        $null = [Reflection.Assembly]::LoadFrom($taglib)
        $kusto = "$kustoBase\netcoreapp2.1\Kusto.Data.dll"
        $null = [Reflection.Assembly]::LoadFrom($kusto)
    #    Add-Type -Path "$sqliteBase\netstandard2.1\System.Data.SQLite.dll"
    } else {
        $taglib = "$taglibBase\net45\TagLibSharp.dll"
        $null = [Reflection.Assembly]::LoadFrom($taglib)
        $kusto = "$kustoBase\net472\Kusto.Data.dll"
        $null = [Reflection.Assembly]::LoadFrom($kusto)
    #    Add-Type -Path "$sqliteBase\net46\System.Data.SQLite.dll"
    }
}
'Loading modules...'
Import-Module sdwheeler.GitTools -Force:$Force
Import-Module sdwheeler.EssentialUtils -Force:$Force
Import-Module sdwheeler.ContentUtils -Force:$Force
Import-Module sdwheeler.PSUtils -Force:$Force
if ($PSVersionTable.PSVersion -gt '6.0') {
    Import-Module Documentarian -Force:$Force
    Import-Module Documentarian.ModuleAuthor -Force:$Force
    Import-Module Documentarian.MicrosoftDocs -Force:$Force
    Set-Alias bcsync Sync-BeyondCompare
    Set-Alias vscsync Sync-VSCode
}

#endregion
#-------------------------------------------------------
#region Collect repo information
#-------------------------------------------------------
# Check for Git folder in the root of each drive
# If found, add it to the list of possible repo roots
$global:gitRepoRoots = @()
& {
    $gitFolders = 'My-Repos', 'PS-Docs', 'PS-Src', 'AzureDocs', 'AzureSrc', 'Learn', 'Windows',
        'APEX', 'PS-Other', 'Community', 'Conferences', 'Collabs', 'MAGIC', 'Other'
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $gitPath = Join-Path $drive.Root 'Git'
        if (Test-Path $gitPath) {
            $gitFolders | ForEach-Object {
                $gitFolder = Join-Path $gitPath $_
                if (Test-Path $gitFolder) { $global:gitRepoRoots += $gitFolder }
            }
        }
    }
}
function Get-RepoCacheAge {
    if (Test-Path ~/repocache.clixml) {
        ((Get-Date) - (Get-Item ~/repocache.clixml).LastWriteTime).TotalDays
    } else {
        [double]::MaxValue
    }
}

& {
    if (Test-Path ~/repocache.clixml) {
        $cacheage = Get-RepoCacheAge
    }
    if ($cacheage -lt 8 -or
        $null -eq (Test-Connection github.com -ea SilentlyContinue -Count 1)) {
        'Loading repo cache...'
        $global:git_repos = Import-Clixml -Path ~/repocache.clixml
    } else {
        'Scanning repos...'
        Get-MyRepos $gitRepoRoots #-Verbose:$Verbose
    }
}

Set-Location (Get-Item $gitRepoRoots[0]).Parent.FullName

$function:prompt = $Prompts.MyPrompt

#-------------------------------------------------------
#endregion
#-------------------------------------------------------

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
if ($PSVersionTable.PSVersion.ToString() -ge '7.4.0') {
    Import-Module -Name Microsoft.WinGet.CommandNotFound
}
#f45873b3-b655-43a6-b217-97c00aa0db58
