# Add this to your PowerShell profile script. This will set up the Git client environment and load the Posh Git module.
# The path to the Git folders below may vary depending on the version of GitHub Desktop and PoshGit that you have installed.

$env:github_git         = "$env:USERPROFILE\AppData\Local\GitHub\PortableGit_624c8416ee51e205b3f892d1d904e06e6f3c57c8"
$env:github_posh_git    = "$env:USERPROFILE\AppData\Local\GitHub\PoshGit_a2be688889e1b24632e83adccd9b2a44b91d655b"
$env:git_install_root   = "$env:USERPROFILE\AppData\Local\GitHub\PortableGit_624c8416ee51e205b3f892d1d904e06e6f3c57c8"
$env:GITHUB_ORG         = '<your org name here>'
$env:GITHUB_OAUTH_TOKEN = '<your oauth key here>'
$env:GITHUB_USERNAME        = '<your_github_username>'

# change $gitRepoRoots to match your repo locations
$global:gitRepoRoots = 'C:\Git\Azure', 'C:\Git\AzureSDK', 'C:\Git\CSI-Repos', 'C:\Git\MyRepos'

. "$env:github_posh_git\profile.example.ps1"

Import-Module "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\Posh-GitHub"
Set-Location C:\Git\Azure

#-------------------------------------------------------
# Helper functions for common git tasks
#-------------------------------------------------------
function get-myrepos {
  $token = "access_token=${Env:\GITHUB_OAUTH_TOKEN}"
  $apiurl = "https://api.github.com/user/repos?visibility=all&affiliation=owner&$token"
  $allrepos = (Invoke-RestMethod $apiurl)
  $global:git_repos = @{}

  foreach ($repo in $allrepos) {
    $props = $repo | Select-Object name,private,default_branch,html_url,description,@{l='remotes';e={@{}}}
    $git_repos.Add($repo.name,$props)
  }

  foreach ($repoRoot in $gitRepoRoots) {
    Get-ChildItem $repoRoot | Where-Object PSIsContainer | %{
      $dir = $_
      push-location $dir.FullName
      if ($git_repos.ContainsKey($dir.name))
      {
        git.exe remote -v | Select-String '(fetch)' | %{
          $r = ($_ -replace ' \(fetch\)') -split "`t"
          $git_repos[$dir.name].remotes.add($r[0],$r[1])
        }
      }
      pop-location
    }
  }
}
get-myrepos

#-------------------------------------------------------
function sync-git {
  param([string]$path='.')
  $dir = Push-Location $path -PassThru
  $reponame = (Get-Item $dir).name
  $repo = $git_repos[$reponame]
  write-host ('='*20)
  write-host ('Syncing {0} [{1}]' -f $repo.name, $repo.default_branch)
  write-host ('='*20)
  git.exe pull upstream ($repo.default_branch)
  write-host ('-'*20)
  git.exe push origin ($repo.default_branch)
  Pop-Location
}
function sync-all {
  $loc = get-location
  $repoRoot = $gitRepoRoots | Where-Object {$loc.path -eq $_ }
  if ($repoRoot -eq '') {
    $repoRoot = $gitRepoRoots | Where-Object {$loc.path.startswith($_) }
  }
  if ($repoRoot) {
    Get-ChildItem | Where-Object PSIsContainer | %{
      $dir = $_
      $remotes = $git_repos[$dir.Name].remotes

      if ($remotes.upstream) {
        sync-git $dir
      } else {
        write-host ('='*20)
        "Skipping $dir - no 'upstream' defined."
        write-host ('='*20)
      }
    }
  } else {
    'No repos found.'
  }
}
function show-diffs {
  param($num=1)
  git.exe diff --stat --name-only HEAD~$num..HEAD
}
#-------------------------------------------------------
function goto-remote {
  param(
    [string]$remotename='origin',
    [string]$reponame
  )

  if ($reponame -eq '') {
    $reponame = (Get-Item .).Name
  }
  $repo = $git_repos[$reponame]
  if ($repo) {
    if ($repo.remotes.containskey($remotename)) {
      start-process $repo.remotes[$remotename]
    } else {
      "Remote '$remotename' not found."
    }
  } else {
    "Repo '$reponame' not found."
  }
}
function goto-myprlist {
  param(
    [string]$remotename='upstream',
    [string]$reponame
  )
  $remotes = @{}
  git.exe remote -v | Select-String '(fetch)' | %{
    $r = ($_ -replace ' \(fetch\)') -split "`t"
    $remotes.add($r[0],$r[1])
  }
  if ($reponame -eq '') {
    $reponame = (Get-Item .).Name
  }
  $repo = $git_repos[$reponame]
  if ($repo) {
    if ($repo.remotes.containskey($remotename)) {
      $repoURL = $repo.remotes[$remotename] -replace '\.git', ''
      start-process "$repoURL/pulls/$env:GITHUB_USERNAME"
    } else {
      "Remote '$remotename' not found."
    }
  } else {
    "Repo '$reponame' not found."
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
    $enddate = '{0}-{1:d2}-{2:d2}' -f $current.Year, $current.Month, [System.DateTime]::DaysInMonth($current.year,$current.month)
  }
  $token = "access_token=${Env:\GITHUB_OAUTH_TOKEN}"
  $query = "q=is:pr+involves:$username+updated:$startdate..$enddate"

  $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query&$token"
  $prlist.items | %{
    $files = $(Invoke-RestMethod ($_.pull_request.url + '/files?' + $token) ) | Select-Object -ExpandProperty filename
    $events = $(Invoke-RestMethod ($_.url + '/events?' + $token) )
    $merged = $events | Where-Object event -eq 'merged' | Select-Object -exp created_at
    $closed = $events | Where-Object event -eq 'closed' | Select-Object -exp created_at
    $pr = $_ | Select-Object number,html_url,@{l='merged';e={$merged}},@{l='closed';e={$closed}},state,title,@{l='filecount'; e={$files.count}},@{l='files'; e={$files -join "`r`n"} }
    $pr
  }
}
#-------------------------------------------------------
function global:prompt {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal] $identity
  $name = ($identity.Name -split '\\')[1]
  $path = Convert-Path $executionContext.SessionState.Path.CurrentLocation
  $prefix = "($env:PROCESSOR_ARCHITECTURE)"

  if($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { $prefix = "Admin: $prefix" }
  $realLASTEXITCODE = $LASTEXITCODE
  $prefix = "Git $prefix"
  Write-Host ("$prefix[$Name]") -nonewline
  Write-VcsStatus
  ("`n$('+' * (get-location -stack).count)") + "PS $($path)$('>' * ($nestedPromptLevel + 1)) "
  $global:LASTEXITCODE = $realLASTEXITCODE
  $host.ui.RawUI.WindowTitle = "$prefix[$Name] $($path)"
}