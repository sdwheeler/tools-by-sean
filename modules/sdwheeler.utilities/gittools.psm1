#-------------------------------------------------------
#region Git Functions
function get-myrepos {
    $my_repos = @{}
    foreach ($repoRoot in $gitRepoRoots) {
      Get-ChildItem $repoRoot -Directory | ForEach-Object {

        $dir = $_.fullname
        push-location $dir

        $gitStatus = Get-GitStatus
        if ($gitStatus) {
          $gitDir = get-item $gitStatus.gitdir -Force
          $repoName = $gitDir.parent.name
        }

        $arepo = New-Object -TypeName psobject -Property ([ordered]@{
            id = ''
            name = $repoName
            organization = ''
            private = ''
            default_branch = ''
            html_url = ''
            description = ''
            path = $dir
            remote = $null
        })

        $remotes = @{}

        git.exe remote -v | Select-String '(fetch)' | ForEach-Object {
          $r = ($_ -replace ' \(fetch\)') -split "`t"
          $remotes.Add($r[0],$r[1])
        }
        $arepo.remote = new-object -type psobject -prop $remotes
        if ($remotes.upstream) {
          $arepo.organization = ($remotes.upstream -split '/')[3]
        } else {
          $arepo.organization = ($remotes.origin -split '/')[3]
        }
        $arepo.id = '{0}/{1}' -f $arepo.organization,$arepo.name

        $my_repos.Add($repoName,$arepo)
        pop-location
      }
    }

    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }

    foreach ($repo in $my_repos.Keys) {
      $apiurl = $my_repos[$repo].remote.origin -replace 'github.com/','api.github.com/repos/'
      $apiurl = $apiurl -replace '\.git$',''

      $gitrepo = Invoke-RestMethod $apiurl -Headers $hdr
      $my_repos[$repo].private = $gitrepo.private
      $my_repos[$repo].default_branch = $gitrepo.default_branch
      $my_repos[$repo].html_url = $gitrepo.html_url
      $my_repos[$repo].description = $gitrepo.description
    }

    $global:git_repos = $my_repos
    '{0} repos found.' -f $global:git_repos.Count
}
#-------------------------------------------------------
function sync-branch {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
      if ($gitStatus.HasIndex -or $gitStatus.HasUntracked) {
        write-host ('='*20)
        "Skipping  - {0} has uncommitted changes." -f $gitStatus.Branch
        write-host ('='*20)
      } else {
        write-host ('='*20)
        git.exe pull upstream ($gitStatus.Branch)
        write-host ('-'*20)
        git.exe push origin ($gitStatus.Branch)
      }
    } else {
      write-host ('='*20)
      "Skipping $pwd - not a repo."
      write-host ('='*20)
    }
}
#-------------------------------------------------------
function sync-repo {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
      $gitDir = get-item $gitStatus.gitdir -Force
      $repoName = $gitDir.parent.name
      $repo = $git_repos[$reponame]
      write-host ('='*20)
      write-host ('Syncing {0}/{1} [{2}]' -f $repo.organization, $reponame, $repo.default_branch)
      if ($gitStatus.Branch -ne $repo.default_branch) {
        write-host ('='*20)
        "Skipping $pwd - default branch not checked out."
        write-host ('='*20)
      } else {
        if ($repo.remote.upstream) {
          write-host ('='*20)
          git.exe fetch upstream
          write-host ('-'*20)
          git.exe pull upstream ($repo.default_branch)
          write-host ('-'*20)
          git.exe push origin ($repo.default_branch)
        } else {
          write-host ('='*20)
          'No upstream defined -  pulling from origin'
          git.exe pull origin ($repo.default_branch)
        }
      }
    } else {
      write-host ('='*20)
      "Skipping $pwd - not a repo."
      write-host ('='*20)
    }
}
#-------------------------------------------------------
function sync-all {
    $reposlist = dir -dir -Hidden .git -rec | Select-Object -exp parent | Select-Object -exp fullname
    if ($reposlist) {
      $reposlist | ForEach-Object{
        Push-Location $_
        sync-repo
        Pop-Location
      }
    } else {
      'No repos found.'
    }
}
Set-Alias syncall sync-all
#-------------------------------------------------------
function kill-branch {
    param([string[]]$branch)
    if ($branch) {
      $branch | ForEach-Object {
        git.exe branch -D $_
        git.exe branch -Dr origin/$_
        git.exe push origin --delete $_
      }
    }
}
#-------------------------------------------------------
function show-diffs {
    $repo=((Get-GitStatus).gitdir -split '\\')[-2]
    $default_branch = $git_repos[$repo].default_branch
    $current_branch = (Get-GitStatus).branch
    git.exe diff --name-only $default_branch $current_branch | %{ $_ }
}
#-------------------------------------------------------
function show-repo {
    [CmdletBinding(DefaultParameterSetName='reponame')]
    param(
      [Parameter(ParameterSetName='reponame',
          Position = 0,
      ValueFromPipelineByPropertyName=$true)]
      [alias('name')]
      [string]$repo,

      [Parameter(ParameterSetName='orgname',Mandatory=$true)]
      [alias('org')]
      [string]$organization
    )
    process {
      if ($organization) {
        $git_repos.keys | %{ $git_repos[$_] | Where-Object organization -eq $organization }
      } elseif ($repo) {
        $git_repos.keys | Where-Object {$_ -like $repo} | %{ $git_repos[$_] }
      } else {
        $repo = ($GitStatus.GitDir -split '\\')[-2]
        $git_repos.keys | Where-Object {$_ -like $repo} | %{ $git_repos[$_] }
      }
    }
}
#-------------------------------------------------------
function show-branches {
    $reposlist = dir -dir -Hidden .git -rec | select -exp parent | select -exp fullname
    if ($reposlist) {
      $reposlist | ForEach-Object{
        Push-Location $_
        "`n{0}" -f $pwd.Path
        git branch -v | sort
        Pop-Location
      }
    } else {
      'No repos found.'
    }
}
#-------------------------------------------------------
function get-branchstatus {
    Write-Host ''
    $git_repos.keys | Sort-Object | %{
      Push-Location $git_repos[$_].path
      if ((Get-GitStatus).Branch -eq $git_repos[$_].default_branch) {
        $default = 'default'
        $fgcolor = [consolecolor]::Cyan
      } else {
        $default = 'working'
        $fgcolor = [consolecolor]::Red
      }
      Write-Host "$_ (" -nonewline
      Write-Host $default -ForegroundColor $fgcolor -nonewline
      Write-Host ")" -nonewline
      Write-VcsStatus
      Write-Host ''
      Pop-Location
    }
    Write-Host ''
}
#-------------------------------------------------------
function checkout {
    param([string]$branch)

    if ($branch -eq '') {
      $repo=((Get-GitStatus).gitdir -split '\\')[-2]
      $branch = $git_repos[$repo].default_branch
    }
    git checkout $branch
}
#-------------------------------------------------------
function getReponame {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
      $gitDir = get-item $gitStatus.gitdir -Force
      write-output $gitDir.parent.name
    }
}
#-------------------------------------------------------
function goto-remote {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
      $gitDir = get-item $gitStatus.gitdir -Force
      $repoName = $gitDir.parent.name
      $repo = $git_repos[$reponame]
      if ($repo) {
        start-process $repo.remote.origin
      }
    } else {
      'Not a git repo.'
    }
}
#-------------------------------------------------------
function goto-myprlist {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
      $gitDir = get-item $gitStatus.gitdir -Force
      $repoName = $gitDir.parent.name
      $repo = $git_repos[$reponame]
      if ($repo) {
        if ($repo.remote.upstream -ne $null) {
          $repoURL = $repo.remote.upstream -replace '\.git', ''
          start-process "$repoURL/pulls/$env:GITHUB_USERNAME"
        } else {
          "Remote 'upstream' not found."
        }
      }
    } else {
      'Not a git repo.'
    }
}
#-------------------------------------------------------
function goto-repo {
    param($reponame = '.')

    if ($reponame -eq '.') {
      $reponame = getReponame
    }
    $repo = $git_repos[$reponame]
    if ($repo) {
      if ($repo.remote.upstream) {
        start-process $repo.remote.upstream
      } else {
        start-process $repo.remote.origin
      }
    } else {
      'Not a git repo.'
    }
}
#-------------------------------------------------------
function goto-fork {
    param($reponame = '.')

    if ($reponame -eq '.') {
      $reponame = getReponame
    }
    $repo = $git_repos[$reponame]
    if ($repo) {
      if ($repo.remote.origin) {
        start-process $repo.remote.origin
      } else {
        'No fork found.'
      }
    } else {
      'Not a git repo.'
    }
}
#-------------------------------------------------------
function list-myprs {
    param(
      [string]$startdate,
      [string]$enddate,
      [string]$username = $env:GITHUB_USERNAME
    )
    if ($startdate -eq '' -or $enddate -eq '') {
      $current = get-date
      $startdate = '{0}-{1:d2}-{2:d2}' -f $current.Year, $current.Month, 1
      $enddate = '{0}-{1:d2}-{2:d2}' -f $current.Year, $current.Month, [datetime]::DaysInMonth($current.year,$current.month)
    }
    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    $query = "q=is:pr+involves:$username+updated:$startdate..$enddate"

    $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr
    $prlist.items | ForEach-Object{
      $files = $(Invoke-RestMethod ($_.pull_request.url + '/files?per_page=100') -Headers $hdr ) | Select-Object -ExpandProperty filename
      $events = $(Invoke-RestMethod ($_.url + '/events') -Headers $hdr)
      $merged = $events | Where-Object event -eq 'merged' | Select-Object -exp created_at
      $closed = $events | Where-Object event -eq 'closed' | Select-Object -exp created_at
      $pr = $_ | Select-Object number,html_url,@{l='merged';e={$merged}},@{l='closed';e={$closed}},state,title,@{l='filecount'; e={$files.count}},@{l='files'; e={$files -join "`r`n"} }
      $pr
    }
}
#-------------------------------------------------------
function get-issue {
    param(

      [Parameter(Position = 0,
      Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [uri]$issueurl
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    if ($issueurl -ne '') {
      $repo = ($issueurl.Segments[1..2]) -join ''
      $repo = $repo.Substring(0,($repo.length-1))
      $num = $issueurl.Segments[-1]
    }

    $apiurl = "https://api.github.com/repos/$repo/issues/$num"
    $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
    $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | select -ExpandProperty body
    $retval = New-Object -TypeName psobject -Property ([ordered]@{
        number = $issue.number
        url=$issue.html_url
        created_at=$issue.created_at
        assignee=$issue.assignee.login
        title=$issue.title
        labels=$issue.labels.name
        body=$issue.body
        comments=$comments -join "`n"
    })
    $retval
}
#-------------------------------------------------------
function list-issues {
    param(
      [ValidateSet("azure/azure-docs-powershell","azure/azure-docs-powershell-samples","azure/azure-powershell","azure/azure-powershell-pr","powershell/platyps","powershell/powershell","powershell/powershell-docs","powershell/powershell-rfc","powershell/powershellget", ignorecase=$true)]
      $reponame,
      $pagesize=200
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3.raw+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$reponame/issues?per_page=$pagesize"
    $i = (Invoke-RestMethod $apiurl -Headers $hdr) | where pull_request -eq $null | select number,@{l='assignee';e={$_.assignee.login}},title,html_url,url
    $i | sort assignee
}
#-------------------------------------------------------
