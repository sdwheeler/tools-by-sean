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
            host = ''
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
          if ($repo.remote.upstream -eq $repo.remote.origin) {
            git.exe fetch origin
          } else {
            git.exe push origin ($repo.default_branch)
          }
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
        $b = $_.Trim()
        git.exe branch -D $b
        git.exe branch -Dr origin/$b
        git.exe push origin --delete $b
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
        git branch | sort
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
function get-prlist {
  param(
    [string]$start,
    [string]$end
  )
  if ($start -eq '') {
      $startdate = get-date -Format 'yyyy-MM-dd'
  } else {
      $startdate = get-date $start -Format 'yyyy-MM-dd'
  }
  if ($end -eq '') {
      $current = get-date $start
      $enddate = '{0}-{1:d2}-{2:d2}' -f $current.Year, $current.Month, [datetime]::DaysInMonth($current.year,$current.month)
  }
  $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }
  $query = "q=type:pr+is:merged+repo:powershell/powershell-docs+merged:$startdate..$enddate"

  $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr  -follow
  $prlist.items | ForEach-Object{
      $files = $(Invoke-RestMethod ($_.pull_request.url + '/files?per_page=100') -Headers $hdr ) | Select-Object -ExpandProperty filename
      $events = $(Invoke-RestMethod ($_.url + '/events') -Headers $hdr)
      $merged = $events | Where-Object event -eq 'merged' | Select-Object -exp created_at
      $closed = $events | Where-Object event -eq 'closed' | Select-Object -exp created_at
      $pr = $_ | Select-Object number,html_url,
      @{l='merged';e={$merged}},
      @{l='closed';e={$closed}},
      @{l='opened_by';e={$_.user.login}},
      state,title,
      @{l='filecount'; e={$files.count}}
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
function get-issuelist {
    param(
      [ValidateSet("azure/azure-docs-powershell","azure/azure-docs-powershell-samples","azure/azure-powershell","azure/azure-powershell-pr","powershell/platyps","powershell/powershell","powershell/powershell-docs","powershell/powershell-rfc","powershell/powershellget", ignorecase=$true)]
      $reponame
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3.raw+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$reponame/issues"
    $results = (Invoke-RestMethod $apiurl -Headers $hdr -FollowRelLink) | where pull_request -eq $null
    foreach ($issuelist in $results) {
      foreach ($issue in $issuelist) {
        New-Object -type psobject -Property ([ordered]@{
          number = $issue.number
          assignee = $issue.assignee.login
          labels = $issue.labels.name -join ','
          title = $issue.title
          html_url = $issue.html_url
          url = $issue.url
        })
      }
    }
}
#-------------------------------------------------------
function get-repostatus {
  $hdr = @{
    Accept = 'application/vnd.github.VERSION.full+json'
    Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }

  $repos = 'PowerShell/PowerShell-Docs','MicrosoftDocs/docs-powershell','MicrosoftDocs/powershell-sdk-samples','MicrosoftDocs/powershell-docs-sdk-dotnet'
  foreach ($repo in $repos) {
    $apiurl = 'https://api.github.com/repos/{0}/issues' -f $repo
    $list = irm $apiurl -header $hdr -follow
    $prs = $list | %{ $_ | where pull_request -ne $null }
    $issues = $list | %{ $_ | where pull_request -eq $null }
    new-object -type psobject -prop ([ordered]@{
      repo = $repo
      issuecount = $issues.count
      prcount = $prs.count
    })
  }
}
#-------------------------------------------------------
# Get issues closed this month
function get-issuehistory {
  param(
    [Parameter(Mandatory=$true)]
    [datetime]$startdate
  )

  $nextmonth = $startdate.AddMonths(1)
  $hdr = @{
    Accept = 'application/vnd.github.symmetra-preview+json'
    Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }
  $i = irm 'https://api.github.com/repos/PowerShell/PowerShell-docs/issues?state=all&since=2018-01-01' -head $hdr -follow
  $x = $i | %{ $_ |where pull_request -eq $null | select number,state,created_at,closed_at,@{n='user'; e={$_.user.login}},title }
  #$x.count
  $x | where {
    $_.created_at -lt $nextmonth -and (($_.closed_at -ge $startdate) -or ($null -eq $_.closed_at))
  } | export-csv C:\temp\issues.csv
  ii  C:\temp\issues.csv
}
#-------------------------------------------------------
function Import-GitHubIssueToTFS {
  param(
    [Parameter(Mandatory=$true)]
    [uri]$issueurl,

    [ValidateSet('TechnicalContent\AzMgmtMon-SC-PS-AzLangs',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Advisor',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\App Insights',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Automation',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Backup',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Governance',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Log Analytics',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Migrate',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Monitoring',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Site Recovery',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Operations Mgmt Suite\Solutions',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell\AzurePS',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell\Cmdlet Ref',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell\Core',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell\Developer',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell\DSC',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\Config Mgr 2012',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\Config Mgr 2016',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\DPM',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\Operations Mgr',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\Orchestrator',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\Service Management Automation',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\Service Manager',
      'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\System Center\VMM'
      )]
    [string]$areapath='TechnicalContent\AzMgmtMon-SC-PS-AzLangs\PowerShell',

    [ValidateSet(
      'TechnicalContent\CY2018\Future',
      'TechnicalContent\CY2018\12_2018',
      'TechnicalContent\CY2019\Future',
      'TechnicalContent\CY2019\01_2019',
      'TechnicalContent\CY2019\02_2019',
      'TechnicalContent\CY2019\03_2019',
      'TechnicalContent\CY2019\04_2019',
      'TechnicalContent\CY2019\05_2019',
      'TechnicalContent\CY2019\06_2019',
      'TechnicalContent\CY2019\07_2019',
      'TechnicalContent\CY2019\08_2019',
      'TechnicalContent\CY2019\09_2019',
      'TechnicalContent\CY2019\10_2019',
      'TechnicalContent\CY2019\11_2019',
      'TechnicalContent\CY2019\12_2019'
      )]
    [string]$iterationpath='TechnicalContent\CY2019\Future',

    [ValidateSet('Sean Wheeler','Bobby Reed','David Coulter','George Wallace','David Smatlak')]
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
#-------------------------------------------------------
function get-prfiles {
  param($num)
  $hdr = @{
    Accept = 'application/vnd.github.VERSION.full+json'
    Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }

  $pr = irm "https://api.github.com/repos/PowerShell/PowerShell-Docs/pulls/$num" -method GET -head $hdr
  $commits = irm $pr.commits_url -head $hdr
  $commits | %{
    $commit = irm $_.url -head $hdr
    $commit.files | select status,changes,filename,previous_filename
  }  | sort status,filename -unique
}
