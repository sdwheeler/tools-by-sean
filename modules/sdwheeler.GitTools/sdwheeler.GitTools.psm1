#-------------------------------------------------------
#region Git Environment configuration
function Get-MyRepos {
    [CmdletBinding()]
    param (
        [string[]]$repoRoots
    )

    if (-not $Verbose) {$Verbose = $false}

    $my_repos = @{}

    $originalDirs = . {
        $d = Get-PSDrive d -ea SilentlyContinue
        if ($d) {
            Get-Location -PSDrive D
        }
        Get-Location -PSDrive C
    }

    Write-Verbose '----------------------------'
    Write-Verbose 'Scanning local repos'
    Write-Verbose '----------------------------'

    foreach ($repoRoot in $repoRoots) {
        if (Test-Path $repoRoot) {
            Write-Verbose "Root - $repoRoot"
            Get-ChildItem $repoRoot -Directory | ForEach-Object {
                Write-Verbose ("Subfolder - " + $_.fullname)
                Push-Location $_.fullname
                $currentRepo = Get-RepoData
                $my_repos.Add($currentRepo.name, $currentRepo)
                Pop-Location
            }
        }
    }
    $global:git_repos = $my_repos
    '{0} repos found.' -f $global:git_repos.Count

    $global:git_repos | Export-Clixml -Depth 10 -Path ~/repocache.clixml -Force

    Write-Verbose '----------------------------'
    Write-Verbose 'Restoring drive locations'
    $originalDirs | Set-Location
    ('c'..'d' | ForEach-Object { Get-Location -PSDrive $_ }).Path | Write-Verbose
}
#-------------------------------------------------------
function Get-RepoData {
    [CmdletBinding()]
    param()

    if (-not $Verbose) {$Verbose = $false}

    $status = Get-GitStatus
    if ($status) {
        $repo = $status.RepoName
        $currentRepo = [pscustomobject]@{
            id             = ''
            name           = $repo
            organization   = ''
            private        = ''
            default_branch = ''
            html_url       = ''
            description    = ''
            host           = ''
            path           = $status.GitDir -replace '\\\.git'
            remote         = $null
        }

        $remotes = @{ }
        git.exe remote | ForEach-Object {
            $url = git remote get-url --all $_
            $remotes.Add($_, $url)
        }
        $currentRepo.remote = [pscustomobject]$remotes

        if ($remotes.upstream) {
            $uri = [uri]$currentRepo.remote.upstream
        }
        else {
            $uri = [uri]$currentRepo.remote.origin
        }
        $currentRepo.organization = $uri.Segments[1].TrimEnd('/')
        $currentRepo.id = $currentRepo.organization + '/' + $currentRepo.name

        switch -Regex ($remotes.origin) {
            '.*github.com.*' {
                $currentRepo.host = 'github'
                $apiurl = 'https://api.github.com/repos/' + $currentRepo.id
                $hdr = @{
                    Accept        = 'application/vnd.github.json'
                    Authorization = "token ${Env:\GITHUB_TOKEN}"
                }
                break
            }
            '.*ghe.com.*' {
                $currentRepo.host = 'github'
                $apiurl = 'https://' + $uri.Host + '/api/v3/repos/' + $currentRepo.id
                $hdr = @{
                    Accept        = 'application/vnd.github.json'
                    Authorization = "token ${Env:\GHE_TOKEN}"
                }
                break
            }
            '.*visualstudio.com.*|.*dev.azure.com.*' {
                $currentRepo.host = 'visualstudio'
                $currentRepo.private = 'True'
                $currentRepo.html_url = $currentRepo.remotes.origin
                $currentRepo.default_branch = (git remote show origin | findstr HEAD).split(':')[1].trim()
                break
            }
        }

        Write-Verbose '----------------------------'
        Write-Verbose "Querying Repo - $($currentRepo.id)"
        Write-Verbose '----------------------------'

        if ($currentRepo.host -eq 'github') {
            try {
                $gitrepo = Invoke-RestMethod $apiurl -Headers $hdr -ea Stop
                $currentRepo.private = $gitrepo.private
                $currentRepo.html_url = $gitrepo.html_url
                $currentRepo.description = $gitrepo.description
                $currentRepo.default_branch = $gitrepo.default_branch
            }
            catch {
                Write-Host ('{0}: [Error] {1}' -f $currentRepo.id, $_.exception.message)
                $Error.Clear()
            }
        }
        Write-Verbose ($currentRepo | Out-String)
        $currentRepo
    } else {
        Write-Warning "Not a repo - $pwd"
    }
}
#-------------------------------------------------------
function Update-RepoData {
    param(
        [switch]$PassThru
    )
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
        $currentRepo = Get-RepoData
        if ($global:git_repos.ContainsKey($currentRepo.name)) {
            $global:git_repos[$currentRepo.name] = $currentRepo
        } else {
            $global:git_repos.Add($currentRepo.name, $currentRepo)
        }
        $global:git_repos | Export-Clixml -Depth 10 -Path ~/repocache.clixml -Force
        if ($PassThru) {
            $global:git_repos[$currentRepo.name]
        }
    } else {
        'Not a git repo.'
    }
}
#-------------------------------------------------------
function Show-RepoData {
    [CmdletBinding(DefaultParameterSetName = 'reponame')]
    param(
        [Parameter(ParameterSetName = 'reponame',
            Position = 0,
            ValueFromPipelineByPropertyName = $true)]
        [alias('name')]
        [string]$reponame,

        [Parameter(ParameterSetName = 'orgname', Mandatory)]
        [alias('org')]
        [string]$organization
    )
    process {
        if ($organization) {
            $global:git_repos.keys |
                ForEach-Object { $global:git_repos[$_] |
                        Where-Object organization -EQ $organization
                    }
        } else {
            if ($reponame -eq '') {
                $gitStatus = Get-GitStatus
                if ($gitStatus) {
                    $reponame = $GitStatus.RepoName
                } else {
                    'Not a git repo.'
                    return
                }
            } elseif ($reponame -like '*/*') {
                $reponame = ($reponame -split '/')[1]
            }
            $global:git_repos[$reponame]
        }
    }
}
Set-Alias srd Show-RepoData
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
Set-Alias open open-repo
Set-Alias goto open-repo
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Branch management
function Checkout-Branch {
    param([string]$branch)

    if ($branch -eq '') {
        $repo = $global:git_repos[(Get-GitStatus).RepoName]
        $branch = $repo.default_branch
    }
    git checkout $branch
}
Set-Alias checkout Checkout-Branch
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
                git.exe pull upstream ($gitStatus.Branch)
                if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red }
                Write-Host '-----[push origin]------------' -Fore DarkCyan
                Write-Host ('-' * 30) -Fore DarkCyan
                git.exe push origin ($gitStatus.Branch)
                if (!$?) { Write-Host 'Error pushing to origin' -Fore Red }
            }
            else {
                git.exe pull origin ($gitStatus.Branch)
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
    param([switch]$origin)
    $gitStatus = Get-GitStatus
    if ($null -eq $gitStatus) {
        Write-Host ('=' * 30) -Fore Magenta
        Write-Host "Skipping $pwd - not a repo." -Fore Red
        Write-Host ('=' * 30) -Fore Magenta
    } else {
        $RepoName = $gitStatus.RepoName
        $repo = $global:git_repos[$RepoName]
        Write-Host ('=' * 30) -Fore Magenta

        Write-Host '-----[fetch --all --prune]----' -Fore DarkCyan
        git.exe fetch --all --prune
        if (!$?) {
            Write-Host 'Error fetching from remotes' -Fore Red
            $global:SyncAllErrors += "$RepoName - Error fetching from remotes"
        }

        if ($origin) {
            Write-Host ('Syncing {0} from {1}' -f $gitStatus.Upstream, $RepoName) -Fore Magenta
            Write-Host '-----[pull origin]------------' -Fore DarkCyan
            git.exe pull origin $gitStatus.Branch
            if (!$?) {
                Write-Host 'Error pulling from origin' -Fore Red
                $global:SyncAllErrors += "$RepoName - Error pulling from origin"
            }
            Write-Host ('=' * 30) -Fore Magenta
        } else { # else not $origin
            if ($gitStatus.Branch -ne $repo.default_branch) {
                Write-Host ('=' * 30) -Fore Magenta
                Write-Host "Skipping $pwd - default branch not checked out." -Fore Yellow
                $global:SyncAllErrors += "$RepoName - Skipping $pwd - default branch not checked out."
                Write-Host ('=' * 30) -Fore Magenta
            } else { # else default branch
                Write-Host ('Syncing {0}/{1} [{2}]' -f $repo.organization, $RepoName, $repo.default_branch) -Fore Magenta
                if ($repo.remote.upstream) {
                    Write-Host '-----[pull upstream]----------' -Fore DarkCyan
                    git.exe pull upstream ($repo.default_branch)
                    if (!$?) {
                        Write-Host 'Error pulling from upstream' -Fore Red
                        $global:SyncAllErrors += "$RepoName - Error pulling from upstream."
                    }
                    if ($repo.remote.upstream -eq $repo.remote.origin) {
                        Write-Host '-----[fetch origin]-----------' -Fore DarkCyan
                        git.exe fetch origin
                        if (!$?) {
                            Write-Host 'Error fetching from origin' -Fore Red
                            $global:SyncAllErrors += "$RepoName - Error fetching from origin."
                        }
                    } else { # else upstream different from origin
                        Write-Host '-----[push origin]------------' -Fore DarkCyan
                        git.exe push origin ($repo.default_branch)
                        if (!$?) {
                            Write-Host 'Error pushing to origin' -Fore Red
                            $global:SyncAllErrors += "$RepoName - Error pushing to origin."
                        }
                    }
                } else { # else no upstream
                    Write-Host ('=' * 30) -Fore Magenta
                    Write-Host 'No upstream defined' -Fore Yellow
                    Write-Host '-----[pull origin]------------' -Fore DarkCyan
                    git.exe pull origin ($repo.default_branch)
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
    param([switch]$origin)

    $originalDirs = . {
        if (Test-Path C:\Git) {Get-Location -PSDrive C}
        if (Test-Path D:\Git) {Get-Location -PSDrive D}
    }

    $global:SyncAllErrors = @()

    foreach ($reporoot in $global:gitRepoRoots) {
        "Processing repos in $reporoot"
        if (Test-Path $reporoot) {
            $reposlist = Get-ChildItem $reporoot -dir -Hidden .git -rec -Depth 2 |
                Select-Object -exp parent | Select-Object -exp fullname
            if ($reposlist) {
                $reposlist | ForEach-Object {
                    Push-Location $_
                    Sync-Repo -origin:$origin
                    Pop-Location
                }
            }
            else {
                Write-Host 'No repos found.' -Fore Red
            }
        }
    }
    $originalDirs | Set-Location
    Write-Host ('=' * 30) -Fore Magenta
    $global:SyncAllErrors
}
Set-Alias syncall Sync-AllRepos
#-------------------------------------------------------
function Get-RepoStatus {
    param(
        [string[]]$RepoName = ('MicrosoftDocs/PowerShell-Docs', 'MicrosoftDocs/PowerShell-Docs-archive',
            'MicrosoftDocs/PowerShell-Docs-Modules', 'PowerShell/Community-Blog',
            'MicrosoftDocs/powershell-sdk-samples', 'MicrosoftDocs/powershell-docs-sdk-dotnet',
            'MicrosoftDocs/windows-powershell-docs', 'PowerShell/platyPS',
            'MicrosoftDocs/PowerShell-Docs-DSC'),
        [switch]$az,
        [switch]$loc
    )
    $hdr = @{
        Accept        = 'application/vnd.github.VERSION.full+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }

    $azlist = 'MicrosoftDocs/azure-docs-powershell', 'Azure/azure-docs-powershell-samples',
    'MicrosoftDocs/azure-docs-cli', 'Azure-Samples/azure-cli-samples'

    $loclist = 'MicrosoftDocs/powerShell-Docs.cs-cz', 'MicrosoftDocs/powerShell-Docs.de-de',
    'MicrosoftDocs/powerShell-Docs.es-es', 'MicrosoftDocs/powerShell-Docs.fr-fr',
    'MicrosoftDocs/powerShell-Docs.hu-hu', 'MicrosoftDocs/powerShell-Docs.it-it',
    'MicrosoftDocs/powerShell-Docs.ja-jp', 'MicrosoftDocs/powerShell-Docs.ko-kr',
    'MicrosoftDocs/powerShell-Docs.nl-nl', 'MicrosoftDocs/powerShell-Docs.pl-pl',
    'MicrosoftDocs/powerShell-Docs.pt-br', 'MicrosoftDocs/powerShell-Docs.pt-pt',
    'MicrosoftDocs/powerShell-Docs.ru-ru', 'MicrosoftDocs/powerShell-Docs.sv-se',
    'MicrosoftDocs/powerShell-Docs.tr-tr', 'MicrosoftDocs/powerShell-Docs.zh-cn',
    'MicrosoftDocs/powerShell-Docs.zh-tw'

    $status = @()

    $repolist = $RepoName

    if ($loc) {
        $repolist = $loclist
    }
    if ($az) {
        $repolist = $azlist
    }

    foreach ($repo in $repolist) {
        $apiurl = 'https://api.github.com/repos/{0}' -f $repo
        $ghrepo = Invoke-RestMethod $apiurl -header $hdr
        $prlist = Invoke-RestMethod ($apiurl + '/pulls') -header $hdr -follow
        $count = 0
        if ($prlist[0].count -eq 1) {
            $count = $prlist.count
        }
        else {
            $prlist | ForEach-Object { $count += $_.count }
        }
        $status += [pscustomobject]@{
                repo       = $repo
                issuecount = $ghrepo.open_issues - $count
                prcount    = $count
            }
    }
    $status | Sort-Object repo| Format-Table -a
}
#-------------------------------------------------------
function Remove-Branch {
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [string[]]$branch
    )
    process {
        if ($branch) {
            $allbranches = @()
            $branch | ForEach-Object {
                $allbranches += git branch -l $_
            }
            Write-Host ("Deleting branches:`r`n" + ($allbranches -join "`r`n"))
            $allbranches | ForEach-Object {
                $b = $_.Trim()
                '---' * 3
                git.exe push origin --delete $b
                '---'
                git.exe branch -D $b
                #git.exe branch -Dr origin/$b
            }
        }
    }
}
Set-Alias -Name Kill-Branch -Value Remove-Branch
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Git Information
function Get-BranchInfo {
    $premote = '^branch\.(?<branch>.+)\.remote\s(?<remote>.*)$'
    $pbranch = '[\s*\*]+(?<branch>[^\s]*)\s*(?<sha>[^\s]*)\s(?<message>.*)'
    $remotes = git config --get-regex '^branch\..*\.remote' | %{ if ($_ -match $premote) { $Matches | select branch,remote } }
    $branches = git branch -vl | ForEach-Object {
        if ($_ -match $pbranch) {$Matches | select branch, @{n='remote';e={''}}, sha, message}
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
            $branches += $r | select branch, @{n='remote';e={''}}, sha, message
        }
    }
    $branches
}
#-------------------------------------------------------
function Get-GitMergeBase {
    param (
        [string]$defaultBranch = (Show-RepoData).default_branch
    )
    $branchName = git branch --show-current
    git merge-base $defaultBranch $branchName
}
#-------------------------------------------------------
function Get-GitBranchChanges {
    param (
        [string]$defaultBranch = (Show-RepoData).default_branch
    )

    $branchName = git branch --show-current
    $diffs = git diff --name-only $($branchName) $(Get-GitMergeBase -defaultBranch $defaultBranch)
    if ($diffs.count -eq 1) {
        Write-Output (, $diffs)
    }
    else {
        $diffs
    }
}
#-------------------------------------------------------
function Get-BranchStatus {
    param(
        [SupportsWildcards()]
        [string[]]$GitLocation = '*'
    )
    Write-Host ''
    $global:git_repos.keys |
        Where-Object {$global:git_repos[$_].path -like "$GitLocation*"} |
        ForEach-Object {
            Push-Location $global:git_repos[$_].path
            if ((Get-GitStatus).Branch -eq $global:git_repos[$_].default_branch) {
                $default = 'default'
                $fgcolor = [consolecolor]::Cyan
            }
            else {
                $default = 'working'
                $fgcolor = [consolecolor]::Red
            }
            Write-Host "$_ (" -NoNewline
            Write-Host $default -ForegroundColor $fgcolor -NoNewline
            Write-Host ')' -NoNewline
            Write-VcsStatus
            Pop-Location
        }
    Write-Host ''
}
#-------------------------------------------------------
function Get-LastCommit {
    git log -n 1 --pretty='format:%s'
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Git queries
function Invoke-GitHubApi {
    param(
        [string]$api,
        [Microsoft.PowerShell.Commands.WebRequestMethod]
        $method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
    )
    $baseuri = 'https://api.github.com/'
    if ($api -like "$baseuri*") {
        $uri = $api
    }
    else {
        $uri = $baseuri + $api
    }
    $hdr = @{
        Accept        = 'application/vnd.github.v3.raw+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $results = Invoke-RestMethod -Headers $hdr -Uri $uri -Method $method -FollowRelLink
    foreach ($page in $results) { $page }
}
#-------------------------------------------------------
function Get-GitHubLabels {
    param(
        [string]$RepoName = 'microsoftdocs/powershell-docs',

        [string]$Name,

        [ValidateSet('Name', 'Color', 'Description', ignorecase = $true)]
        [string]$Sort = 'Name',

        [switch]$NoANSI
    )
    function colorit {
        param(
            $label,
            $rgb
        )
        $r = [int]('0x' + $rgb.Substring(0, 2))
        $g = [int]('0x' + $rgb.Substring(2, 2))
        $b = [int]('0x' + $rgb.Substring(4, 2))
        $ansi = 16 + (36 * [math]::round($r / 255 * 5)) + (6 * [math]::round($g / 255 * 5)) + [math]::round($b / 255 * 5)
        if (($ansi % 36) -lt 16) { $fg = 0 } else { $fg = 255 }
        "`e[48;2;${r};${g};${b}m`e[38;2;${fg};${fg};${fg}m${label}`e[0m"
    }

    $apiurl = "repos/$RepoName/labels"

    $labels = Invoke-GitHubApi $apiurl | Sort-Object $sort

    if ($null -ne $LabelName) {
        $labels = $labels | Where-Object { $_.name -like ('*{0}*' -f $Name) }
    }
    if ($NoANSI) {
        $labels | Select-Object name,
        @{n = 'color'; e = { "0x$($_.color)" } },
        description
    }
    else {
        $labels | Select-Object @{n = 'name'; e = { colorit $_.name $_.color } },
        @{n = 'color'; e = { "0x$($_.color)" } },
        description
    }
}
#-------------------------------------------------------
function Import-GitHubLabels {
    [CmdletBinding()]
    param(
        [string]$RepoName,
        [string]$CsvPath
    )

    if (-not $Verbose) {$Verbose = $false}

    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $api = "https://api.github.com/repos/$RepoName/labels"

    $oldlabels = Get-GitHubLabels $RepoName -NoANSI
    $newlabels = Import-Csv $CsvPath

    foreach ($label in $newlabels) {
        $label.color = $label.color -replace '0x'
        $body = $label | ConvertTo-Json
        if ($oldlabels.name -contains $label.name) {
            $method = 'PATCH'
            $uri = $api + "/" + $label.name
        } else {
            $method = 'POST'
            $uri = $api
        }
        Write-Verbose $method
        Write-Verbose $body
        Invoke-RestMethod -Uri $uri -Method $method -Body $body -Headers $hdr |
            Select-Object name, color, description
    }
}
#-------------------------------------------------------
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
function Get-Issue {
    [CmdletBinding(DefaultParameterSetName = 'ByIssueNum')]
    param(
        [Parameter(ParameterSetName = 'ByIssueNum', Position = 0, Mandatory)]
        [int]$IssueNum,

        [Parameter(ParameterSetName = 'ByIssueNum')]
        [string]$RepoName = (Show-RepoData).id,

        [Parameter(ParameterSetName = 'ByUri', Mandatory)]
        [uri]$IssueUrl
    )

    if (-not $Verbose) {$Verbose = $false}

    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    if ($null -ne $IssueUrl) {
        $RepoName = ($IssueUrl.Segments[1..2] -join '').trim('/')
        $IssueNum = $IssueUrl.Segments[4]
    }

    $apiurl = "https://api.github.com/repos/$RepoName/issues/$IssueNum"
    Write-Verbose "Getting $apiurl"
    $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
    $apiurl = "https://api.github.com/repos/$RepoName/issues/$IssueNum/comments"
    Write-Verbose "Getting $apiurl"
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) |
        Select-Object -ExpandProperty body
    [pscustomobject]@{
        number     = $issue.number
        name       = $RepoName + '#' + $num
        url        = $issue.html_url
        created_at = $issue.created_at
        assignee   = $issue.assignee.login
        title      = $issue.title
        labels     = $issue.labels.name
        body       = $issue.body
        comments   = $comments -join "`n"
    }
}
#-------------------------------------------------------
function Get-IssueList {
    param(
        $RepoName = 'MicrosoftDocs/PowerShell-Docs'
    )
    $hdr = @{
        Accept        = 'application/vnd.github.v3.raw+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$RepoName/issues"
    $results = (Invoke-RestMethod $apiurl -Headers $hdr -FollowRelLink)
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

    $repo = (Show-RepoData)
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

    $currentbranch = git branch --show-current
    $defaultbranch = $repo.default_branch

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
#region Workitem actions
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
        'Content\Production\Infrastructure\Azure Deployments\PowerShell'
    )
    $areaPathList
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
        @{l = 'Description'; e = { $_.fields.'System.Description' } }
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

        [ValidateSet('Bug', 'Task', 'User%20Story', 'Backlog%20Work', 'Feature')]
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
        [string]$RepoName = (Show-RepoData).id,

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
    $issue = Get-Issue -IssueNum $IssueId -RepoName $RepoName
    if ($null -eq $issue) {
        throw "Issue $IssueId not found."
    } else {
        $global:prcmd = 'New-PrFromBranch -title (Get-LastCommit) -work {0} -issue {1}' -f $Id, $issue.number
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

    $issue = Get-Issue -issueurl $IssueUrl
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

    $global:prcmd = 'New-PrFromBranch -work {0} -issue {1} -title (Get-LastCommit)' -f $result.id, $issue.number
    $result
    $prcmd
}
#-------------------------------------------------------
function New-IssueBranch {
    [CmdletBinding()]
    param(
        [string]$Id,
        [string]$RepoName = (Show-RepoData).id,
        [switch]$CreateWorkItem
    )

    try {
        0 + $id | Out-Null
        $prefix = 'sdw-i'
    }
    catch {
        $prefix = 'sdw-'
    }

    if (-not $Verbose) {$Verbose = $false}

    if ($null -eq $RepoName) {
        Write-Error 'No repo specified.'
    } else {
        git.exe checkout -b $prefix$id
        if ($createworkitem) {
            $params = @{
                Assignee      = 'sewhee'
                AreaPath      = 'Content\Production\Infrastructure\Azure Deployments\PowerShell'
                IterationPath = (GetIterationPaths -Current).path
                IssueUrl      = "https://github.com/$RepoName/issues/$id"
            }
            Import-GHIssueToDevOps @params -Verbose:$Verbose
        }
    }
}
Set-Alias nib New-IssueBranch
Register-ArgumentCompleter -CommandName New-IssueBranch -ParameterName RepoName -ScriptBlock $sbRepoList
#-------------------------------------------------------
function New-MergeToLive {
    param(
        $repo = (Show-RepoData)
    )
    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$($repo.id)/pulls"
    $params = @{
        title = 'Publish to live'
        body  = 'Publishing latest changes to live'
        head  = $repo.default_branch
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
#endregion
#-------------------------------------------------------
#region completers
$sbBranchList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    git branch --format '%(refname:lstrip=2)' | Where-Object {$_ -like "$wordToComplete*"}
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
$cmdList = 'Get-Issue','Get-IssueList', 'Get-RepoStatus', 'Open-Repo', 'Import-GitHubLabels',
    'Get-GitHubLabels', 'Get-PrMerger', 'Show-RepoData', 'Update-DevOpsWorkItem'
Register-ArgumentCompleter -ParameterName RepoName -ScriptBlock $sbRepoList -CommandName $cmdList
#-------------------------------------------------------
$sbIterationPathList = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    (GetIterationPaths).path | Where-Object {$_ -like "*$wordToComplete*"}
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
#endregion