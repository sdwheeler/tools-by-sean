#-------------------------------------------------------
#region Git Functions
function get-myrepos {
  $my_repos = @{ }
  foreach ($repoRoot in $gitRepoRoots) {
    Get-ChildItem $repoRoot -Directory -Exclude *.wiki | ForEach-Object {

      $dir = $_.fullname
      push-location $dir

      $gitStatus = Get-GitStatus
      if ($gitStatus) {
        $gitDir = get-item $gitStatus.gitdir -Force
        $repoName = $gitDir.parent.name
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
      $arepo.remote = new-object -type psobject -prop $remotes
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
      pop-location
    }
  }

  $hdr = @{
    Accept        = 'application/vnd.github.v3+json'
    Authorization = "token ${Env:\GITHUB_TOKEN}"
  }

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
    $repo = ((Get-GitStatus).gitdir -split '\\')[-2]
    $branch = $git_repos[$repo].default_branch
  }
  git checkout $branch
}
function status {
  (Get-GitStatus).working
}
#-------------------------------------------------------
function sync-branch {
  $gitStatus = Get-GitStatus
  $repo = show-repo
  if ($gitStatus) {
    if ($gitStatus.HasIndex -or $gitStatus.HasUntracked) {
      write-host ('=' * 20) -Fore DarkCyan
      write-host ("Skipping  - {0} has uncommitted changes." -f $gitStatus.Branch) -Fore Yellow
      write-host ('=' * 20) -Fore DarkCyan
    }
    else {
      write-host ('=' * 20) -Fore DarkCyan
      if ($repo.remote.upstream) {
        git.exe pull upstream ($gitStatus.Branch)
        if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red }
        write-host ('-' * 20) -Fore DarkCyan
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
    write-host ('=' * 20) -Fore DarkCyan
    write-host "Skipping $pwd - not a repo." -Fore Yellow
    write-host ('=' * 20) -Fore DarkCyan
  }
}
#-------------------------------------------------------
function sync-repo {
  param([switch]$origin)
  $gitStatus = Get-GitStatus
  if ($gitStatus -eq $null) {
    write-host ('=' * 20) -Fore DarkCyan
    write-host "Skipping $pwd - not a repo." -Fore Red
    write-host ('=' * 20) -Fore DarkCyan
  } else {
    $repoName = $gitStatus.RepoName
    $repo = $git_repos[$reponame]
    write-host ('=' * 20) -Fore DarkCyan
    if ($origin) {
      write-host ('Syncing {0} from {1}' -f $gitStatus.Upstream, $repoName) -Fore DarkCyan
      write-host ('=' * 20) -Fore DarkCyan
      git.exe fetch origin
      if (!$?) { Write-Host 'Error fetching from origin' -Fore Red }
      write-host ('-' * 20) -Fore DarkCyan
      git.exe pull origin $gitStatus.Branch
      if (!$?) { Write-Host 'Error pulling from origin' -Fore Red }
      write-host ('-' * 20) -Fore DarkCyan
    } else {
      if ($gitStatus.Branch -ne $repo.default_branch) {
      write-host ('=' * 20) -Fore DarkCyan
      write-host "Skipping $pwd - default branch not checked out." -Fore Yellow
      write-host ('=' * 20) -Fore DarkCyan
    } else {
      write-host ('Syncing {0}/{1} [{2}]' -f $repo.organization, $reponame, $repo.default_branch) -Fore DarkCyan
      if ($repo.remote.upstream) {
          write-host ('=' * 20) -Fore DarkCyan
          git.exe fetch upstream
          if (!$?) { Write-Host 'Error fetching from upstream' -Fore Red }
          write-host ('-' * 20) -Fore DarkCyan
          git.exe pull upstream ($repo.default_branch)
          if (!$?) { Write-Host 'Error pulling from upstream' -Fore Red }
          write-host ('-' * 20) -Fore DarkCyan
          if ($repo.remote.upstream -eq $repo.remote.origin) {
            git.exe fetch origin
            if (!$?) { Write-Host 'Error fetching from origin' -Fore Red }
          }
          else {
            git.exe push origin ($repo.default_branch)
            if (!$?) { Write-Host 'Error pushing to origin' -Fore Red }
          }
        } else {
          write-host ('=' * 20) -Fore DarkCyan
          write-host 'No upstream defined -  pulling from origin' -Fore Yellow
          git.exe pull origin ($repo.default_branch)
          if (!$?) { Write-Host 'Error pulling from origin' -Fore Red }
        }
      }
    }
  }
}
#-------------------------------------------------------
function sync-all {
  param([switch]$origin)
  foreach ($reporoot in $gitRepoRoots) {
    $reposlist = Get-ChildItem $reporoot -dir -Hidden .git -rec -depth 2 |
      Select-Object -exp parent | Select-Object -exp fullname
    if ($reposlist) {
      $reposlist | ForEach-Object {
        Push-Location $_
        sync-repo -origin:$origin
        Pop-Location
      }
    }
    else {
      write-host 'No repos found.' -Fore Red
    }
  }
}
Set-Alias syncall sync-all
#-------------------------------------------------------
function kill-branch {
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
  $repo = ((Get-GitStatus).gitdir -split '\\')[-2]
  $default_branch = $git_repos[$repo].default_branch
  $current_branch = (Get-GitStatus).branch
  git.exe diff --name-only $default_branch $current_branch | ForEach-Object { $_ }
}
#-------------------------------------------------------
function show-repo {
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
    if ($organization) {
      $git_repos.keys | ForEach-Object { $git_repos[$_] | Where-Object organization -eq $organization }
    }
    elseif ($repo) {
      $git_repos.keys | Where-Object { $_ -like $repo } | ForEach-Object { $git_repos[$_] }
    }
    else {
      $repo = ($GitStatus.GitDir -split '\\')[-2]
      $git_repos.keys | Where-Object { $_ -like $repo } | ForEach-Object { $git_repos[$_] }
    }
  }
}
#-------------------------------------------------------
function show-branches {
  $reposlist = Get-ChildItem -dir -Hidden .git -rec | Select-Object -exp parent | Select-Object -exp fullname
  if ($reposlist) {
    $reposlist | ForEach-Object {
      Push-Location $_
      "`n{0}" -f $pwd.Path
      git branch | Sort-Object
      Pop-Location
    }
  }
  else {
    'No repos found.'
  }
}
#-------------------------------------------------------
function get-branchstatus {
  Write-Host ''
  $git_repos.keys | Sort-Object | ForEach-Object {
    Push-Location $git_repos[$_].path
    if ((Get-GitStatus).Branch -eq $git_repos[$_].default_branch) {
      $default = 'default'
      $fgcolor = [consolecolor]::Cyan
    }
    else {
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
    }
    else {
      if ($repo.remote.upstream) {
        start-process $repo.remote.upstream
      }
      else {
        start-process $repo.remote.origin
      }
    }
  }
  else {
    'Not a git repo.'
  }
}
#endregion
#-------------------------------------------------------
#region Git queries
function get-issue {
  param(
    [Parameter(Position = 0,
      Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [uri]$issueurl
  )
  $hdr = @{
    Accept        = 'application/vnd.github.v3+json'
    Authorization = "token ${Env:\GITHUB_TOKEN}"
  }
  if ($issueurl -ne '') {
    $repo = ($issueurl.Segments[1..2]) -join ''
    $repo = $repo.Substring(0, ($repo.length - 1))
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
function get-issuelist {
  param(
    [ValidateSet("azure/azure-docs-powershell", "azure/azure-docs-powershell-samples",
    "azure/azure-powershell", "azure/azure-powershell-pr", "powershell/platyps",
    "powershell/powershell", "MicrosoftDocs/PowerShell-Docs", "powershell/powershell-rfc",
    "powershell/powershellget", ignorecase = $true)]
    $reponame = "MicrosoftDocs/PowerShell-Docs"
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
function get-repostatus {
  $hdr = @{
    Accept        = 'application/vnd.github.VERSION.full+json'
    Authorization = "token ${Env:\GITHUB_TOKEN}"
  }
  $repos1 = 'MicrosoftDocs/PowerShell-Docs', 'MicrosoftDocs/PowerShell-Docs-archive',
  'MicrosoftDocs/windows-powershell-docs', 'MicrosoftDocs/powershell-sdk-samples',
  'MicrosoftDocs/powershell-docs-sdk-dotnet'

  $repos2 = 'Azure/azure-docs-powershell', 'Azure/azure-docs-powershell-samples',
  'Azure/azure-powershell', 'MicrosoftDocs/azure-docs-cli',
  'Azure-Samples/azure-cli-samples', 'MicrosoftDocs/azure-dev-docs',
  'MicrosoftDocs/azure-dev-docs-pr'
  $repos1, $repos2 | ForEach-Object {
    $status = @()
    $repos = $_
    foreach ($repo in $repos) {
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
      $status += new-object -type psobject -prop ([ordered]@{
          repo       = $repo
          issuecount = $ghrepo.open_issues - $count
          prcount    = $count
        })
    }
    $status | Format-Table -a
  }
}

#-------------------------------------------------------
function New-DevOpsWorkItem {
  param(
    [Parameter(Mandatory = $true)]
    [string]$title,

    [Parameter(Mandatory = $true)]
    [string]$description,

    [int]$parentId,

    [string[]]$tags,

    [ValidateSet('Task', 'User%20Story')]
    [string]$wiType = 'Task',

    [ValidateSet(
      'TechnicalContent\Carmon Mills Org',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Cmdlet Ref',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Core',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Developer',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\DSC'
    )]
    [string]$areapath = 'TechnicalContent\Azure\Compute\Management\Config\PowerShell',

    [ValidateSet(
      'TechnicalContent\Future',
      'TechnicalContent\CY2020\01_2020',
      'TechnicalContent\CY2020\02_2020',
      'TechnicalContent\CY2020\03_2020',
      'TechnicalContent\CY2020\04_2020',
      'TechnicalContent\CY2020\05_2020',
      'TechnicalContent\CY2020\06_2020',
      'TechnicalContent\CY2020\07_2020',
      'TechnicalContent\CY2020\08_2020',
      'TechnicalContent\CY2020\09_2020',
      'TechnicalContent\CY2020\10_2020',
      'TechnicalContent\CY2020\11_2020',
      'TechnicalContent\CY2020\12_2020'
    )]
    [string]$iterationpath = 'TechnicalContent\CY2019\12_2019',

    [ValidateSet('sewhee', 'phwilson', 'robreed', 'dcoulte', 'v-dasmat')]
    [string]$assignee = 'sewhee'
  )

  $username = ' '
  $password = ConvertTo-SecureString $env:MSENG_OAUTH_TOKEN -AsPlainText -Force
  $cred = [PSCredential]::new($username, $password)

  $vsuri = 'https://dev.azure.com'
  $org = 'mseng'
  $project = 'TechnicalContent'
  $apiurl = "$vsuri/$org/$project/_apis/wit/workitems/$" + $wiType + "?api-version=5.1"

  $widata = [System.Collections.Generic.List[psobject]]::new()

  $field = New-Object -type PSObject -prop @{
    op    = "add"
    path  = "/fields/System.Title"
    value = $title
  }
  $widata.Add($field)

  $field = New-Object -type PSObject -prop @{
    op    = "add"
    path  = "/fields/System.AreaPath"
    value = $areapath
  }
  $widata.Add($field)

  $field = New-Object -type PSObject -prop @{
    op    = "add"
    path  = "/fields/System.IterationPath"
    value = $iterationpath
  }
  $widata.Add($field)

  if ($parentId -ne 0) {
    $field = New-Object -type PSObject -prop @{
      op    = "add"
      path  = "/relations/-"
      value = @{
        rel = 'System.LinkTypes.Hierarchy-Reverse'
        url = "$vsuri/$org/$project/_apis/wit/workitems/$parentId"
      }
    }
    $widata.Add($field)
  }

  if ($tags.count -ne 0) {
    $field = New-Object -type PSObject -prop @{
      op    = "add"
      path  = "/fields/System.Tags"
      value = $tags -join '; '
    }
    $widata.Add($field)
  }

  $field = New-Object -type PSObject -prop @{
    op    = "add"
    path  = "/fields/System.AssignedTo"
    value = $assignee + '@microsoft.com'
  }
  $widata.Add($field)

  $field = New-Object -type PSObject -prop @{
    op    = "add"
    path  = "/fields/System.Description"
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
function Import-GitHubIssueToTFS {
  param(
    [Parameter(Mandatory = $true)]
    [uri]$issueurl,

    [ValidateSet(
      'TechnicalContent\Carmon Mills Org',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Cmdlet Ref',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Core',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\Developer',
      'TechnicalContent\Azure\Compute\Management\Config\PowerShell\DSC'
    )]
    [string]$areapath = 'TechnicalContent\Azure\Compute\Management\Config\PowerShell',

    [ValidateSet(
      'TechnicalContent\Future',
      'TechnicalContent\CY2020\01_2020',
      'TechnicalContent\CY2020\02_2020',
      'TechnicalContent\CY2020\03_2020',
      'TechnicalContent\CY2020\04_2020',
      'TechnicalContent\CY2020\05_2020',
      'TechnicalContent\CY2020\06_2020',
      'TechnicalContent\CY2020\07_2020',
      'TechnicalContent\CY2020\08_2020',
      'TechnicalContent\CY2020\09_2020',
      'TechnicalContent\CY2020\10_2020',
      'TechnicalContent\CY2020\11_2020',
      'TechnicalContent\CY2020\12_2020'
    )]
    [string]$iterationpath = 'TechnicalContent\CY2019\12_2019',

    [ValidateSet('sewhee', 'phwilson', 'robreed', 'dcoulte', 'v-dasmat')]
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
  $description += "Created: {0}<BR>" -f $issue.created_at
  $description += "Labels: {0}<BR>" -f ($issue.labels -join ',')

  $wiParams = @{
    title         = $issue.title
    description   = $description
    parentId      = 1669514
    areapath      = $areapath
    iterationpath = $iterationpath
    wiType        = 'Task'
    assignee      = $assignee
  }
  New-DevOpsWorkItem @wiParams
}
# Create PR to merge staging to live
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
  $i = Invoke-RestMethod $apiurl -head $hdr -method POST -body $body
  Start-Process $i.html_url
}
#-------------------------------------------------------
function get-prfiles {
  param(
    [int32]$num,
    [string]$repo = 'MicrosoftDoc/PowerShell-Docs'
  )
  $hdr = @{
    Accept        = 'application/vnd.github.VERSION.full+json'
    Authorization = "token ${Env:\GITHUB_TOKEN}"
  }

  $pr = Invoke-RestMethod  "https://api.github.com/repos/$repo/pulls/$num" -method GET -head $hdr
  $commits = Invoke-RestMethod  $pr.commits_url -head $hdr
  $commits | ForEach-Object {
    $commit = Invoke-RestMethod  $_.url -head $hdr
    $commit.files | Select-Object status, changes, filename, previous_filename
  } | Sort-Object status, filename -unique
}
function list-prmerger {
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
    $event = (Invoke-RestMethod $pr.events_url -Headers $hdr) | Where-Object event -eq merged
    $result = [ordered]@{
      number     = $pr.number
      state      = $pr.state
      event      = $event.event
      created_at = get-date $event.created_at -f 'yyyy-MM-dd'
      merged_by  = $event.actor.login
      title      = $pr.title
    }
    New-Object -type psobject -Property $result
  }
}
#-------------------------------------------------------
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
  }
  else {
    $startdate = get-date $start -Format 'yyyy-MM-dd'
  }
  if ($end -eq '') {
    $current = get-date $start
    $enddate = '{0}-{1:d2}-{2:d2}' -f $current.Year, $current.Month, [datetime]::DaysInMonth($current.year, $current.month)
  }
  else {
    $enddate = get-date $end -Format 'yyyy-MM-dd'
  }
  $hdr = @{
    Accept        = 'application/vnd.github.v3+json'
    Authorization = "token ${Env:\GITHUB_TOKEN}"
  }

  $query = "q=type:pr+is:merged+repo:MicrosoftDocs/PowerShell-Docs+merged:$startdate..$enddate"

  $users = Import-Csv C:\Users\sewhee\Desktop\WIPBin\ROB-Data\github-users.csv
  function getOrg {
    param($name)
    ($users | Where-Object { $_.opened_by -eq $name }).org
  }

  $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr -follow
  $prlist.items | ForEach-Object {
    $pr = Invoke-RestMethod $_.pull_request.url -Headers $hdr
    $pr | Select-Object number, state,
    @{l = 'merged_at'; e = { ([datetime]$_.merged_at).GetDateTimeFormats()[3] } },
    changed_files,
    @{n = 'base'; e = { $_.base.ref } },
    @{n = 'org'; e = { getOrg $_.user.login } },
    @{n = 'user'; e = { $_.user.login } }
  } | Export-Csv -Path ('.\prlist-{0}.csv' -f (get-date $start -Format 'MMMMyyyy'))
}
#-------------------------------------------------------
# Get issues closed this month
function get-issuehistory {
  param([datetime]$startmonth)

  if ($null -eq $startmonth) { $startmonth = Get-Date }
  $startdate = Get-Date ('{0}-{1:d2}-{2:d2}' -f $startmonth.Year, $startmonth.Month, 1)

  $hdr = @{
    Accept        = 'application/vnd.github.symmetra-preview+json'
    Authorization = "token ${Env:\GITHUB_TOKEN}"
  }
  $apiurl = 'https://api.github.com/repos/MicrosoftDocs/PowerShell-Docs/issues?state=all&since=' + $startdate

  $users = Import-Csv C:\Users\sewhee\Desktop\WIPBin\ROB-Data\github-users.csv
  function getOrg {
    param($name)
    ($users | Where-Object { $_.opened_by -eq $name }).org
  }

  function getAge {
    param($record)
    $start = $record.created_at
    $end = $record.closed_at
    if ($end -eq $null) { $end = get-date }
    (New-TimeSpan -Start $start -End $end).totaldays
  }

  Write-Host 'Querying GitHub issues...'
  $issuepages = Invoke-RestMethod $apiurl -head $hdr -follow
  $x = $issuepages | ForEach-Object {
    $_ | Where-Object pull_request -eq $null
  }
  $x | Select-Object number, state,
  @{l = 'created_at'; e = { ([datetime]$_.created_at).GetDateTimeFormats()[3] } },
  @{l = 'closed_at'; e = { ([datetime]$_.closed_at).GetDateTimeFormats()[3] } },
  @{l = 'age'; e = { '{0:f2}' -f (getAge $_) } },
  @{l = 'user'; e = { $_.user.login } },
  @{l = 'org'; e = { getOrg $_.user.login } },
  title |
  Export-Csv -Path ('.\issues-{0}.csv' -f (get-date $startdate -Format 'MMMMyyyy'))
}
function merge-issues {
  param($newcsv)
  $ht = @{ }
  Import-Csv C:\Users\sewhee\Desktop\WIPBin\ROB-Data\issues.csv | ForEach-Object { $ht[$_.number] = $_ }
  Import-Csv $newcsv | ForEach-Object { $ht[$_.number] = $_ }
  $ht.values | export-csv issues-merged.csv
}
function get-issueage {
  param([datetime]$startmonth)

  if ($null -eq $startmonth) { $startmonth = Get-Date }
  $startdate = Get-Date ('{0}-{1:d2}-{2:d2}' -f $startmonth.Year, $startmonth.Month, 1)
  $csv = import-csv ('C:\Users\sewhee\Desktop\WIPBin\ROB-Data\issues.csv' -f (get-date $startdate -Format 'MMMMyyyy'))

  $range = @(
    (new-object -type psobject -prop @{
        range   = 'Less than 14 days'
        count   = 0
        sum     = 0.0
        average = 0.0
        min     = 99999.99
        max     = 0.00
      }),
    (new-object -type psobject -prop @{
        range   = '14-30 days'
        count   = 0
        sum     = 0.0
        average = 0.0
        min     = 99999.99
        max     = 0.00
      }),
    (new-object -type psobject -prop @{
        range   = 'More than 30 days'
        count   = 0
        sum     = 0.0
        average = 0.0
        min     = 99999.99
        max     = 0.00
      }),
    (new-object -type psobject -prop @{
        range   = 'Total'
        count   = 0
        sum     = 0.0
        average = 0.0
        min     = 99999.99
        max     = 0.00
      })
  )

  $csv | Where-Object state -eq 'closed' |
  Where-Object { (([datetime]$_.closed_at) -ge $startdate) -and
    (([datetime]$_.closed_at) -lt $startdate.AddMonths(1)) } | ForEach-Object {
    $range[3].count++
    $range[3].sum += [decimal]$_.age
    $range[3].average = $range[3].sum / $range[3].count
    if ([decimal]$_.age -lt $range[3].min) { $range[3].min = [decimal]$_.age }
    if ([decimal]$_.age -gt $range[3].max) { $range[3].max = [decimal]$_.age }

    switch ([decimal]$_.age) {
      { $_ -le 14 } {
        $range[0].count++
        $range[0].sum += $_
        $range[0].average = $range[0].sum / $range[0].count
        if ($_ -lt $range[0].min) { $range[0].min = $_ }
        if ($_ -gt $range[0].max) { $range[0].max = $_ }
      }
      { $_ -gt 14 -and $_ -le 31 } {
        $range[1].count++
        $range[1].sum += $_
        $range[1].average = $range[1].sum / $range[1].count
        if ($_ -lt $range[1].min) { $range[1].min = $_ }
        if ($_ -gt $range[1].max) { $range[1].max = $_ }
      }
      { $_ -ge 31 } {
        $range[2].count++
        $range[2].sum += $_
        $range[2].average = $range[2].sum / $range[2].count
        if ($_ -lt $range[2].min) { $range[2].min = $_ }
        if ($_ -gt $range[2].max) { $range[2].max = $_ }
      }
    }
  }

$range | ForEach-Object { if ($_.count -eq 0) { $_.min = 0 } }

$range | Select-Object range, count,
@{l = 'minimum'; e = { '{0,7:N2}' -f $_.min } },
@{l = 'average'; e = { '{0,7:N2}' -f $_.average } },
@{l = 'maximum'; e = { '{0,7:N2}' -f $_.max } } | Format-Table -a
}
#-------------------------------------------------------
#endregion
