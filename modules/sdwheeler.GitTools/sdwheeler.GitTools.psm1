#-------------------------------------------------------
#region Initialization
$gitcmd = Get-Command git
#endregion Initialization
#-------------------------------------------------------
#region Private functions
function GetIterationPaths {
    param(
        [switch]$Current,
        [datetime]$Date
    )
    if ($Current) {
        $Date = Get-Date
    }
    $baseurl = 'https://dev.azure.com/msft-skilling/content/powershell/_apis'
    $apiurl = 'work/teamsettings/iterations?api-version=7.0'
    $username = ' '
    $password = ConvertTo-SecureString $env:CLDEVOPS_TOKEN -AsPlainText -Force
    $cred = [PSCredential]::new($username, $password)
    $params = @{
            uri            = "$baseurl/$apiurl"
            Authentication = 'Basic'
            Credential     = $cred
            Method         = 'Get'
            ContentType    = 'application/json-patch+json'
    }
    $iterations = (Invoke-RestMethod @params).value |
        Select-Object name,
                      path,
                      @{n='startDate'; e={[datetime]$_.attributes.startDate}},
                      @{n='finishDate'; e={[datetime]$_.attributes.finishDate}},
                      @{n='timeFrame'; e={$_.attributes.timeFrame}}
    if ($Current) {
        $iterations | Where-Object timeFrame -eq 'current'
    } elseif ($null -ne $Date) {
        $iterations | Where-Object {($Date) -ge $_.startDate -and ($Date) -le $_.finishDate}
    } else {
        $iterations
    }
}
#-------------------------------------------------------
function GetAreaPaths {
    [string[]]$areaPathList = @(
        'Content',
        'Content\Production\Infrastructure\Azure e2e\PowerShell'
    )
    $areaPathList
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Repo root management
#-------------------------------------------------------
function Get-RepoRootList {
    if (Test-Path -Path ~/gitreporoots.csv) {
        Import-Csv -Path ~/gitreporoots.csv
    } else {
        Write-Error "File ~/gitreporoots.csv not found."
    }
}
#-------------------------------------------------------
function New-RepoRootList {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like "$($_.Name)*" }
    $csvdata = @()
    foreach ($drive in $drives) {
        $gitPath = Join-Path $drive.Root 'Git'
        if (Test-Path -Path $gitPath) {
            Get-ChildItem -Path $gitPath -Directory |
                ForEach-Object {
                    $csvdata += [PSCustomObject]@{
                        Path    = $_.FullName
                        Include = $true
                    }
                }
        }
    }
    $csvdata | Export-Csv -Path ~/gitreporoots.csv -NoTypeInformation -Force
}
#-------------------------------------------------------
function Add-RepoRoot {
    param (
        [string[]]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Path '$Path' does not exist."
        return
    }
    $repos = Get-RepoRootList
    foreach ($p in $Path) {
        if (-not (Test-Path -Path $p)) {
            Write-Error "Path '$p' does not exist."
        } else {
            if ($p -in $repos.Path) {
                Write-Error "Path '$p' already exists in repo root list."
            } else {
                $newEntry = [PSCustomObject]@{
                    Path    = $p
                    Include = $true
                }
                $repos += $newEntry
            }
        }
    }
    $repos | Export-Csv -Path ~/gitreporoots.csv -NoTypeInformation -Force
}
#-------------------------------------------------------
function Disable-RepoRoot {
    param (
        [string[]]$Path
    )
    $repos = Get-RepoRootList
    foreach ($p in $Path) {
        $repo = $repos | Where-Object Path -eq $p
        if ($null -ne $repo) {
            $repo.Include = $false
            $repos | Export-Csv -Path ~/gitreporoots.csv -NoTypeInformation -Force
        } else {
            Write-Error "Path '$p' not found in repo root list."
        }
    }
}
#-------------------------------------------------------
function Enable-RepoRoot {
    param (
        [string[]]$Path
    )
    $repos = Get-RepoRootList
    foreach ($p in $Path) {
        $repo = $repos | Where-Object Path -eq $p
        if ($null -ne $repo) {
            $repo.Include = $true
            $repos | Export-Csv -Path ~/gitreporoots.csv -NoTypeInformation -Force
        } else {
            Write-Error "Path '$p' not found in repo root list."
        }
    }
}
#-------------------------------------------------------
function Find-GitRepo {
    $repoRoots = Get-RepoRootList | Where-Object Include -eq 'True'
    foreach ($root in $repoRoots) {
        Get-ChildItem -Path $root.Path -Directory -Recurse -Depth 2 -Hidden .git |
            ForEach-Object { $_.Parent.FullName }
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Repo data management
#-------------------------------------------------------
function Invoke-GitHubApi {
    <#
    .SYNOPSIS
    Invoke a GitHub API.

    .PARAMETER Api
    The API endpoint to call.

    .PARAMETER Method
    The HTTP method to use (GET, POST, etc.).

    .PARAMETER Body
    A JSON string containing the data to send (for POST/PUT requests).
    #>
    param(
        [string]$Api,

        [Microsoft.PowerShell.Commands.WebRequestMethod]
        $Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
        [string]$Body
    )
    $baseuri = 'https://api.github.com/'
    if ($api -like "$baseuri*") {
        $uri = $api
    } else {
        $uri = $baseuri + $api
    }
    $hdr = @{
        Accept                 = 'application/vnd.github.raw+json'
        Authorization          = "token ${Env:\GITHUB_TOKEN}"
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $invokeRestMethodSplat = @{
        Headers       = $hdr
        Uri           = $uri
        Method        = $method
        FollowRelLink = $true
    }
    if ($Body) {
        $invokeRestMethodSplat.Add('Body', $Body)
    }
    $results = Invoke-RestMethod @invokeRestMethodSplat
    foreach ($page in $results) { $page }
}
#-------------------------------------------------------
function Get-RepoCacheAge {
    if (Test-Path ~/repocache.clixml) {
        ((Get-Date) - (Get-Item ~/repocache.clixml).LastWriteTime).TotalDays
    } else {
        [double]::MaxValue
    }
}
#-------------------------------------------------------
function Get-MyRepos {
    [CmdletBinding()]
    param()
    $startLocation = $PWD
    $originalDirs = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        if ($_.Root -like "$($_.Name)*") {join-path $_.Root $_.CurrentLocation}
    }

    $my_repos = @{}
    $repoFolders = Find-GitRepo

    foreach ($folder in $repoFolders) {
        Push-Location $folder
        Write-Verbose $PWD
        $currentRepo = New-RepoData
        $my_repos.Add($currentRepo.name, $currentRepo)
        Pop-Location
    }

    $global:git_repos = $my_repos
    '{0} repos found.' -f $global:git_repos.Count

    $global:git_repos | Export-Clixml -Depth 10 -Path ~/repocache.clixml -Force

    Write-Verbose '----------------------------'
    Write-Verbose 'Restoring drive locations'
    $originalDirs | Set-Location -PassThru | Write-Verbose
    Set-Location $startLocation
}
#-------------------------------------------------------
function Get-RepoData {
    [CmdletBinding(DefaultParameterSetName = 'reponame')]
    param(
        [Parameter(ParameterSetName = 'reponame', Position = 0)]
        [SupportsWildcards()]
        [alias('name')]
        [string]$RepoName,

        [Parameter(ParameterSetName = 'orgname', Mandatory)]
        [alias('org')]
        [string]$Organization
    )

    if ($Organization) {
        $global:git_repos.Values | Where-Object organization -EQ $Organization
    } else {
        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($RepoName)) {
            $Global:git_repos.Values | Where-Object name -Like $RepoName
        } else {
            if ($RepoName -eq '') {
                $gitStatus = Get-GitStatus
                if ($gitStatus) {
                    $RepoName = $GitStatus.RepoName
                } else {
                    'Not a git repo.'
                    return
                }
            } elseif ($RepoName -like '*/*') {
                $RepoName = ($RepoName -split '/')[1]
            }
            $global:git_repos[$RepoName]
        }
    }
}
#-------------------------------------------------------
function New-RepoData {
    $status = Get-GitStatus
    if ($status) {
        $currentRepo = [pscustomobject]@{
            id             = ''
            name           = $status.RepoName
            organization   = ''
            html_url       = ''
            host           = ''
            path           = $status.GitDir.Trim('\.git')
            remote         = $null
        }

        $remotes = @{ }
        & $gitcmd remote | ForEach-Object {
            $url = & $gitcmd remote get-url --all $_
            $remotes.Add($_, $url)
            if ($_ -in 'origin', 'upstream') {
                # Base settings on origin or upstream only
                # - organization, id,html_url, host
                # - last one (upstream) wins
                $uri = [uri]$url
                $currentRepo.organization = $uri.Segments[1].TrimEnd('/')
                $currentRepo.id = $currentRepo.organization + '/' + $status.RepoName
                $currentRepo.html_url = $url.Trim('.git$')
                switch -Regex ($url) {
                    '.*github.com.*|.*ghe.com.*' {
                        $currentRepo.host = 'github'
                    }
                    '.*visualstudio.com.*|.*dev.azure.com.*' {
                        $currentRepo.host = 'visualstudio'
                    }
                }
            }
        }
        $currentRepo.remote = [pscustomobject]$remotes
        $currentRepo
    } else {
        Write-Warning "Not a repo - $pwd"
    }
}
#-------------------------------------------------------
function Remove-RepoData {
    [CmdletBinding()]
    param(
        [string]$reponame
    )

    if ($null -eq $reponame) {
        $gitStatus = Get-GitStatus
        if ($gitStatus) {
            $reponame = $gitStatus.RepoName
        } else {
            'Not a git repo.'
            return
        }
    } elseif ($reponame -like '*/*') {
        $reponame = ($reponame -split '/')[1]
    }

    if ($global:git_repos.ContainsKey($reponame)) {
        Write-Verbose "Removing $reponame."
        $global:git_repos.Remove($reponame)
        Write-Verbose "Updating repo cache."
        $global:git_repos | Export-Clixml -Depth 10 -Path ~/repocache.clixml -Force
    } else {
        Write-Verbose "Repo $reponame not found."
    }
}
#-------------------------------------------------------
function Update-RepoData {
    param(
        [switch]$PassThru
    )
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
        $currentRepo = New-RepoData
        if ($global:git_repos.ContainsKey($currentRepo.name)) {
            $global:git_repos[$currentRepo.name] = $currentRepo
        } else {
            $global:git_repos.Add($currentRepo.name, $currentRepo)
        }
        Write-Verbose "Updating repo cache."
        $global:git_repos | Export-Clixml -Depth 10 -Path ~/repocache.clixml -Force
        if ($PassThru) {
            $global:git_repos[$currentRepo.name]
        }
    } else {
        'Not a git repo.'
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Repo management
#-------------------------------------------------------
function Get-DefaultBranch {
    $repo = Get-GitStatus
    if ($repo) {
        $remote = (git remote) -match 'upstream'
        if ($remote -eq '') { $remote = 'origin' }
        $default = git remote show $remote | Select-String -Pattern 'HEAD branch: (.+)'
        $default.Matches.Groups[1].Value
    } else {
        Write-Error 'Not a git repo.'
    }
}
#-------------------------------------------------------
function Get-GitRemote {
    $pattern = '(?<name>\w+)\s+(?<uri>[^\s]+)\s+\((?<mode>fetch|push)\)'
    $results = @{}
    foreach ($r in (& $gitcmd remote -v)) {
        if ($r -match $pattern) {
            $remote = [pscustomobject]@{
                remote = $Matches.name
                fetch  = $false
                push   = $false
                uri    = $Matches.uri
            }
            if ($results.ContainsKey($Matches.name)) {
                # Update existing entry
                if ($Matches.mode -eq 'fetch') {
                    $results[$Matches.name].fetch = $true
                }
                if ($Matches.mode -eq 'push') {
                    $results[$Matches.name].push = $true
                }
            } else {
                # Create new entry
                if ($Matches.mode -eq 'fetch') {
                    $remote.fetch = $true
                }
                if ($Matches.mode -eq 'push') {
                    $remote.push = $true
                }
                $results.Add($Matches.name, $remote)
            }
        }
    }
    $results.Values
}
#-------------------------------------------------------
function Set-LocationRepoRoot { Set-Location (Get-RepoData).path }
Set-Alias cdr Set-LocationRepoRoot
#-------------------------------------------------------
function Get-GitHubLabel {
    <#
    .SYNOPSIS
    Get GitHub labels for a repository.

    .PARAMETER Name
    The name of the label to retrieve. Supports wildcards.

    .PARAMETER RepoName
    The repository name in the format 'owner/repo'. Default is 'microsoftdocs/powershell-docs'.
    #>
    param(
        [SupportsWildcards()]
        [Parameter(Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        [string]$RepoName = 'microsoftdocs/powershell-docs'
    )

    $apiBase = "repos/$RepoName/labels"

    &{
        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name)) {
            Invoke-GitHubApi -Api $apiBase |
                Where-Object { $_.name -like ('*{0}*' -f $Name) }
        } elseif ($Name -ne '') {
            Invoke-GitHubApi -Api "$apiBase/$Name"
        } else {
            Invoke-GitHubApi -Api $apiBase
        }
    } | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName  = 'RepoLabelType'
            name        = $_.name
            color       = $_.color
            description = $_.description
        }
    }
}
#-------------------------------------------------------
function Add-GitHubLabel {
    [CmdletBinding(DefaultParameterSetName = 'byValues')]
    param(
        [Parameter(ParameterSetName = 'byValues')]
        [Parameter(ParameterSetName = 'byObject')]
        [string]$RepoName = 'microsoftdocs/powershell-docs',

        [Parameter(ParameterSetName = 'byValues')]
        [string]$Name,

        [Parameter(ParameterSetName = 'byValues')]
        [string]$Color,

        [Parameter(ParameterSetName = 'byValues')]
        [string]$Description,

        [Parameter(ParameterSetName = 'byObject')]
        [psobject]$Label
    )

    $api = "repos/$RepoName/labels"

    switch ($PSCmdlet.ParameterSetName) {
        'byValues' {
            $body = @{
                name        = $Name
                color       = $Color
                description = $Description
            } | ConvertTo-Json
            break
        }
        'byObject' {
            $body = $Label | ConvertTo-Json
            break
        }
    }

    Invoke-GitHubApi -Api $api -Method POST -Body $body |
        Select-Object name, color, description
}
#-------------------------------------------------------
function Remove-GitHubLabel {
    param(
        [string]$RepoName = 'microsoftdocs/powershell-docs',
        [string]$Name
    )

    $api = "repos/$RepoName/labels/$Name"

    Invoke-GitHubApi -Api $api -Method DELETE
}
#-------------------------------------------------------
function Set-GitHubLabel {
    [CmdletBinding(DefaultParameterSetName = 'byValues')]
    param(
        [Parameter(ParameterSetName = 'byValues')]
        [Parameter(ParameterSetName = 'byObject')]
        [string]$RepoName = 'microsoftdocs/powershell-docs',

        [Parameter(Mandatory, ParameterSetName = 'byValues', Position = 0)]
        [Parameter(ParameterSetName = 'byObject', Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'byValues', Position = 1)]
        [string]$NewName,

        [Parameter(ParameterSetName = 'byValues', Position = 2)]
        [string]$Color,

        [Parameter(ParameterSetName = 'byValues', Position = 3)]
        [string]$Description,

        [Parameter(Mandatory, ParameterSetName = 'byObject')]
        [psobject]$Label
    )

    $api = "repos/$RepoName/labels/$Name"

    switch ($PSCmdlet.ParameterSetName) {
        'byValues' {
            $body = @{
                name        = $NewName
                color       = $Color
                description = $Description
            } | ConvertTo-Json
            break
        }
        'byObject' {
            $body = $Label | ConvertTo-Json
            break
        }
    }

    Invoke-GitHubApi -Api $api -Method PATCH -Body $body |
        Select-Object name, color, description
}
#-------------------------------------------------------
function Import-GitHubLabel {
    [CmdletBinding()]
    param(
        [string]$RepoName,
        [string]$CsvPath
    )

    $oldLabels = Get-GitHubLabel $RepoName
    $newLabels = Import-Csv $CsvPath

    foreach ($label in $newLabels) {
        if ($oldLabels.name -contains $label.name) {
            Set-GitHubLabel -RepoName $RepoName -Name $label.name -Label $label
        } else {
            Add-GitHubLabel -RepoName $RepoName -Label $label
        }
    }
}
#-------------------------------------------------------
function Get-RepoStatus {
    param(
        [SupportsWildcards()]
        [string]$RepoName = '*'
    )
    Get-RepoData -RepoName $RepoName | ForEach-Object {
        Push-Location $_.path
        $current = & $gitcmd branch --show-current
        $default_branch = Get-DefaultBranch
        if ($current -eq $default_branch) {
            $default = '≡'
        }
        else {
            $default = 'working'
        }
        [pscustomobject]@{
            PSTypeName   = 'BranchStatusType'
            RepoName     = $_.name
            Status       = $default
            Default      = $default_branch
            Current      = $current
            GitStatus    = Write-VcsStatus
        }
        Pop-Location
    }
}
#-------------------------------------------------------
function Open-Repo {
    [CmdletBinding(DefaultParameterSetName = 'base')]
    param(
        [Parameter(Position = 0)]
        [string]$RepoName = '.',

        [switch]$Local,

        [Parameter(ParameterSetName = 'base')]
        [Parameter(ParameterSetName = 'forkissues', Mandatory)]
        [Parameter(ParameterSetName = 'forkpulls', Mandatory)]
        [switch]$Fork,

        [Parameter(ParameterSetName = 'forkissues', Mandatory)]
        [Parameter(ParameterSetName = 'baseissues', Mandatory)]
        [switch]$Issues,

        [Parameter(ParameterSetName = 'forkpulls', Mandatory)]
        [Parameter(ParameterSetName = 'basepulls', Mandatory)]
        [switch]$Pulls
    )

    if ($RepoName -eq '.') {
        $gitStatus = Get-GitStatus
        if ($gitStatus) {
            $RepoName = $gitStatus.RepoName
        }
    }
    $repo = $global:git_repos[($RepoName  -split '/')[-1]]

    if ($repo) {
        if ($Local) {
            Set-Location $repo.path
        } else {
            if ($Fork) {
                $url = $repo.remote.origin -replace '\.git$'
            }
            else {
                if ($repo.remote.upstream) {
                    $url = $repo.remote.upstream -replace '\.git$'
                } else {
                    $url = $repo.html_url
                }
            }
            if ($Issues) { $url += '/issues' }

            if ($Pulls) { $url += '/pulls' }

            Start-Process $url
        }
    } else {
        'Not a git repo.'
    }
}
Set-Alias goto Open-Repo
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Branch management
function Open-Branch {
    param([string]$Branch)

    $repo = Get-GitStatus
    if ($repo) {
        if ($Branch -eq '') {
            $repo = Get-GitStatus
            $Branch = Get-DefaultBranch
        }
        & $gitcmd checkout $Branch
    } else {
        Write-Error 'Not a git repo.'
    }
}
Set-Alias checkout Open-Branch
#-------------------------------------------------------
function Sync-Branch {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
        $repo = $global:git_repos[$gitStatus.RepoName]
        if ($gitStatus.HasIndex -or $gitStatus.HasUntracked) {
            Write-Host ('=' * 30) -Fore Magenta
            Write-Host ("Skipping  - $($gitStatus.Branch) has uncommitted changes.") -Fore Yellow
            Write-Host ('=' * 30) -Fore Magenta
        }
        else {
            Write-Host ('=' * 30) -Fore Magenta
            if ($repo.remote.upstream) {
                Write-Host '-----[pull upstream]----------' -Fore DarkCyan
                & $gitcmd pull upstream ($gitStatus.Branch)
                if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red }
                Write-Host '-----[push origin]------------' -Fore DarkCyan
                Write-Host ('-' * 30) -Fore DarkCyan
                & $gitcmd push origin ($gitStatus.Branch)
                if (!$?) { Write-Host 'Error pushing to origin' -Fore Red }
            }
            else {
                & $gitcmd pull origin ($gitStatus.Branch)
                if (!$?) { Write-Host 'Error pulling from origin' -Fore Red }
            }
        }
    }
    else {
        Write-Host ('=' * 30) -Fore Magenta
        Write-Host "Skipping $pwd - not a repo." -Fore Yellow
        Write-Host ('=' * 30) -Fore Magenta
    }
}
#-------------------------------------------------------
function Sync-Repo {
    param([switch]$Origin)

    $gitStatus = Get-GitStatus
    if ($null -eq $gitStatus) {
        Write-Host ('=' * 30) -Fore Magenta
        Write-Host "Skipping $pwd - not a repo." -Fore Red
        Write-Host ('=' * 30) -Fore Magenta
    } else {
        $RepoName = $gitStatus.RepoName
        $repo = $global:git_repos[$RepoName]
        $default_branch = Get-DefaultBranch
        Write-Host ('=' * 30) -Fore Magenta
        Write-Host $repo.id  -Fore Magenta
        Write-Host ('=' * 30) -Fore Magenta

        $onlyMain = @('azure-docs-pr','learn-pr', 'entra-powershell','entra-powershell-docs-pr',
        'azure-cli','azure-powershell')

        if ($RepoName -in $onlyMain) {
            Write-Host '-----[fetch upstream main]----' -Fore DarkCyan
            & $gitcmd  fetch upstream $default_branch --jobs=10
            Write-Host '-----[fetch origin --prune]----' -Fore DarkCyan
            & $gitcmd  fetch origin --prune --jobs=10
        } else {
            Write-Host '-----[fetch --all --prune]----' -Fore DarkCyan
            & $gitcmd fetch --all --prune --jobs=10
        }
        if (!$?) {
            Write-Host 'Error fetching from remotes' -Fore Red
            $global:SyncAllErrors += "$RepoName - Error fetching from remotes"
        }

        if ($Origin) {
            Write-Host ('Syncing {0}' -f $gitStatus.Upstream) -Fore Magenta
            Write-Host '-----[pull origin]------------' -Fore DarkCyan
            & $gitcmd pull origin $gitStatus.Branch
            if (!$?) {
                Write-Host 'Error pulling from origin' -Fore Red
                $global:SyncAllErrors += "$RepoName - Error pulling from origin"
            }
            Write-Host ('=' * 30) -Fore Magenta
        } else { # else not $Origin
            if ($gitStatus.Branch -ne $default_branch) {
                Write-Host ('=' * 30) -Fore Magenta
                Write-Host "Skipping $pwd - default branch not checked out." -Fore Yellow
                $global:SyncAllErrors += "$RepoName - Skipping $pwd - default branch not checked out."
                Write-Host ('=' * 30) -Fore Magenta
            } else { # else default branch
                Write-Host ('Syncing {0}' -f $default_branch) -Fore Magenta
                if ($repo.remote.upstream) {
                    Write-Host '-----[rebase upstream]----------' -Fore DarkCyan
                    & $gitcmd rebase upstream/$($default_branch)
                    if (!$?) {
                        Write-Host 'Error rebasing from upstream' -Fore Red
                        $global:SyncAllErrors += "$RepoName - Error rebasing from upstream."
                    }
                    if ($repo.remote.upstream -eq $repo.remote.origin) {
                        Write-Host '-----[fetch origin]-----------' -Fore DarkCyan
                        & $gitcmd fetch origin --jobs=10
                        if (!$?) {
                            Write-Host 'Error fetching from origin' -Fore Red
                            $global:SyncAllErrors += "$RepoName - Error fetching from origin."
                        }
                    } else { # else upstream different from origin
                        Write-Host '-----[push origin --force]------------' -Fore DarkCyan
                        & $gitcmd push origin ($default_branch) --force-with-lease
                        if (!$?) {
                            Write-Host 'Error pushing to origin' -Fore Red
                            $global:SyncAllErrors += "$RepoName - Error pushing to origin."
                        }
                    }
                } else { # else no upstream
                    Write-Host ('=' * 30) -Fore Magenta
                    Write-Host 'No upstream defined' -Fore Yellow
                    Write-Host '-----[pull origin]------------' -Fore DarkCyan
                    & $gitcmd pull origin ($default_branch)
                    if (!$?) {
                        Write-Host 'Error pulling from origin' -Fore Red
                        $global:SyncAllErrors += "$RepoName - Error pulling from origin."
                    }
                }
            }
        }
    }
}
#-------------------------------------------------------
function Sync-AllRepos {
    param(
        [switch]$Origin
    )

    $startLocation = $PWD
    $originalDirs = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        if ($_.Root -like "$($_.Name)*") {join-path $_.Root $_.CurrentLocation}
    }

    $global:SyncAllErrors = @()
    $repoFolders = Find-GitRepo

    foreach ($folder in $repoFolders) {
        Push-Location $folder
        Sync-Repo -Origin:$Origin
        Pop-Location
    }
    $originalDirs | Set-Location
    Set-Location $startLocation
    Write-Host ('=' * 30) -Fore Magenta
    $global:SyncAllErrors
}
Set-Alias syncall Sync-AllRepos
#-------------------------------------------------------
function Remove-Branch {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$branch
    )
    process {
        if ($branch) {
            $allbranches = @()
            $branch | ForEach-Object {
                $allbranches += & $gitcmd branch -l $_
            }
            Write-Host ("Deleting branches:`r`n" + ($allbranches -join "`r`n"))
            $allbranches | ForEach-Object {
                $b = $_.Trim()
                '---' * 3
                & $gitcmd push origin --delete $b
                '---'
                & $gitcmd branch -D $b
                #& $gitcmd branch -Dr origin/$b
            }
        }
    }
}
Set-Alias -Name rmbr -Value Remove-Branch
function Get-BranchInfo {
    $remotePattern = '^branch\.(?<branch>.+)\.remote\s(?<remote>.*)$'
    $branchPattern = '[\s*\*]+(?<branch>[^\s]*)\s*(?<sha>[^\s]*)\s(?<message>.*)'
    $remotes = & $gitcmd config --get-regex '^branch\..*\.remote' |
        ForEach-Object {
            if ($_ -match $remotePattern) { $Matches | Select-Object branch,remote }
        }
    $branches = & $gitcmd branch -vl | ForEach-Object {
        if ($_ -match $branchPattern) {
            $Matches | Select-Object branch, @{n='remote';e={''}}, sha, message
        }
    }
    foreach ($r in $remotes) {
        $exist = $false
        foreach ($b in $branches) {
            if ($b.branch -eq $r.branch) {
                $b.remote = $r.remote
                $exist = $true
            }
        }
        if (! $exist) {
            $branches += $r | Select-Object branch, @{n='remote';e={''}}, sha, message
        }
    }
    $branches
}
#-------------------------------------------------------
function Get-GitMergeBase {
    param (
        [string]$defaultBranch = (Get-DefaultBranch)
    )
    $branchName = & $gitcmd branch --show-current
    & $gitcmd merge-base $defaultBranch $branchName
}
#-------------------------------------------------------
function Get-BranchDiff {
    <#
    .SYNOPSIS
    Get the list of files that differ between the current branch and the specified base branch.

    .PARAMETER BaseBranch
    The base branch to compare against. Defaults to the repository's default branch.
    #>
    param (
        [string]$BaseBranch = (Get-DefaultBranch)
    )

    $branchName = & $gitcmd branch --show-current
    $params = @('diff', '--name-only',
        "$($branchName)..$(Get-GitMergeBase -defaultBranch $BaseBranch)")
    $diffs = & $gitcmd @params
    if ($diffs.count -eq 1) {
        Write-Output (, $diffs)
    } else {
        $diffs
    }
}
#-------------------------------------------------------
function Get-LastCommit {
    & $gitcmd log -n 1 --pretty='format:%s'
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Git PR management
function Get-PrFiles {
    param(
        [int32]$num,
        [string]$repo = 'MicrosoftDocs/PowerShell-Docs'
    )
    $hdr = @{
        Accept        = 'application/vnd.github.VERSION.full+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }

    $pr = Invoke-RestMethod "https://api.github.com/repos/$repo/pulls/$num" -Method GET -head $hdr -FollowRelLink
    $pages = Invoke-RestMethod $pr.commits_url -head $hdr
    foreach ($commits in $pages) {
        $commits | ForEach-Object {
            $commitpages = Invoke-RestMethod $_.url -head $hdr -FollowRelLink
            foreach ($commit in $commitpages) {
                $commit.files | Select-Object status, changes, filename, previous_filename
            }
        } | Sort-Object status, filename -Unique
    }
}
#-------------------------------------------------------
function Get-PrMerger {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $RepoName
    )

    if (-not $Verbose) {$Verbose = $false}

    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $query = "q=type:pr+is:merged+repo:$RepoName"

    $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr
    foreach ($pr in $prlist.items) {
        $prevent = (Invoke-RestMethod $pr.events_url -Headers $hdr) | Where-Object event -EQ merged
        [pscustomobject]@{
            number     = $pr.number
            state      = $pr.state
            event      = $prevent.event
            created_at = Get-Date $prevent.created_at -f 'yyyy-MM-dd'
            merged_by  = $prevent.actor.login
            title      = $pr.title
        }
    }
}
#-------------------------------------------------------
function New-MergeToLive {
    param(
        $repo = (Get-RepoData)
    )
    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$($repo.id)/pulls"
    $default_branch = Get-DefaultBranch
    $params = @{
        title = 'Publish to live'
        body  = 'Publishing latest changes to live'
        head  = $default_branch
        base  = 'live'
    }
    $body = $params | ConvertTo-Json
    try {
        $i = Invoke-RestMethod $apiurl -head $hdr -Method POST -Body $body
        Start-Process $i.html_url
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        $e = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object -exp errors
        Write-Error $e.message
        $error.Clear()
    }
}
#-------------------------------------------------------
function New-PrFromBranch {
    [CmdletBinding()]
    param (
        $workitemid,
        $issue,
        $title
    )

    if (-not $Verbose) {$Verbose = $false}

    $repo = (Get-RepoData)
    $hdr = @{
        Accept        = 'application/vnd.github.raw+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$($repo.id)/pulls"

    switch ($repo.name) {
        'PowerShell-Docs' {
            $repoPath = $repo.path
            $template = Get-Content $repoPath\.github\PULL_REQUEST_TEMPLATE.md
        }
    }

    # build comment to be added to body
    $comment = "$title`r`n`r`n"
    $prtitle = "$title"

    if ($null -ne $workitemid) {
        $comment += "- Fixes AB#$workitemid`r`n"
    }
    if ($null -ne $issue) {
        $comment += "- Fixes #$issue`r`n"
        $prtitle = "Fixes #$issue - $prtitle"
    }

    $currentbranch = & $gitcmd branch --show-current
    $defaultbranch = Get-DefaultBranch

    # Only process template if it exists
    if ($null -ne $template) {
        # check all boxes in the checklist
        21..24 | ForEach-Object {
            $template[$_] = $template[$_] -replace [regex]::Escape('[ ]'), '[x]'
        }

        $template[11] = $comment
        $comment = $template -join "`r`n"
    }

    $body = @{
        title = $prtitle
        body  = $comment
        head  = "${env:GITHUB_USER}:$currentbranch"
        base  = $defaultbranch
    } | ConvertTo-Json

    Write-Verbose $body

    try {
        $i = Invoke-RestMethod $apiurl -head $hdr -Method POST -Body $body
        Start-Process $i.html_url
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        $e = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object -exp errors
        Write-Error $e.message
        $error.Clear()
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Git Issue management
function Get-Issue {
    <#
    .SYNOPSIS
    Get a GitHub issue by number or URL.

    .PARAMETER IssueNumber
    The issue number to retrieve.

    .PARAMETER RepoName
    The repository name in the format 'owner/repo'. Defaults to the current repository.

    .PARAMETER Url
    The full URL of the issue to retrieve.

    .PARAMETER List
    If specified, lists all issues in the repository instead of a single issue.
    #>
    param(
        [Parameter(ParameterSetName = 'ByIssueNum')]
        [string]$RepoName = (Get-RepoData).id,

        [Parameter(ParameterSetName = 'ByUri', Mandatory)]
        [uri]$Url,

        [Parameter(ParameterSetName = 'List', Mandatory)]
        [switch]$List
    )

    if ($null -ne $Url) {
        $RepoName = ($Url.Segments[1..2] -join '').trim('/')
        $IssueNumber = $Url.Segments[4]
    }

    $apiBase = "repos/$RepoName/issues"

    if ($List) {
        $results = Invoke-GitHubApi -Api $apiBase
        foreach ($issuelist in $results) {
            foreach ($issue in $issuelist) {
                if ($null -eq $issue.pull_request) {
                    [pscustomobject]@{
                        number    = $issue.number
                        assignee  = $issue.assignee.login
                        labels    = $issue.labels.name -join ','
                        milestone = $issue.milestone.title
                        title     = $issue.title
                        html_url  = $issue.html_url
                        url       = $issue.url
                    }
                }
            }
        }
    } else {
        $apiurl = "$apiBase/$IssueNumber"
        $issue = Invoke-GitHubApi -Api $apiurl
        $apiurl += "/comments"
        $comments = Invoke-GitHubApi -Api $apiurl -Headers $hdr |
            Select-Object -ExpandProperty body
            [pscustomobject]@{
                title      = $issue.title
                url        = $issue.html_url
                name       = $RepoName + '#' + $issue.number
                created_at = $issue.created_at
                state      = $issue.state
                number     = $issue.number
                assignee   = $issue.assignee.login
                labels     = $issue.labels.name
                body       = $issue.body
                comments   = $comments -join "`n"
            }
    }
}
#-------------------------------------------------------
function Close-Issue {
    <#
    .SYNOPSIS
    Close a GitHub issue.

    .PARAMETER IssueNumber
    The issue number to close.

    .PARAMETER Comment
    A comment to add when closing the issue. Default is 'Closing issue.'.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.

    .PARAMETER Spam
    If set, marks the issue as spam and adds a standard comment.

    .PARAMETER Duplicate
    The number of the issue that _IssueNumber_ duplicates. The command creates adds
    a standard comment that links to the duplicated issue.
    #>
    param(
        [CmdletBinding(DefaultParameterSetName = 'Close')]

        [Parameter(Mandatory, ParameterSetName = 'Close', Position=0)]
        [Parameter(Mandatory, ParameterSetName = 'Spam', Position=0)]
        [Parameter(Mandatory, ParameterSetName = 'Duplicate', Position=0)]
        [uint[]]$IssueNumber,

        [Parameter(ParameterSetName = 'Close', Position=1)]
        [string]$Comment,

        [Parameter(ParameterSetName = 'Close')]
        [Parameter(ParameterSetName = 'Spam')]
        [Parameter(ParameterSetName = 'Duplicate')]
        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs',

        [Parameter(Mandatory, ParameterSetName = 'Spam')]
        [switch]$Spam,

        [Parameter(Mandatory, ParameterSetName = 'Duplicate')]
        [uint32]$Duplicate
    )

    begin {
        if ($Spam) {
            $Comment = @'
This is not actionable feedback and violates our code of conduct.

The [Code of Conduct][coc], which outlines the expectations for community interactions with learn.microsoft.com, is designed to help provide a welcoming and inspiring community for all.

[coc]: https://opensource.microsoft.com/codeofconduct/
'@
        }
        if ($Duplicate) {
            $Comment = "This issue is a duplicate of #$Duplicate. Please refer to that issue for further updates."
        }
        if ($Comment -eq '') {
            $Comment = 'Closing issue.'
        }
    }

    end {
        foreach ($i in $IssueNumber) {
            $null = Add-IssueComment -IssueNumber $i -Comment $Comment -RepoName $RepoName
            $body = @{
                state        = 'closed'
                state_reason = 'completed'
            }
            if ($Spam) {
                $body.state_reason = 'not_planned'
                $null = Set-IssueLabel -IssueNumber $i -LabelName 'code-of-conduct' -RepoName $RepoName
            }
            if ($Duplicate) {
                $body.state_reason = 'duplicate'
                $null = Set-IssueLabel -IssueNumber $i -LabelName 'duplicate' -RepoName $RepoName
            }
            $json = $body | ConvertTo-Json
            Write-Verbose "Closing issue $i in $RepoName"
            Write-Verbose $json

            Invoke-GitHubApi -api repos/$RepoName/issues/$i -method PATCH -Body $json |
                Select-Object url, state, state_reason, closed_at
        }
    }
}
#-------------------------------------------------------
function New-Issue {
    <#
    .SYNOPSIS
    Create a new GitHub issue.

    .PARAMETER Title
    The title of the issue.

    .PARAMETER Description
    The description of the issue.

    .PARAMETER LabelName
    The labels to apply to the issue.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [string[]]$LabelName,

        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs'
    )
    $body = @{
        'title' = $Title
        'body'  = $Description
    }
    if ($LabelName) {
        $body.Add('labels', $LabelName)
    }
    $body = $body | ConvertTo-Json
    Invoke-GitHubApi -api repos/$RepoName/issues -method POST -Body $body |
        Select-Object @{n = 'repo'; e = { $RepoName } }, number, created_at, title, body
}
#-------------------------------------------------------
function Add-IssueComment {
    <#
    .SYNOPSIS
    Add a comment to a GitHub issue.

    .PARAMETER IssueNumber
    The issue number to add a comment to.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.
    #>
    param(
        [Parameter(Mandatory)]
        [UInt32]$IssueNumber,

        [Parameter(Mandatory)]
        [string]$Comment,

        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs'
    )
    $body = @{'body' = $Comment } | ConvertTo-Json
    Invoke-GitHubApi -api repos/$RepoName/issues/$IssueNumber/comments -method POST -Body $body |
        Select-Object @{n = 'repo'; e = { $RepoName } }, @{n = 'issue'; e = { $IssueNumber } },
        created_at, body
}
#-------------------------------------------------------
function Add-IssueLabel {
    <#
    .SYNOPSIS
    Add labels to a GitHub issue.

    .PARAMETER IssueNumber
    The issue number to add labels to.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.

    .PARAMETER LabelName
    The labels to add to the issue.
    #>
    param(
        [UInt32]$IssueNumber,
        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs',
        [string[]]$LabelName
    )
    $body = @{'labels' = $LabelName } | ConvertTo-Json
    Invoke-GitHubApi -api repos/$RepoName/issues/$IssueNumber/labels -method POST -Body $body |
        Select-Object @{n = 'repo'; e = { $RepoName } }, @{n = 'issue'; e = { $IssueNumber } },
        name, color, description
}
#-------------------------------------------------------
function Get-IssueLabel {
    <#
    .SYNOPSIS
    Get the labels for a GitHub issue.

    .PARAMETER IssueNumber
    The issue number to get labels for.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.
    #>
    param(
        [Parameter(Mandatory)]
        [UInt32]$IssueNumber,
        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs'
    )
    Invoke-GitHubApi -api repos/$RepoName/issues/$IssueNumber/labels |
        Select-Object @{n = 'repo'; e = { $RepoName } }, @{n = 'issue'; e = { $IssueNumber } },
        name, color, description
}
#-------------------------------------------------------
function Remove-IssueLabel {
    <#
    .SYNOPSIS
    Remove labels from a GitHub issue.

    .PARAMETER IssueNumber
    The issue number to remove labels from.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.

    .PARAMETER LabelName
    The label to remove from the issue. If not specified, all labels are removed.
    #>
    param(
        [UInt32]$IssueNumber,
        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs',
        [string]$LabelName
    )
    $uri = "repos/$RepoName/issues/$IssueNumber/labels"
    if ($LabelName) {
        $uri += "/$LabelName"
    }
    Invoke-GitHubApi -api $uri -method DELETE |
        Select-Object @{n = 'repo'; e = { $RepoName } }, @{n = 'issue'; e = { $IssueNumber } },
        name, color, description
}
#-------------------------------------------------------
function Set-IssueLabel {
    <#
    .SYNOPSIS
    Set (replace) labels on a GitHub issue.

    .PARAMETER IssueNumber
    The issue number to set labels for.

    .PARAMETER RepoName
    The repository name (owner/repo). Default is 'MicrosoftDocs/PowerShell-Docs'.
    #>

    param(
        [UInt32]$IssueNumber,
        [string]$RepoName = 'MicrosoftDocs/PowerShell-Docs',
        [string[]]$LabelName
    )
    $body = @{'labels' = $LabelName } | ConvertTo-Json
    Invoke-GitHubApi -api repos/$RepoName/issues/$IssueNumber/labels -method PUT -Body $body |
        Select-Object @{n = 'repo'; e = { $RepoName } }, @{n = 'issue'; e = { $IssueNumber } },
        name, color, description
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region AzDO actions
$global:DevOpsParentIds = @{
    NoParentId = 0
    ContentMaintenance = 4154
    GitHubIssues = 4155
    SearchRescue = 4043
    Crescendo = 4151
    SecretManagement = 4084
    PSScriptAnalyzer = 4161
    PlatyPS = 4063
    PS73Docs = 4087
    OpenSSH = 4065
    SDKAPI = 4147
    PSReadLine = 4160
    ShellExperience = 4053
}
#-------------------------------------------------------
function Get-DevOpsGitHubConnections {
    $username = ' '
    $password = ConvertTo-SecureString $env:CLDEVOPS_TOKEN -AsPlainText -Force
    # The token must have READ permissions for GitHub Connections
    $baseUri = 'https://dev.azure.com/msft-skilling/Content/_apis'
    $params = @{
        uri            = "$baseUri/githubconnections?api-version=7.2-preview.1"
        Authentication = 'Basic'
        Credential     = [PSCredential]::new($username, $password)
        Method         = 'Get'
        ContentType    = 'application/json-patch+json'
    }
    $result = Invoke-RestMethod @params

    $connections = $result.value | Select-Object id,
        @{n='Owner';e={$_.createdBy.displayName}},
        @{n='Upn';e={$_.createdBy.uniqueName}}

    foreach ($c in $connections) {
        $params.uri = "$baseUri/githubconnections/$($c.id)/repos?api-version=7.2-preview.1"
        $result = Invoke-RestMethod @params
        $addMemberSplat = @{
            MemberType = 'NoteProperty'
            Name = 'Repos'
            Value = ($result.value.gitHubRepositoryUrl  -replace 'https://github.com/')
        }
        $c | Add-Member @addMemberSplat
    }
    $connections
}
#-------------------------------------------------------
function Get-DevOpsWorkItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$id
    )

    if (-not $Verbose) {$Verbose = $false}

    $username = ' '
    $password = ConvertTo-SecureString $env:CLDEVOPS_TOKEN -AsPlainText -Force
    $cred = [PSCredential]::new($username, $password)

    $vsuri = 'https://dev.azure.com'
    $org = 'msft-skilling'
    $project = 'Content'
    $apiurl = "$vsuri/$org/$project/_apis/wit/workitems/" + $id + '?$expand=all&api-version=7.0-preview.3'

    $params = @{
        uri            = $apiurl
        Authentication = 'Basic'
        Credential     = $cred
        Method         = 'Get'
        ContentType    = 'application/json-patch+json'
    }
    #$params
    $results = Invoke-RestMethod @params

    $results |
        Select-Object @{l = 'Id'; e = { $_.Id } },
        @{l = 'State'; e = { $_.fields.'System.State' } },
        @{l = 'Parent'; e = { $_.fields.'System.Parent' } },
        @{l = 'AssignedTo'; e = { $_.fields.'System.AssignedTo'.displayName } },
        @{l = 'AreaPath'; e = { $_.fields.'System.AreaPath' } },
        @{l = 'IterationPath'; e = { $_.fields.'System.IterationPath' } },
        @{l = 'Type'; e = { $_.fields.'System.WorkItemType' } },
        @{l = 'Title'; e = { $_.fields.'System.Title' } },
        @{l = 'Description'; e = { $_.fields.'System.Description' } },
        @{l = 'Fields'; e = { $_.fields } }
}
#-------------------------------------------------------
function New-DevOpsWorkItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Description,

        [Int32]$ParentId,

        [string[]]$Tags,

        [ValidateSet('Bug', 'Task', 'User%20Story', 'Backlog%20Work', 'Feature', 'Epic')]
        [string]$WorkItemType,

        [string]$AreaPath = (GetAreaPaths)[1],

        [string]$IterationPath = (GetIterationPaths -Current).path,

        [ArgumentCompletions('sewhee', 'mlombardi', 'mirobb', 'jahelmic')]
        [string]$Assignee = 'sewhee'
    )

    if (-not $Verbose) {$Verbose = $false}

    $username = ' '
    $password = ConvertTo-SecureString $env:CLDEVOPS_TOKEN -AsPlainText -Force
    $cred = [PSCredential]::new($username, $password)

    $vsuri = 'https://dev.azure.com'
    $org = 'msft-skilling'
    $project = 'Content'
    $apiurl = "$vsuri/$org/$project/_apis/wit/workitems/$" + $WorkItemType + '?api-version=7.0-preview.3'

    $widata = [System.Collections.Generic.List[psobject]]::new()

    $field = [pscustomobject]@{
        op    = 'add'
        path  = '/fields/System.Title'
        value = $Title
    }
    $widata.Add($field)

    $field = [pscustomobject]@{
        op    = 'add'
        path  = '/fields/System.AreaPath'
        value = $AreaPath
    }
    $widata.Add($field)

    $field = [pscustomobject]@{
        op    = 'add'
        path  = '/fields/System.IterationPath'
        value = $IterationPath
    }
    $widata.Add($field)

    switch ($parentId.GetType().Name) {
        'Int32' {
            $parentIdValue = $ParentId
        }
        'String' {
            $parentIdValue = $global:DevOpsParentIds[$ParentId]
        }
        default {
            throw "Parameter parentid - Invalid argument type."
        }
    }

    if ($parentIdValue -ne 0) {
        $field = [pscustomobject]@{
            op    = 'add'
            path  = '/relations/-'
            value = @{
                rel = 'System.LinkTypes.Hierarchy-Reverse'
                url = "$vsuri/$org/$project/_apis/wit/workitems/$($parentIdValue)"
            }
        }
        $widata.Add($field)
    }

    if ($tags.count -ne 0) {
        $field = [pscustomobject]@{
            op    = 'add'
            path  = '/fields/System.Tags'
            value = $tags -join '; '
        }
        $widata.Add($field)
    }

    $field = [pscustomobject]@{
        op    = 'add'
        path  = '/fields/System.AssignedTo'
        value = $assignee + '@microsoft.com'
    }
    $widata.Add($field)

    $field = [pscustomobject]@{
        op    = 'add'
        path  = '/fields/System.Description'
        value = $description
    }
    $widata.Add($field)

    $query = ConvertTo-Json $widata

    $params = @{
        uri            = $apiurl
        Authentication = 'Basic'
        Credential     = $cred
        Method         = 'Post'
        ContentType    = 'application/json-patch+json'
        Body           = $query
    }
    Write-Verbose ([pscustomobject]$params)
    $results = Invoke-RestMethod @params

    $results |
        Select-Object @{l = 'Id'; e = { $_.Id } },
        @{l = 'State'; e = { $_.fields.'System.State' } },
        @{l = 'Parent'; e = { $_.fields.'System.Parent' } },
        @{l = 'AssignedTo'; e = { $_.fields.'System.AssignedTo'.displayName } },
        @{l = 'AreaPath'; e = { $_.fields.'System.AreaPath' } },
        @{l = 'IterationPath'; e = { $_.fields.'System.IterationPath' } },
        @{l = 'Title'; e = { $_.fields.'System.Title' } },
        @{l = 'AttachedFiles'; e = { $_.fields.'System.AttachedFileCount' } },
        @{l = 'ExternalLinks'; e = { $_.fields.'System.ExternalLinkCount' } },
        @{l = 'HyperLinks'; e = { $_.fields.'System.HyperLinkCount' } },
        @{l = 'Reason'; e = { $_.fields.'System.Reason' } },
        @{l = 'RelatedLinks'; e = { $_.fields.'System.RelatedLinkCount' } },
        @{l = 'RemoteLinks'; e = { $_.fields.'System.RemoteLinkCount' } },
        @{l = 'Tags'; e = { $_.fields.'System.Tags' } },
        @{l = 'Description'; e = { $_.fields.'System.Description' } }
}
#-------------------------------------------------------
function Update-DevOpsWorkItem {
    [CmdletBinding(DefaultParameterSetName='ByIdOnly')]
    param(
        [Parameter(Mandatory, Position=0, ParameterSetName='ByIdOnly')]
        [Parameter(Mandatory, Position=0, ParameterSetName='WithIssue')]
        [Int32]$Id,

        [Parameter(Mandatory, Position=1, ParameterSetName='WithIssue')]
        [int32]$IssueId,

        [Parameter(ParameterSetName='WithIssue')]
        [string]$RepoName = (Get-RepoData).id,

        [Parameter(ParameterSetName='ByIdOnly')]
        [string]$Title,

        [Parameter(ParameterSetName='ByIdOnly')]
        [string]$Description,

        [Int32]$ParentId,

        [string[]]$Tags,

        [string]$AreaPath = (GetAreaPaths)[1],

        [string]$IterationPath = (GetIterationPaths -Current).path,

        [ArgumentCompletions('sewhee', 'mlombardi', 'mirobb', 'jahelmic')]
        [string]$Assignee = 'sewhee'
    )

    if (-not $Verbose) {$Verbose = $false}

    $username = ' '
    $password = ConvertTo-SecureString $env:CLDEVOPS_TOKEN -AsPlainText -Force
    $cred = [PSCredential]::new($username, $password)

    $vsuri = 'https://dev.azure.com'
    $org = 'msft-skilling'
    $project = 'Content'
    $apiurl = "$vsuri/$org/$project/_apis/wit/workitems/$Id" + '?$expand=all&api-version=7.0'

    ## Get the work item
    $params = @{
        uri            = $apiurl
        Authentication = 'Basic'
        Credential     = $cred
        Method         = 'GET'
        ContentType    = 'application/json'
    }

    Write-Verbose ('-' * 40)
    Write-Verbose ([pscustomobject]$params)
    Write-Verbose ('-' * 40)
    $wiresult = Invoke-RestMethod @params
    Write-Verbose ('-' * 40)
    Write-Verbose ($wiresult)
    Write-Verbose ('-' * 40)

    if ($null -eq $wiresult) {
        throw "Work item $Id not found."
    }

    if ($wiresult.fields.'System.State' -eq 'Closed') {
        throw "Work item $Id is closed. Cannot update."
    }

    $newComment = "$($wiresult.fields.'System.Title')" #+ "$($wiresult.fields.'System.Description')"

    ## Get the issue
    Write-Verbose ('-' * 40)
    Write-Verbose "Getting issue $IssueId"
    Write-Verbose ('-' * 40)
    $issueUrl = "https://github.com/$RepoName/issues/$IssueId"
    $issue = Get-Issue -Url $issueUrl -RepoName $RepoName
    if ($null -eq $issue) {
        throw "Issue $IssueId not found."
    } else {
        $global:prcmd = 'New-PrFromBranch -work {0} -issue {1} -title (Get-LastCommit)' -f $Id, $issue.number
        $Title = '[GH#{0}] - {1}' -f $issue.number, $issue.title
        $Description = "Issue: <a href='{0}'>{1}</a><BR>" -f $issue.url, $issue.name
        $Description += 'Created: {0}<BR>' -f $issue.created_at
        $Description += 'Labels: {0}<BR>' -f ($issue.labels -join ',')
        if ($issue.body -match 'Content Source: \[(.+)\]') {
            $Description += 'Document: {0}<BR>' -f $matches[1]
        }
    }

    ## Copy the existing Title and Description to a new comment
    if ($Title -and $Description) {
        $apiurl = "$vsuri/$org/$project/_apis/wit/workitems/$Id/comments?api-version=6.0-preview.3"
        $json = @{
            text = $newComment
        } | ConvertTo-Json
        $params = @{
            uri            = $apiurl
            Authentication = 'Basic'
            Credential     = $cred
            Method         = 'POST'
            Body           = $json
            ContentType    = 'application/json-patch+json'
        }

        Write-Verbose ('-' * 40)
        Write-Verbose ([pscustomobject]$params)
        Write-Verbose ('-' * 40)
        $commentresult = Invoke-RestMethod @params
        Write-Verbose ('-' * 40)
        Write-Verbose $commentresult.text
        Write-Verbose ('-' * 40)
    }

    $widata = [System.Collections.Generic.List[psobject]]::new()

    if ($null -ne $Title) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/fields/System.Title'
            value = $Title
        }
        $widata.Add($field)
    }

    if ($null -ne $Description) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/fields/System.Description'
            value = $Description
        }
        $widata.Add($field)
    }

    if ($null -ne $Tags) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/fields/System.Tags'
            value = $Tags -join '; '
        }
        $widata.Add($field)
    }

    if ($null -ne $AreaPath) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/fields/System.AreaPath'
            value = $AreaPath
        }
        $widata.Add($field)
    }

    if ($null -ne $IterationPath) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/fields/System.IterationPath'
            value = $IterationPath
        }
        $widata.Add($field)
    }

    switch ($parentId.GetType().Name) {
        'Int32' {
            $parentIdValue = $ParentId
        }
        'String' {
            $parentIdValue = $global:DevOpsParentIds[$ParentId]
        }
        default {
            throw "Parameter parentid - Invalid argument type."
        }
    }

    if ($parentIdValue -ne 0) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/relations/-'
            value = @{
                rel = 'System.LinkTypes.Hierarchy-Reverse'
                url = "$vsuri/$org/$project/_apis/wit/workitems/$($parentIdValue)"
            }
        }
        $widata.Add($field)
    }

    if ($null -ne $assignee) {
        $field = [pscustomobject]@{
            op    = 'replace'
            path  = '/fields/System.AssignedTo'
            value = $assignee + '@microsoft.com'
        }
        $widata.Add($field)
    }

    $query = ConvertTo-Json $widata

    $params = @{
        uri            = "$vsuri/$org/$project/_apis/wit/workitems/$Id" + '?$expand=all&api-version=7.0'
        Authentication = 'Basic'
        Credential     = $cred
        Method         = 'patch'
        ContentType    = 'application/json-patch+json'
        Body           = $query
    }

    ## Update the work item
    Write-Verbose ('-' * 40)
    Write-Verbose ([pscustomobject]$params)
    Write-Verbose ('-' * 40)
    $updateresult = Invoke-RestMethod @params

    $updateresult |
        Select-Object @{l = 'Id'; e = { $_.Id } },
        @{l = 'State'; e = { $_.fields.'System.State' } },
        @{l = 'Parent'; e = { $_.fields.'System.Parent' } },
        @{l = 'AssignedTo'; e = { $_.fields.'System.AssignedTo'.displayName } },
        @{l = 'AreaPath'; e = { $_.fields.'System.AreaPath' } },
        @{l = 'IterationPath'; e = { $_.fields.'System.IterationPath' } },
        @{l = 'Title'; e = { $_.fields.'System.Title' } },
        @{l = 'AttachedFiles'; e = { $_.fields.'System.AttachedFileCount' } },
        @{l = 'ExternalLinks'; e = { $_.fields.'System.ExternalLinkCount' } },
        @{l = 'HyperLinks'; e = { $_.fields.'System.HyperLinkCount' } },
        @{l = 'Reason'; e = { $_.fields.'System.Reason' } },
        @{l = 'RelatedLinks'; e = { $_.fields.'System.RelatedLinkCount' } },
        @{l = 'RemoteLinks'; e = { $_.fields.'System.RemoteLinkCount' } },
        @{l = 'Tags'; e = { $_.fields.'System.Tags' } },
        @{l = 'Description'; e = { $_.fields.'System.Description' } }

    Write-Host $prcmd
}
#-------------------------------------------------------
function Import-GHIssueToDevOps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$IssueUrl,

        [string]$AreaPath = (GetAreaPaths)[1],

        [string]$IterationPath = (GetIterationPaths -Current).path,

        [ArgumentCompletions('sewhee', 'mlombardi', 'mirobb', 'jahelmic')]
        [string]$Assignee = 'sewhee'
    )

    if (-not $Verbose) {$Verbose = $false}

    $issue = Get-Issue -Url $IssueUrl
    $description = "Issue: <a href='{0}'>{1}</a><BR>" -f $issue.url, $issue.name
    $description += 'Created: {0}<BR>' -f $issue.created_at
    $description += 'Labels: {0}<BR>' -f ($issue.labels -join ',')
    if ($issue.body -match 'Content Source: \[(.+)\]') {
        $description += 'Document: {0}<BR>' -f $matches[1]
    }

    $wiParams = @{
        Title         = $issue.title
        Description   = $description
        ParentId      = $DevOpsParentIds.GitHubIssues
        AreaPath      = $AreaPath
        IterationPath = $IterationPath
        WorkItemType  = 'Task'
        Assignee      = $Assignee
    }
    Write-Verbose ($wiParams | Out-String)
    $result = New-DevOpsWorkItem @wiParams -Verbose:$Verbose

    $global:prcmd = 'New-PrFromBranch -title (Get-LastCommit) -work {0} -issue {1}' -f $result.id, $issue.number
    $result
    $prcmd
}
#-------------------------------------------------------
function New-IssueBranch {
    [CmdletBinding(DefaultParameterSetName='ByIssueNum')]
    param(
        [Parameter(ParameterSetName='ByIssueNum', Position=0)]
        [Parameter(ParameterSetName='CreateWorkItem', Position=0)]
        # An existing GitHub issue number in the specified repo
        [uint32]$Issue,

        [Parameter(ParameterSetName='ByIssueNum', Position=1)]
        # An existing Azure DevOps workitem Id
        [uint32]$Workitem,

        [Parameter(ParameterSetName='ByIssueNum')]
        [Parameter(ParameterSetName='CreateWorkItem')]
        [string]$Label,

        # orgname/reponame - defaults to current repo
        [Parameter(ParameterSetName='ByIssueNum')]
        [Parameter(ParameterSetName='CreateWorkItem')]
        [string]$RepoName = (Get-RepoData).id,

        [Parameter(ParameterSetName='CreateWorkItem', Mandatory)]
        # Creates a new workitem in Azure DevOps
        [switch]$CreateWorkItem
    )
    if (-not $Verbose) {$Verbose = $false}

    $prefix = 'sdw'
    $ipart = $wpart = $lpart = ''
    if (($Issue -eq 0) -and ($Workitem -eq 0) -and ($Label -eq '')) {
        Write-Error 'You must provide -Label if -Issue and -Workitem are empty.'
        return
    }
    if ($Issue -ne 0)    {$ipart = "-i$Issue"}
    if ($Workitem -ne 0) {$wpart = "-w$Workitem"}
    if ($Label -ne '')   {$lpart = "-$Label"}

    if ($null -eq $RepoName) {
        Write-Error 'No repo specified.'
    } else {
        if ($createworkitem -and ($Issue -ne 0) -and ($Workitem -eq 0) ) {
            $params = @{
                Assignee      = 'sewhee'
                AreaPath      = 'Content\Production\Infrastructure\Azure e2e\PowerShell'
                IterationPath = (GetIterationPaths -Current).path
                IssueUrl      = "https://github.com/$RepoName/issues/$Issue"
            }
            $result = Import-GHIssueToDevOps @params -Verbose:$Verbose
            $Workitem = $result.id
            $wpart = "-w$Workitem"
        }
        $global:prcmd = 'New-PrFromBranch -title (Get-LastCommit)'
        if ($Workitem -ne 0) { $global:prcmd += " -work $Workitem" }
        if ($Issue -ne 0)    { $global:prcmd += " -issue $Issue" }
        $prcmd
        & $gitcmd checkout -b $prefix$wpart$ipart$lpart
    }
}
Set-Alias nib New-IssueBranch
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region completers
$sbBranchList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    & $gitcmd branch --format '%(refname:lstrip=2)' | Where-Object {$_ -like "$wordToComplete*"}
}
$cmdList =  'Checkout-Branch', 'Remove-Branch'
Register-ArgumentCompleter -ParameterName branch -ScriptBlock $sbBranchList -CommandName $cmdList
#-------------------------------------------------------
$sbGitLocation = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $gitRepoRoots | Where-Object {$_ -like "*$wordToComplete*"}
}
$cmdList = 'Get-BranchStatus'
Register-ArgumentCompleter -ParameterName GitLocation -ScriptBlock $sbGitLocation -CommandName $cmdList
#-------------------------------------------------------
$sbRepoList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $git_repos.keys | ForEach-Object { $git_repos[$_] } |
        Where-Object id -like "*$wordToComplete*" | Sort-Object Id | Select-Object -ExpandProperty Id
}
$cmdList = 'Add-GitHubLabel', 'Get-GitHubLabel', 'Import-GitHubLabel', 'Remove-GitHubLabel',
    'Set-GitHubLabel', 'Add-IssueComment', 'Get-IssueComment', 'Get-IssueLabel', 'Add-IssueLabel',
    'Remove-IssueLabel', 'Set-IssueLabel', 'Close-Issue', 'Get-Issue', 'New-Issue', 'Get-RepoData',
    'Remove-RepoData', 'Get-PrMerger', 'Get-RepoStatus', 'New-IssueBranch', 'Open-Repo',
    'Update-DevOpsWorkItem', 'Get-RepoStatus'
