#-------------------------------------------------------
#region Git Environment configuration
function Get-MyRepos {
    [CmdletBinding()]
    param (
        [string[]]$repoRoots,
        [switch]$TestNetwork
    )

    try {
        $null = Test-Connection github.com -ea Stop -Count 1
    }
    catch {
        'Network error detected.'
        break
    }

    $my_repos = @{}

    Write-Verbose '----------------------------'
    Write-Verbose 'Scanning local repos'
    Write-Verbose '----------------------------'
    $originalDirs = . {
        $d = Get-PSDrive d -ea SilentlyContinue
        if ($d) {
            Get-Location -PSDrive D
        }
        Get-Location -PSDrive C
    }
    foreach ($repoRoot in $repoRoots) {
        if (Test-Path $repoRoot) {
            Write-Verbose "Root - $repoRoot"
            Get-ChildItem $repoRoot -Directory -Exclude *.wiki | ForEach-Object {

                $dir = $_.fullname
                Write-Verbose "Subfolder - $dir"

                Push-Location $dir
                $gitStatus = Get-GitStatus
                if ($gitStatus) {
                    $gitDir = Get-Item $gitStatus.gitdir -Force
                    $repoName = $gitStatus.RepoName
                }
                else {
                    continue
                }

                $arepo = New-Object -TypeName psobject -Property ([ordered]@{
                        id             = ''
                        name           = $repoName
                        organization   = ''
                        private        = ''
                        default_branch = ''
                        html_url       = ''
                        description    = ''
                        host           = ''
                        path           = $dir
                        remote         = $null
                    })

                $remotes = @{ }

                git.exe remote -v | Select-String '(fetch)' | ForEach-Object {
                    $r = ($_ -replace ' \(fetch\)') -split "`t"
                    $remotes.Add($r[0], $r[1])
                }
                $arepo.remote = New-Object -type psobject -prop $remotes
                if ($remotes.upstream) {
                    $arepo.organization = ($remotes.upstream -split '/')[3]
                }
                else {
                    $arepo.organization = ($remotes.origin -split '/')[3]
                }
                $arepo.id = '{0}/{1}' -f $arepo.organization, $arepo.name

                switch -Regex ($remotes.origin) {
                    '.*github.com.*' {
                        $arepo.host = 'github'
                        break
                    }
                    '.*visualstudio.com.*' {
                        $arepo.host = 'visualstudio'
                        break
                    }
                }

                if ($my_repos.ContainsKey($repoName)) {
                    Write-Warning "Duplicate repo - $repoName"
                    $arepo
                }
                else {
                    $my_repos.Add($repoName, $arepo)
                }
                Pop-Location
            }
        }
    }
    $originalDirs | ForEach-Object { Set-Location $_ }

    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }

    Write-Verbose '----------------------------'
    Write-Verbose 'Querying GitHub'
    Write-Verbose '----------------------------'
    foreach ($repo in $my_repos.Keys) {
        Write-Verbose $my_repos[$repo].id

        switch ($my_repos[$repo].host) {
            'github' {
                $apiurl = $my_repos[$repo].remote.origin -replace 'github.com/', 'api.github.com/repos/'
                $apiurl = $apiurl -replace '\.git$', ''

                try {
                    $gitrepo = Invoke-RestMethod $apiurl -Headers $hdr -ea Stop
                    $my_repos[$repo].private = $gitrepo.private
                    $my_repos[$repo].default_branch = $gitrepo.default_branch
                    $my_repos[$repo].html_url = $gitrepo.html_url
                    $my_repos[$repo].description = $gitrepo.description
                }
                catch {
                    Write-Host ('{0}: [Error] {1}' -f $my_repos[$repo].id, $_.exception.message)
                    $Error.Clear()
                }
            }
            'visualstudio' {
                $my_repos[$repo].private = 'True'
                $my_repos[$repo].default_branch = 'master'
                $my_repos[$repo].html_url = $my_repos[$repo].remotes.origin
            }
        }
    }

    $global:git_repos = $my_repos
    '{0} repos found.' -f $global:git_repos.Count
}
function Show-Repo {
    [CmdletBinding(DefaultParameterSetName = 'reponame')]
    param(
        [Parameter(ParameterSetName = 'reponame',
            Position = 0,
            ValueFromPipelineByPropertyName = $true)]
        [alias('name')]
        [string]$repo,

        [Parameter(ParameterSetName = 'orgname', Mandatory = $true)]
        [alias('org')]
        [string]$organization
    )
    process {
        $GitStatus = Get-GitStatus
        if ($organization) {
            $global:git_repos.keys |
                ForEach-Object { $global:git_repos[$_] |
                        Where-Object organization -EQ $organization
                    }
        }
        elseif ($repo) {
            $global:git_repos.keys |
                Where-Object { $_ -like $repo } |
                ForEach-Object { $global:git_repos[$_]
                }
        }
        else {
            $repo = $GitStatus.RepoName
            $global:git_repos.keys |
                Where-Object { $_ -like $repo } |
                ForEach-Object { $global:git_repos[$_]
                }
        }
    }
}
#-------------------------------------------------------
function Goto-Repo {
    [CmdletBinding(DefaultParameterSetName = 'base')]
    param(
        [Parameter(Position = 0)]
        [string]$reponame = '.',

        [Parameter(ParameterSetName = 'base')]
        [Parameter(ParameterSetName = 'forkissues', Mandatory = $true)]
        [Parameter(ParameterSetName = 'forkpulls', Mandatory = $true)]
        [switch]$fork,

        [Parameter(ParameterSetName = 'forkissues', Mandatory = $true)]
        [Parameter(ParameterSetName = 'baseissues', Mandatory = $true)]
        [switch]$issues,

        [Parameter(ParameterSetName = 'forkpulls', Mandatory = $true)]
        [Parameter(ParameterSetName = 'basepulls', Mandatory = $true)]
        [switch]$pulls
    )

    if ($reponame -eq '.') {
        $gitStatus = Get-GitStatus
        if ($gitStatus) {
            $reponame = $gitStatus.RepoName
        }
    }
    $repo = $global:git_repos[$reponame]

    if ($repo) {

        if ($fork) {
            $url = $repo.remote.origin -replace '\.git$'
        }
        else {
            if ($repo.remote.upstream) {
                $url = $repo.remote.upstream -replace '\.git$'
            }
        }
        if ($issues) { $url += '/issues' }
        if ($pulls) { $url += '/pulls' }

        Start-Process $url
    }
    else {
        'Not a git repo.'
    }
}
Set-Alias goto goto-repo
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
            Write-Host ('=' * 30) -Fore DarkCyan
            Write-Host ("Skipping  - $($gitStatus.Branch) has uncommitted changes.") -Fore Yellow
            Write-Host ('=' * 30) -Fore DarkCyan
        }
        else {
            Write-Host ('=' * 30) -Fore DarkCyan
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
        Write-Host ('=' * 30) -Fore DarkCyan
        Write-Host "Skipping $pwd - not a repo." -Fore Yellow
        Write-Host ('=' * 30) -Fore DarkCyan
    }
}
#-------------------------------------------------------
function Sync-Repo {
    param([switch]$origin)
    $gitStatus = Get-GitStatus
    if ($null -eq $gitStatus) {
        Write-Host ('=' * 30) -Fore DarkCyan
        Write-Host "Skipping $pwd - not a repo." -Fore Red
        Write-Host ('=' * 30) -Fore DarkCyan
    }
    else {
        $repoName = $gitStatus.RepoName
        $repo = $global:git_repos[$reponame]
        Write-Host ('=' * 30) -Fore DarkCyan
        if ($origin) {
            Write-Host ('Syncing {0} from {1}' -f $gitStatus.Upstream, $repoName) -Fore DarkCyan
            Write-Host '-----[fetch origin]-----------' -Fore DarkCyan
            git.exe fetch origin
            if (!$?) { Write-Host 'Error fetching from origin' -Fore Red }
            Write-Host '-----[pull origin]------------' -Fore DarkCyan
            git.exe pull origin $gitStatus.Branch
            if (!$?) { Write-Host 'Error pulling from origin' -Fore Red }
            Write-Host ('=' * 30) -Fore DarkCyan
        }
        else {
            if ($gitStatus.Branch -ne $repo.default_branch) {
                Write-Host ('=' * 30) -Fore DarkCyan
                Write-Host "Skipping $pwd - default branch not checked out." -Fore Yellow
                Write-Host ('=' * 30) -Fore DarkCyan
            }
            else {
                Write-Host ('Syncing {0}/{1} [{2}]' -f $repo.organization, $reponame, $repo.default_branch) -Fore DarkCyan
                if ($repo.remote.upstream) {
                    Write-Host '-----[fetch upstream]---------' -Fore DarkCyan
                    git.exe fetch upstream
                    if (!$?) { Write-Host 'Error fetching from upstream' -Fore Red }
                    Write-Host '-----[pull upstream]----------' -Fore DarkCyan
                    git.exe pull upstream ($repo.default_branch)
                    if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red }
                    Write-Host '-----[push origin]------------' -Fore DarkCyan
                    if ($repo.remote.upstream -eq $repo.remote.origin) {
                        git.exe fetch origin
                        if (!$?) { Write-Host 'Error fetching from origin' -Fore Red }
                    }
                    else {
                        git.exe push origin ($repo.default_branch)
                        if (!$?) { Write-Host 'Error pushing to origin' -Fore Red }
                    }
                }
                else {
                    Write-Host ('=' * 30) -Fore DarkCyan
                    Write-Host 'No upstream defined' -Fore Yellow
                    Write-Host '-----[pull origin]------------' -Fore DarkCyan
                    git.exe pull origin ($repo.default_branch)
                    if (!$?) { Write-Host 'Error pulling from origin' -Fore Red }
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

    foreach ($reporoot in $global:gitRepoRoots) {
        "Processing repos in $reporoot"
        if (Test-Path $reporoot) {
            $reposlist = Get-ChildItem $reporoot -dir -Hidden .git -rec -Depth 2 |
                Select-Object -exp parent | Select-Object -exp fullname
            if ($reposlist) {
                $reposlist | ForEach-Object {
                    Push-Location $_
                    sync-repo -origin:$origin
                    Pop-Location
                }
            }
            else {
                Write-Host 'No repos found.' -Fore Red
            }
        }
    }
    $originalDirs | Set-Location
}
Set-Alias syncall sync-allrepos
#-------------------------------------------------------
function Kill-Branch {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Git Information
function Get-GitMergeBase {
    param (
        [string]$defaultBranch = (show-repo).default_branch
    )

    # Set variables
    $branchName = git branch --show-current
    git merge-base $defaultBranch $branchName
}
#-------------------------------------------------------
function Get-GitBranchChanges {
    param (
        [string]$defaultBranch = (show-repo).default_branch
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
    Write-Host ''
    $global:git_repos.keys | Sort-Object | ForEach-Object {
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
function Get-RepoStatus {
    param(
        $repolist = ('MicrosoftDocs/PowerShell-Docs', 'MicrosoftDocs/PowerShell-Docs-archive',
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
        $status += New-Object -type psobject -prop ([ordered]@{
                repo       = $repo
                issuecount = $ghrepo.open_issues - $count
                prcount    = $count
            })
    }
    $status | Sort-Object repo| Format-Table -a
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
function List-Labels {
    param(
        [string]$repo = 'microsoftdocs/powershell-docs',

        [string]$name,

        [ValidateSet('Name', 'Color', 'Description', ignorecase = $true)]
        [string]$sort = 'name'
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

    $apiurl = "repos/$repo/labels"

    $labels = Invoke-GitHubApi $apiurl | Sort-Object $sort

    if ($null -ne $name) {
        $labels | Where-Object { $_.name -like ('*{0}*' -f $name) } | Select-Object @{n = 'label'; e = { colorit $_.name $_.color } }, color, description
    }
    else {
        $labels | Select-Object @{n = 'label'; e = { colorit $_.name $_.color } }, color, description
    }
}
Set-Alias ll list-labels
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
function List-PrMerger {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $reponame
    )
    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $query = "q=type:pr+is:merged+repo:$reponame"

    $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr
    foreach ($pr in $prlist.items) {
        $prevent = (Invoke-RestMethod $pr.events_url -Headers $hdr) | Where-Object event -EQ merged
        $result = [ordered]@{
            number     = $pr.number
            state      = $pr.state
            event      = $prevent.event
            created_at = Get-Date $prevent.created_at -f 'yyyy-MM-dd'
            merged_by  = $prevent.actor.login
            title      = $pr.title
        }
        New-Object -type psobject -Property $result
    }
}
#-------------------------------------------------------
function Get-Issue {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [uri]$issueurl
    )
    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    if ($issueurl -ne '') {
        $repo = ($issueurl.Segments[1..2] -join '').TrimEnd('/')
        $num = $issueurl.Segments[-1]
    }

    $apiurl = "https://api.github.com/repos/$repo/issues/$num"
    $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
    $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | Select-Object -ExpandProperty body
    $retval = New-Object -TypeName psobject -Property ([ordered]@{
            title      = '[GitHub #{0}] {1}' -f $issue.number, $issue.title
            url        = $issue.html_url
            created_at = $issue.created_at
            state      = $issue.state
            assignee   = $issue.assignee.login
            labels     = $issue.labels.name
            body       = $issue.body
            comments   = $comments -join "`n"
        })
    $retval
}
#-------------------------------------------------------
function Get-IssueList {
    param(
        [ValidateSet('azure/azure-docs-powershell', 'azure/azure-docs-powershell-samples',
            'azure/azure-powershell', 'azure/azure-powershell-pr', 'powershell/platyps',
            'powershell/powershell', 'MicrosoftDocs/PowerShell-Docs', 'powershell/powershell-rfc',
            'powershell/powershellget', ignorecase = $true)]
        $reponame = 'MicrosoftDocs/PowerShell-Docs'
    )
    $hdr = @{
        Accept        = 'application/vnd.github.v3.raw+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$reponame/issues"
    $results = (Invoke-RestMethod $apiurl -Headers $hdr -FollowRelLink)
    foreach ($issuelist in $results) {
        foreach ($issue in $issuelist) {
            if ($null -eq $issue.pull_request) {
                New-Object -type psobject -Property ([ordered]@{
                        number    = $issue.number
                        assignee  = $issue.assignee.login
                        labels    = $issue.labels.name -join ','
                        milestone = $issue.milestone.title
                        title     = $issue.title
                        html_url  = $issue.html_url
                        url       = $issue.url
                    })
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

    $repoPath = $git_repos['PowerShell-Docs'].path
    $template = Get-Content $repoPath\.github\PULL_REQUEST_TEMPLATE.md

    $pathmap = @(
        [pscustomobject]@{path = '.editorconfig'                ; line = 16 },
        [pscustomobject]@{path = '.git'                         ; line = 16 },
        [pscustomobject]@{path = '.gitattributes'               ; line = 16 },
        [pscustomobject]@{path = '.gitignore'                   ; line = 16 },
        [pscustomobject]@{path = '.localization-config'         ; line = 16 },
        [pscustomobject]@{path = '.localization-config'         ; line = 16 },
        [pscustomobject]@{path = '.markdownlint.json'           ; line = 16 },
        [pscustomobject]@{path = '.vscode'                      ; line = 16 },
        [pscustomobject]@{path = 'CONTRIBUTING.md'              ; line = 16 },
        [pscustomobject]@{path = 'LICENSE'                      ; line = 16 },
        [pscustomobject]@{path = 'README.md'                    ; line = 16 },
        [pscustomobject]@{path = 'reference/README.md'          ; line = 16 },
        [pscustomobject]@{path = 'ThirdParyNotices'             ; line = 16 },
        [pscustomobject]@{path = '.openpublishing'              ; line = 17 },
        [pscustomobject]@{path = 'build.ps1'                    ; line = 17 },
        [pscustomobject]@{path = 'ci-steps.yml'                 ; line = 17 },
        [pscustomobject]@{path = 'ci.yml'                       ; line = 17 },
        [pscustomobject]@{path = 'daily.yml'                    ; line = 17 },
        [pscustomobject]@{path = 'tests'                        ; line = 17 },
        [pscustomobject]@{path = 'tools'                        ; line = 17 },
        [pscustomobject]@{path = 'reference/bread'              ; line = 18 },
        [pscustomobject]@{path = 'reference/docfx.json'         ; line = 18 },
        [pscustomobject]@{path = 'reference/mapping'            ; line = 18 },
        [pscustomobject]@{path = 'reference/module'             ; line = 18 },
        [pscustomobject]@{path = 'assets'                       ; line = 21 },
        [pscustomobject]@{path = 'reference/docs-conceptual'    ; line = 21 },
        [pscustomobject]@{path = 'reference/includes'           ; line = 21 },
        [pscustomobject]@{path = 'reference/index.yml'          ; line = 21 },
        [pscustomobject]@{path = 'reference/media'              ; line = 21 },
        [pscustomobject]@{path = 'reference/7.3'                ; line = 27 },
        [pscustomobject]@{path = 'reference/7.2'                ; line = 28 },
        [pscustomobject]@{path = 'reference/7.1'                ; line = 29 },
        [pscustomobject]@{path = 'reference/7.0'                ; line = 30 },
        [pscustomobject]@{path = 'reference/5.1'                ; line = 31 }
    )

    $hdr = @{
        Accept        = 'application/vnd.github.raw+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = 'https://api.github.com/repos/MicrosoftDocs/PowerShell-Docs/pulls'

    function mappath {
        param($path)
        $line = 0
        foreach ($map in $pathmap) {
            if ($path.StartsWith($map.path)) { return $map.line }
        }
        $line
    }

    $currentbranch = git branch --show-current
    $defaultbranch = (git remote show upstream | findstr HEAD).split(':')[1].trim()

    $diffs = Get-GitBranchChanges $defaultbranch

    # set TOC checkboxs based on location of updated files
    foreach ($file in $diffs) {
        $line = mappath $file
        $template[$line] = $template[$line] -replace [regex]::Escape('[ ]'), '[x]'
    }

    # check all boxes in the checklist
    35..40 | ForEach-Object {
        $template[$_] = $template[$_] -replace [regex]::Escape('[ ]'), '[x]'
    }

    $comment = "$title"
    $prtitle = "$title"
    if ($null -ne $issue) {
        $comment = "Fixes #$issue - $comment"
        $prtitle = "Fixes #$issue - $prtitle"
    }
    if ($null -ne $workitemid) {
        $comment = "Fixes AB#$workitemid - $comment"
    }`

    $template[3] = "$comment`r`n"
    $tmp = $template -join "`r`n"

    $body = @{
        title = $prtitle
        body  = $tmp
        head  = "${env:GITHUB_USER}:$currentbranch"
        base  = 'staging'
    } | ConvertTo-Json

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
function New-DevOpsWorkItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$title,

        [Parameter(Mandatory = $true)]
        [string]$description,

        [int]$parentId,

        [string[]]$tags,

        [ValidateSet('Task', 'User%20Story')]
        [string]$wiType = 'User%20Story',

        [ValidateSet(
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Cmdlet Ref',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Core',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Developer',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\DSC',
            'TechnicalContent\ContentProjects',
            'TechnicalContent'
        )]
        [string]$areapath = 'TechnicalContent\Azure\Compute\Management\Config\PowerShell',

        [ArgumentCompletions(
            'TechnicalContent\Future',
            'TechnicalContent\CY2021\01_2021',
            'TechnicalContent\CY2021\02_2021',
            'TechnicalContent\CY2021\03_2021',
            'TechnicalContent\CY2021\04_2021',
            'TechnicalContent\CY2021\05_2021',
            'TechnicalContent\CY2021\06_2021',
            'TechnicalContent\CY2021\07_2021',
            'TechnicalContent\CY2021\08_2021',
            'TechnicalContent\CY2021\09_2021',
            'TechnicalContent\CY2021\10_2021',
            'TechnicalContent\CY2021\11_2021',
            'TechnicalContent\CY2021\12_2021'
        )]
        [string]$iterationpath = 'TechnicalContent\CY2021\07_2019',

        [ArgumentCompletions('sewhee', 'phwilson', 'dcoulte', 'v-dasmat')]
        [string]$assignee = 'sewhee'
    )

    $username = ' '
    $password = ConvertTo-SecureString $env:MSENG_OAUTH_TOKEN -AsPlainText -Force
    $cred = [PSCredential]::new($username, $password)

    $vsuri = 'https://dev.azure.com'
    $org = 'mseng'
    $project = 'TechnicalContent'
    $apiurl = "$vsuri/$org/$project/_apis/wit/workitems/$" + $wiType + '?api-version=5.1'

    $widata = [System.Collections.Generic.List[psobject]]::new()

    $field = New-Object -type PSObject -prop @{
        op    = 'add'
        path  = '/fields/System.Title'
        value = $title
    }
    $widata.Add($field)

    $field = New-Object -type PSObject -prop @{
        op    = 'add'
        path  = '/fields/System.AreaPath'
        value = $areapath
    }
    $widata.Add($field)

    $field = New-Object -type PSObject -prop @{
        op    = 'add'
        path  = '/fields/System.IterationPath'
        value = $iterationpath
    }
    $widata.Add($field)

    if ($parentId -ne 0) {
        $field = New-Object -type PSObject -prop @{
            op    = 'add'
            path  = '/relations/-'
            value = @{
                rel = 'System.LinkTypes.Hierarchy-Reverse'
                url = "$vsuri/$org/$project/_apis/wit/workitems/$parentId"
            }
        }
        $widata.Add($field)
    }

    if ($tags.count -ne 0) {
        $field = New-Object -type PSObject -prop @{
            op    = 'add'
            path  = '/fields/System.Tags'
            value = $tags -join '; '
        }
        $widata.Add($field)
    }

    $field = New-Object -type PSObject -prop @{
        op    = 'add'
        path  = '/fields/System.AssignedTo'
        value = $assignee + '@microsoft.com'
    }
    $widata.Add($field)

    $field = New-Object -type PSObject -prop @{
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
    #$params
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
function Import-GitHubIssueToTFS {
    param(
        [Parameter(Mandatory = $true)]
        [uri]$issueurl,

        [ArgumentCompletions(
            'TechnicalContent\Carmon Mills Org',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Cmdlet Ref',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Core',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Developer',
            'TechnicalContent\Azure\Compute\Management\Config\PowerShell\DSC'
        )]
        [string]$areapath = 'TechnicalContent\Azure\Compute\Management\Config\PowerShell',

        [ArgumentCompletions(
            'TechnicalContent\Future',
            'TechnicalContent\CY2021\01_2021',
            'TechnicalContent\CY2021\02_2021',
            'TechnicalContent\CY2021\03_2021',
            'TechnicalContent\CY2021\04_2021',
            'TechnicalContent\CY2021\05_2021',
            'TechnicalContent\CY2021\06_2021',
            'TechnicalContent\CY2021\07_2021',
            'TechnicalContent\CY2021\08_2021',
            'TechnicalContent\CY2021\09_2021',
            'TechnicalContent\CY2021\10_2021',
            'TechnicalContent\CY2021\11_2021',
            'TechnicalContent\CY2021\12_2021'
        )]
        [string]$iterationpath = 'TechnicalContent\Future',

        [ArgumentCompletions('sewhee', 'phwilson')]
        [string]$assignee = 'sewhee'
    )

    function GetIssue {
        param(
            [Parameter(ParameterSetName = 'bynamenum', Mandatory = $true)]
            [string]$repo,
            [Parameter(ParameterSetName = 'bynamenum', Mandatory = $true)]
            [int]$num,

            [Parameter(ParameterSetName = 'byurl', Mandatory = $true)]
            [uri]$issueurl
        )
        $hdr = @{
            Accept        = 'application/vnd.github.v3+json'
            Authorization = "token ${Env:\GITHUB_TOKEN}"
        }
        if ($issueurl -ne '') {
            $repo = ($issueurl.Segments[1..2] -join '').trim('/')
            $issuename = $issueurl.Segments[1..4] -join ''
            $num = $issueurl.Segments[-1]
        }

        $apiurl = "https://api.github.com/repos/$repo/issues/$num"
        $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
        $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
        $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | Select-Object -ExpandProperty body
        $retval = New-Object -TypeName psobject -Property ([ordered]@{
                number     = $issue.number
                name       = $issuename
                url        = $issue.html_url
                created_at = $issue.created_at
                assignee   = $issue.assignee.login
                title      = '[GitHub #{0}] {1}' -f $issue.number, $issue.title
                labels     = $issue.labels.name
                body       = $issue.body
                comments   = $comments -join "`n"
            })
        $retval
    }

    $issue = GetIssue -issueurl $issueurl
    $description = "Issue: <a href='{0}'>{1}</a><BR>" -f $issue.url, $issue.name
    $description += 'Created: {0}<BR>' -f $issue.created_at
    $description += 'Labels: {0}<BR>' -f ($issue.labels -join ',')
    if ($issue.body -match 'Content Source: \[(.+)\]') {
        $description += 'Document: {0}<BR>' -f $matches[1]
    }

    $wiParams = @{
        title         = $issue.title
        description   = $description
        parentId      = 1669514
        areapath      = $areapath
        iterationpath = $iterationpath
        wiType        = 'User%20Story'
        assignee      = $assignee
    }
    $result = New-DevOpsWorkItem @wiParams

    $prcmd = 'New-PrFromBranch -work {0} -issue {1} -title $lastcommit' -f $result.id, $issue.number
    $result
    $prcmd
}
#-------------------------------------------------------
function New-MergeToLive {
    $hdr = @{
        Accept        = 'application/vnd.github.shadow-cat-preview+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = 'https://api.github.com/repos/MicrosoftDocs/PowerShell-Docs/pulls'
    $params = @{
        title = 'Publish to live'
        body  = 'Publishing latest changes to live'
        head  = 'staging'
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
function New-IssueBranch {
    param(
        [string]$id,
        [switch]$createworkitem
    )

    try {
        0 + $id | Out-Null
        $prefix = 'sdw-i'
    }
    catch {
        $prefix = 'sdw-'
    }

    git.exe checkout -b $prefix$id

    if ($createworkitem) {
        $yyyy = (Get-Date).year
        $mm = '{0:d2}' -f (Get-Date).month
        $params = @{
            assignee      = 'sewhee'
            areapath      = 'TechnicalContent\Azure\Compute\Management\Config\PowerShell'
            iterationpath = "TechnicalContent\CY$yyyy\${mm}_$yyyy"
            issueurl      = "https://github.com/MicrosoftDocs/PowerShell-Docs/issues/$id"
        }
        Import-GitHubIssueToTFS @params
    }

}
Set-Alias nib new-issuebranch
#-------------------------------------------------------
#endregion
