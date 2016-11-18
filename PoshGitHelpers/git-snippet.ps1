# Add this to your PowerShell profile script. This will set up the Git client environment and load the Posh Git module.
# The path to the Git folders below may vary depending on the version of GitHub Desktop and PoshGit that you have installed.

$env:github_git         = "$env:USERPROFILE\AppData\Local\GitHub\PortableGit_624c8416ee51e205b3f892d1d904e06e6f3c57c8"
$env:github_posh_git    = "$env:USERPROFILE\AppData\Local\GitHub\PoshGit_a2be688889e1b24632e83adccd9b2a44b91d655b"
$env:git_install_root   = "$env:USERPROFILE\AppData\Local\GitHub\PortableGit_624c8416ee51e205b3f892d1d904e06e6f3c57c8"
$env:GITHUB_ORG         = '<your org name here>'
$env:GITHUB_OAUTH_TOKEN = '<your oauth key here>'
$env:GITHUB_USERNAME        = '<your_github_username>'
# change $gitRepoRoots to match your repo locations
$gitRepoRoots = 'C:\Git\Azure', 'C:\Git\AzureSDK', 'C:\Git\CSI-Repos', 'C:\Git\MyRepos'

. "$env:github_posh_git\profile.example.ps1"

# Helper functions for common git tasks

function sync-git {
  git.exe pull upstream master
  git.exe push origin master
}

function sync-all {
  $loc = get-location
  $repoRoot = $gitRepoRoots | Where-Object {$loc.path -eq $_ }
  if ($repoRoot -eq '') {
    $repoRoot = $gitRepoRoots | Where-Object {$loc.path.startswith($_) }
  }
  if ($repoRoot) {
    Push-Location $repoRoot
    Get-ChildItem | Where-Object PSIsContainer | %{
      $dir = $_
      Push-Location $dir
      $remotes = @{}
      git.exe remote -v | Select-String '(fetch)' | %{ 
        $r = ($_ -replace ' \(fetch\)') -split "`t" 
        $remotes.add($r[0],$r[1])
      }

      if ($remotes.keys -contains 'upstream') {
        write-host ('='*20)
        write-host $dir
        write-host ('='*20)
        sync-git
      } else {
        write-host ('='*20)
        "Skipping $dir - no 'upstream' defined."
        write-host ('='*20)
      }
      Pop-Location
    } 
    Pop-Location
  } else {
    'No repos found.'
  }
}

function show-diffs {
  param($num=1)
  git.exe diff --stat --name-only HEAD~$num..HEAD
}

function goto-myprlist {
  param([string]$remotename='upstream')
  $r = git.exe remote -v | select-string $remotename | Select-Object Line -first 1
  if ($r) {
    $repoURL = ($r.line -split '\s')[1] -replace '\.git', ''
    start-process "$repoURL/pulls/$env:GITHUB_USERNAME"
  } else {
    "Remote '$remotename' not found."
  }
}

function goto-remote {
  param([string]$remotename='origin')
  $r = git.exe remote -v | select-string $remotename | Select-Object Line -first 1
  if ($r) {
    start-process ($r.line -split '\s')[1]
  } else {
    "Remote '$remotename' not found."
  }
}

# list all of my PRs in GitHub for current month

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

# A prompt function that will show the current Git branch and status.

function global:prompt {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal] $identity
  $name = ($identity.Name -split '\\')[1]
  $path = Convert-Path $executionContext.SessionState.Path.CurrentLocation
  $prefix = "($env:PROCESSOR_ARCHITECTURE)"

  if($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { $prefix = "Admin: $prefix" }
  $realLASTEXITCODE = $LASTEXITCODE
  if ($env:github_shell -eq 'true') {
    $prefix = "Git $prefix"
    Write-Host ("$prefix[$Name]") -nonewline
    Write-VcsStatus
  } else {
    Write-Host ("$prefix[$Name]") -nonewline
  }
  ("`n$('+' * (get-location -stack).count)") + "PS $($path)$('>' * ($nestedPromptLevel + 1)) "
  $global:LASTEXITCODE = $realLASTEXITCODE
  $host.ui.RawUI.WindowTitle = "$prefix[$Name] $($path)"
}
