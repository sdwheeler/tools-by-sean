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

        if ($my_repos.ContainsKey($repoName)) {
          Write-Warning "Duplicate repo - $repoName"
          $arepo
        } else {
          $my_repos.Add($repoName,$arepo)
        }
        pop-location
      }
    }

    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }

    foreach ($repo in $my_repos.Keys) {
      Write-Verbose $my_repos[$repo].id

      switch ($my_repos[$repo].host) {
        'github' {
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
#-------------------------------------------------------
function getReponame {
  $gitStatus = Get-GitStatus
  if ($gitStatus) {
    $gitDir = get-item $gitStatus.gitdir -Force
    write-output $gitDir.parent.name
  }
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
function sync-branch {
    $gitStatus = Get-GitStatus
    $repo = show-repo
    if ($gitStatus) {
      if ($gitStatus.HasIndex -or $gitStatus.HasUntracked) {
        write-host ('='*20) -Fore DarkCyan
        write-host ("Skipping  - {0} has uncommitted changes." -f $gitStatus.Branch) -Fore Yellow
        write-host ('='*20) -Fore DarkCyan
      } else {
        write-host ('='*20) -Fore DarkCyan
        if ($repo.remote.upstream) {
          git.exe pull upstream ($gitStatus.Branch)
          if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red}
          write-host ('-'*20) -Fore DarkCyan
          git.exe push origin ($gitStatus.Branch)
          if (!$?) { Write-Host 'Error pushing to origin' -Fore Red}
        } else {
          git.exe pull origin ($gitStatus.Branch)
          if (!$?) { Write-Host 'Error pulling from origin' -Fore Red}
        }
      }
    } else {
      write-host ('='*20) -Fore DarkCyan
      write-host "Skipping $pwd - not a repo." -Fore Yellow
      write-host ('='*20) -Fore DarkCyan
    }
}
#-------------------------------------------------------
function sync-repo {
    $gitStatus = Get-GitStatus
    if ($gitStatus) {
      $gitDir = get-item $gitStatus.gitdir -Force
      $repoName = $gitDir.parent.name
      $repo = $git_repos[$reponame]
      write-host ('='*20) -Fore DarkCyan
      write-host ('Syncing {0}/{1} [{2}]' -f $repo.organization, $reponame, $repo.default_branch) -Fore DarkCyan
      if ($gitStatus.Branch -ne $repo.default_branch) {
        write-host ('='*20) -Fore DarkCyan
        write-host "Skipping $pwd - default branch not checked out." -Fore Yellow
        write-host ('='*20) -Fore DarkCyan
      } else {
        if ($repo.remote.upstream) {
          write-host ('='*20) -Fore DarkCyan
          git.exe fetch upstream
          if (!$?) { Write-Host 'Error fetching from upstream' -Fore Red}
          write-host ('-'*20) -Fore DarkCyan
          git.exe pull upstream ($repo.default_branch)
          if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red}
          write-host ('-'*20) -Fore DarkCyan
          if ($repo.remote.upstream -eq $repo.remote.origin) {
            git.exe fetch origin
            if (!$?) { Write-Host 'Error fetching from origin' -Fore Red}
          } else {
            git.exe push origin ($repo.default_branch)
            if (!$?) { Write-Host 'Error pushing to origin' -Fore Red}
          }
        } else {
          write-host ('='*20) -Fore DarkCyan
          write-host 'No upstream defined -  pulling from origin' -Fore Yellow
          git.exe pull origin ($repo.default_branch)
          if (!$?) { Write-Host 'Error pulling from origin' -Fore Red}
        }
      }
    } else {
      write-host ('='*20) -Fore DarkCyan
      write-host "Skipping $pwd - not a repo." -Fore Red
      write-host ('='*20) -Fore DarkCyan
    }
}
#-------------------------------------------------------
function sync-all {
  foreach ($reporoot in $gitRepoRoots) {
    $reposlist = Get-ChildItem $reporoot -dir -Hidden .git -rec -depth 2 |
      Select-Object -exp parent | Select-Object -exp fullname
    if ($reposlist) {
      $reposlist | ForEach-Object{
        Push-Location $_
        sync-repo
        Pop-Location
      }
    } else {
      write-host 'No repos found.' -Fore Red
    }
  }
}
Set-Alias syncall sync-all
#-------------------------------------------------------
function kill-branch {
    param(
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
      [string[]]$branch
    )
    process {
    if ($branch) {
      $branch | ForEach-Object {
        $b = $_.Trim()
        git.exe branch -D $b
        git.exe branch -Dr origin/$b
        git.exe push origin --delete $b
      }
    }
  }
}
#-------------------------------------------------------
function show-diffs {
    $repo=((Get-GitStatus).gitdir -split '\\')[-2]
    $default_branch = $git_repos[$repo].default_branch
    $current_branch = (Get-GitStatus).branch
    git.exe diff --name-only $default_branch $current_branch | ForEach-Object{ $_ }
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
        $git_repos.keys | ForEach-Object{ $git_repos[$_] | Where-Object organization -eq $organization }
      } elseif ($repo) {
        $git_repos.keys | Where-Object {$_ -like $repo} | ForEach-Object{ $git_repos[$_] }
      } else {
        $repo = ($GitStatus.GitDir -split '\\')[-2]
        $git_repos.keys | Where-Object {$_ -like $repo} | ForEach-Object{ $git_repos[$_] }
      }
    }
}
#-------------------------------------------------------
function show-branches {
    $reposlist = Get-ChildItem -dir -Hidden .git -rec | Select-Object -exp parent | Select-Object -exp fullname
    if ($reposlist) {
      $reposlist | ForEach-Object{
        Push-Location $_
        "`n{0}" -f $pwd.Path
        git branch | Sort-Object
        Pop-Location
      }
    } else {
      'No repos found.'
    }
}
#-------------------------------------------------------
function get-branchstatus {
    Write-Host ''
    $git_repos.keys | Sort-Object | ForEach-Object{
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
#endregion
#-------------------------------------------------------
#region Git queries
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
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | Select-Object -ExpandProperty body
    $retval = New-Object -TypeName psobject -Property ([ordered]@{
        title='[GitHub #{0}] {1}' -f $issue.number,$issue.title
        url=$issue.html_url
        created_at=$issue.created_at
        state=$issue.state
        assignee=$issue.assignee.login
        labels=$issue.labels.name
        body=$issue.body
        comments=$comments -join "`n"
    })
    $retval
}
#-------------------------------------------------------
function get-issuelist {
    param(
      [ValidateSet("azure/azure-docs-powershell","azure/azure-docs-powershell-samples","azure/azure-powershell","azure/azure-powershell-pr","powershell/platyps","powershell/powershell","MicrosoftDocs/PowerShell-Docs","powershell/powershell-rfc","powershell/powershellget", ignorecase=$true)]
      $reponame="MicrosoftDocs/PowerShell-Docs"
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3.raw+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    $apiurl = "https://api.github.com/repos/$reponame/issues"
    $results = (Invoke-RestMethod $apiurl -Headers $hdr -FollowRelLink)
    foreach ($issuelist in $results) {
      foreach ($issue in $issuelist) {
        if (null -eq $issue.pull_request) {
          New-Object -type psobject -Property ([ordered]@{
            number = $issue.number
            assignee = $issue.assignee.login
            labels = $issue.labels.name -join ','
            milestone = $issue.milestone.title
            title = $issue.title
            html_url = $issue.html_url
            url = $issue.url
          })
        }
      }
    }
}
#-------------------------------------------------------
function get-repostatus {
  $hdr = @{
    Accept = 'application/vnd.github.VERSION.full+json'
    Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }
  $status = @()
  $repos = 'MicrosoftDocs/PowerShell-Docs','MicrosoftDocs/PowerShell-Docs-archive',
           'MicrosoftDocs/windows-powershell-docs','MicrosoftDocs/powershell-sdk-samples',
           'MicrosoftDocs/powershell-docs-sdk-dotnet', 'Azure-Samples/azure-cli-samples',
           'Azure/azure-docs-powershell-samples', 'Azure/azure-docs-powershell',
           'Azure/azure-powershell'
  foreach ($repo in $repos) {
    $apiurl = 'https://api.github.com/repos/{0}' -f $repo
    $ghrepo = Invoke-RestMethod $apiurl -header $hdr
    $prlist = Invoke-RestMethod ($apiurl+'/pulls') -header $hdr -follow
    $count = 0
    if ($prlist[0].count -eq 1) {
      $count = $prlist.count
    } else {
      $prlist | ForEach-Object{ $count += $_.count }
    }
    $status += new-object -type psobject -prop ([ordered]@{
      repo = $repo
      issuecount = $ghrepo.open_issues - $count
      prcount = $count
    })
  }
  $status
}

#-------------------------------------------------------
function Import-GitHubIssueToTFS {
  param(
    [Parameter(Mandatory=$true)]
    [uri]$issueurl,

    [ValidateSet(
      'TechnicalContent\Carmon Mills Org',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\Cmdlet Ref',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\Core',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\Developer',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\DSC'
      )]
    [string]$areapath='TechnicalContent\Carmon Mills Org\Management\PowerShell',

    [ValidateSet(
      'TechnicalContent\Future',
      'TechnicalContent\CY2019\06_2019',
      'TechnicalContent\CY2019\07_2019',
      'TechnicalContent\CY2019\08_2019',
      'TechnicalContent\CY2019\09_2019',
      'TechnicalContent\CY2019\10_2019',
      'TechnicalContent\CY2019\11_2019',
      'TechnicalContent\CY2019\12_2019',
      'TechnicalContent\CY2020\01_2020',
      'TechnicalContent\CY2020\02_2020',
      'TechnicalContent\CY2020\03_2020',
      'TechnicalContent\CY2020\04_2020',
      'TechnicalContent\CY2020\05_2020'
      )]
    [string]$iterationpath='TechnicalContent\Future',

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
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | Select-Object -ExpandProperty body
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
    #$description += "Description:<BR>{0}<BR>" -f ($issue.body -replace '\n','<BR>')
    #$description += "Comments:<BR>{0}" -f ($issue.comments -replace '\n','<BR>')

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
    $item | Select-Object Id,AreaPath,IterationPath,@{n='AssignedTo';e={$_.Fields['Assigned To'].Value}},Title,Description
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

  $pr = Invoke-RestMethod  "https://api.github.com/repos/MicrosoftDocs/PowerShell-Docs/pulls/$num" -method GET -head $hdr
  $commits = Invoke-RestMethod  $pr.commits_url -head $hdr
  $commits | ForEach-Object{
    $commit = Invoke-RestMethod  $_.url -head $hdr
    $commit.files | Select-Object status,changes,filename,previous_filename
  }  | Sort-Object status,filename -unique
}
#endregion
#-------------------------------------------------------
#region ROB Data
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
  } else {
      $enddate = get-date $end -Format 'yyyy-MM-dd'
  }
  $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }
  $query = "q=type:pr+is:merged+repo:MicrosoftDocs/PowerShell-Docs+merged:$startdate..$enddate"

  $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr -follow
  $prlist.items | ForEach-Object{
      $pr = Invoke-RestMethod $_.pull_request.url -Headers $hdr
      $pr | Select-Object number,state,merged_at,changed_files,@{n='base';e={$_.base.ref}},@{n='user';e={$_.user.login}}
  } | Export-Csv -Path ('.\prlist-{0}.csv' -f (get-date $start -Format 'MMMMyyyy'))
}
#-------------------------------------------------------
# Get issues closed this month
function get-issuehistory {
  param([datetime]$startmonth)

  if ($null -eq $startmonth) { $startmonth = Get-Date }
  $startdate = Get-Date ('{0}-{1:d2}-{2:d2}' -f $startmonth.Year, $startmonth.Month, 1)

  $nextmonth = $startdate.AddMonths(1)
  $hdr = @{
    Accept = 'application/vnd.github.symmetra-preview+json'
    Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
  }
  $apiurl = 'https://api.github.com/repos/MicrosoftDocs/PowerShell-Docs/issues?state=all&since=2018-01-01'
  Write-Host 'Querying GitHub issues...'
  $issuepages = Invoke-RestMethod $apiurl -head $hdr -follow
  $x = $issuepages | ForEach-Object {
    $_ | Where-Object pull_request -eq $null |
      Select-Object number,state,created_at,closed_at,@{n='user'; e={$_.user.login}},title
  }
  #$x.count
  $x | Where-Object {
    $_.created_at -lt $nextmonth -and (($_.closed_at -ge $startdate) -or ($null -eq $_.closed_at))
  } | Export-Csv -Path ('.\issues-{0}.csv' -f (get-date $startdate -Format 'MMMMyyyy'))
}
#endregion
