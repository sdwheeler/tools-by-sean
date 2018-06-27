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
      Write-Verbose $my_repos[$repo].id
      $apiurl = $my_repos[$repo].remote.origin -replace 'github.com/','api.github.com/repos/'
      $apiurl = $apiurl -replace '\.git$',''

      try {
        $gitrepo = Invoke-RestMethod $apiurl -Headers $hdr -ea Stop
        $my_repos[$repo].private = $gitrepo.private
        $my_repos[$repo].default_branch = $gitrepo.default_branch
        $my_repos[$repo].html_url = $gitrepo.html_url
        $my_repos[$repo].description = $gitrepo.description
      } catch {
        Write-Host ('{0}: [Error] {1}' -f $my_repos[$repo].id,$_.exception.message)
        $Error.Clear()
      }
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
  foreach ($reporoot in $gitRepoRoots) {
    $reposlist = dir $reporoot -dir -Hidden .git -rec -depth 2 |
      Select-Object -exp parent | Select-Object -exp fullname
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
    param(
      $reponame = '.',
      [switch]$fork
    )

    if ($reponame -eq '.') {
      $reponame = getReponame
    }
    $repo = $git_repos[$reponame]
    if ($repo) {
      if ($fork) {
        start-process $repo.remote.origin
      } else {
        if ($repo.remote.upstream) {
          start-process $repo.remote.upstream
        } else {
          start-process $repo.remote.origin
        }
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
function Import-GitHubIssueToTFS {
  param(
    [Parameter(Mandatory=$true)]
    [uri]$issueurl,

    [ValidateSet('TechnicalContent\OMS-SC-PS',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Advisor',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\App Insights',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Automation',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Backup',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Governance',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Log Analytics',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Migrate',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Monitoring',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Site Recovery',
      'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Solutions',
      'TechnicalContent\OMS-SC-PS\PowerShell',
      'TechnicalContent\OMS-SC-PS\PowerShell\AzurePS',
      'TechnicalContent\OMS-SC-PS\PowerShell\Cmdlet Ref',
      'TechnicalContent\OMS-SC-PS\PowerShell\Core',
      'TechnicalContent\OMS-SC-PS\PowerShell\Developer',
      'TechnicalContent\OMS-SC-PS\PowerShell\DSC',
      'TechnicalContent\OMS-SC-PS\System Center',
      'TechnicalContent\OMS-SC-PS\System Center\Config Mgr 2012',
      'TechnicalContent\OMS-SC-PS\System Center\Config Mgr 2016',
      'TechnicalContent\OMS-SC-PS\System Center\DPM',
      'TechnicalContent\OMS-SC-PS\System Center\Operations Mgr',
      'TechnicalContent\OMS-SC-PS\System Center\Orchestrator',
      'TechnicalContent\OMS-SC-PS\System Center\Service Management Automation',
      'TechnicalContent\OMS-SC-PS\System Center\Service Manager',
      'TechnicalContent\OMS-SC-PS\System Center\VMM'
      )]
    [string]$areapath='TechnicalContent\OMS-SC-PS\PowerShell',

    [ValidateSet('TechnicalContent\CY2018\Future',
      'TechnicalContent\CY2018\06_2018',
      'TechnicalContent\CY2018\07_2018',
      'TechnicalContent\CY2018\08_2018',
      'TechnicalContent\CY2018\09_2018',
      'TechnicalContent\CY2018\10_2018',
      'TechnicalContent\CY2018\11_2018',
      'TechnicalContent\CY2018\12_2018',
      'TechnicalContent\CY2019\01_2019',
      'TechnicalContent\CY2019\02_2019',
      'TechnicalContent\CY2019\03_2019',
      'TechnicalContent\CY2019\04_2019',
      'TechnicalContent\CY2019\05_2019',
      'TechnicalContent\CY2019\06_2019'
      )]
    [string]$iterationpath='TechnicalContent\CY2018\Future',

    [ValidateSet('Sean Wheeler','Bobby Reed','David Coulter','George Wallace')]
    [string]$assignee='Sean Wheeler'
  )

  if (!(Test-Path Env:\GITHUB_OAUTH_TOKEN)) {
    Write-Error "Error: missing Env:\GITHUB_OAUTH_TOKEN"
    exit
  }

  # load the required dll
  $dllpath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
  Add-Type -path "$dllpath\Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
  Add-Type -path "$dllpath\Microsoft.TeamFoundation.Client.dll"

  $vsourl = "https://mseng.visualstudio.com"

  function GetIssue {
    param(
      [Parameter(ParameterSetName='bynamenum',Mandatory=$true)]
      [string]$repo,
      [Parameter(ParameterSetName='bynamenum',Mandatory=$true)]
      [int]$num,

      [Parameter(ParameterSetName='byurl',Mandatory=$true)]
      [uri]$issueurl
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    if ($issueurl -ne '') {
      $repo = ($issueurl.Segments[1..2] -join '').trim('/')
      $issuename = $issueurl.Segments[1..4] -join ''
      $num = $issueurl.Segments[-1]
    }

    $apiurl = "https://api.github.com/repos/$repo/issues/$num"
    $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
    $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | select -ExpandProperty body
    $retval = New-Object -TypeName psobject -Property ([ordered]@{
        number = $issue.number
        name = $issuename
        url=$issue.html_url
        created_at=$issue.created_at
        assignee=$issue.assignee.login
        title='[GitHub #{0}] {1}' -f $issue.number,$issue.title
        labels=$issue.labels.name
        body=$issue.body
        comments=$comments -join "`n"
    })
    $retval
  }


  $issue = GetIssue -issueurl $issueurl
  if ($issue) {
    $description = "Issue: <a href='{0}'>{1}</a><BR>" -f $issue.url,$issue.name
    $description += "Created: {0}<BR>" -f $issue.created_at
    $description += "Labels: {0}<BR>" -f ($issue.labels -join ',')
    $description += "Description:<BR>{0}<BR>" -f ($issue.body -replace '\n','<BR>')
    $description += "Comments:<BR>{0}" -f ($issue.comments -replace '\n','<BR>')

    $vsts = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($vsourl)
    $WIStore=$vsts.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
    $project=$WIStore.Projects["TechnicalContent"]

    #Create Task
    $type=$project.WorkItemTypes["Task"]
    $item = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItem $type
    $item.Title = $issue.title
    $item.AreaPath = $areapath
    $item.IterationPath = $iterationpath
    $item.Description = $description
    $item.Fields['Assigned To'].Value = $assignee
    $item.save()
    $item | select Id,AreaPath,IterationPath,@{n='AssignedTo';e={$_.Fields['Assigned To'].Value}},Title,Description
  } else {
    Write-Error "Error: unable to retrieve issue."
  }
}