Register-ArgumentCompleter -ParameterName RepoName -ScriptBlock $sbRepoList -CommandName $cmdList
#-------------------------------------------------------
$sbIterationPathList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    (GetIterationPaths).path |
        Where-Object {$_ -like "*$wordToComplete*"} |
        ForEach-Object { "'$_'" }
}
$cmdList = 'Import-GHIssueToDevOps', 'New-DevOpsWorkItem', 'Update-DevOpsWorkItem'
Register-ArgumentCompleter -ParameterName IterationPath -ScriptBlock $sbIterationPathList -CommandName $cmdlist
#-------------------------------------------------------
$sbParentIds = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $DevOpsParentIds.keys |
        Where-Object {$_ -like "*$wordToComplete*"} |
        ForEach-Object { "`$DevOpsParentIds.$_" }
}
$cmdlist = 'New-DevOpsWorkItem', 'Update-DevOpsWorkItem'
Register-ArgumentCompleter  -ParameterName ParentId -ScriptBlock $sbParentIds -CommandName $cmdlist
#-------------------------------------------------------
$sbAreaPathList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    GetAreaPaths |
        Where-Object {$_ -like "*$wordToComplete*"} |
        ForEach-Object { "'$_'" }
}
$cmdlist = 'Import-GHIssueToDevOps', 'New-DevOpsWorkItem', 'Update-DevOpsWorkItem'
Register-ArgumentCompleter -ParameterName AreaPath -ScriptBlock $sbAreaPathList -CommandName $cmdList
#-------------------------------------------------------
$sbLabelList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $repo = if ($fakeBoundParameters.ContainsKey('RepoName')) {
        $fakeBoundParameters['RepoName']
    } else {
        'MicrosoftDocs/PowerShell-Docs'
    }
    Get-GitHubLabels -RepoName $repo |
        Where-Object name -Like "*$wordToComplete*" |
        Sort-Object name | Select-Object -ExpandProperty name
}
$cmdList = 'Set-IssueLabel', 'Remove-IssueLabel', 'Add-IssueLabel', 'New-Issue'
Register-ArgumentCompleter -ParameterName LabelName -ScriptBlock $sbLabelList -CommandName $cmdList
#-------------------------------------------------------
$sbRepoRootList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    Get-RepoRootList |
        Where-Object {$_.Path -like "*$wordToComplete*"} |
        ForEach-Object { $_.Path }
}
$cmdlist = 'Add-RepoRoot', 'Disable-RepoRoot', 'Enable-RepoRoot'
Register-ArgumentCompleter -ParameterName Path -ScriptBlock $sbRepoRootList -CommandName $cmdList
#-------------------------------------------------------
#endregion
#-------------------------------------------------------