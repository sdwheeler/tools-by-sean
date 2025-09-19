# sdwheeler.GitTools module

This module provides a collection of tools for interacting with Git repositories. I designed this
module to setup a working environment for my own use, but I hope others find it useful as well.

The module creates a global variable `$git_repos` that contains a list of all Git repositories found
in the `\Git` directory at the root of all drives on the system. Many of the commands in this module
depend on this data to function properly.

## Layout of Git repositories

I keep all of my Git repositories in a `\Git` directory at the root of each drive on my system. For
example, if I have a drive `D:`, I would keep my repositories in `D:\Git`. I can have multiple
drives, and each drive can have its own `\Git` directory. In the `\Git` directory, there are
subfolders used to organize repositories by category. Then each repository is a subfolder within one
of those category folders. For example:

```
C:\Git
+---\3rdParty
|    +---\AHK-v2-script-converter
+---\APEX
|    +---\Contribute
+---\AzureDocs
|    +---\azure-docs-powershell
|    +---\azure-docs-powershell-archive
|    +---\azure-docs-pr
+---\My-Repos
|    +---\Documentarian
|    +---\hugo-theme-bootstrap
|    +---\sdwheeler
|    +---\seanonit
|    +---\ToolModules
|    +---\tools-by-sean
+---\PS-Docs
|    +---\PowerShell-Docs
|    +---\PowerShell-Docs-archive
|    +---\PowerShell-Docs-DSC
|    +---\PowerShell-Docs-Modules
|    +---\PowerShell-Docs-PSGet
+---\PS-Other
|    +---\Community-Blog
|    +---\PowerShell-Blog
+---\PS-Src
|    +---\AIShell
|    +---\platyPS
|    +---\PowerShell
|    +---\PSReadLine
|    +---\PSResourceGet
|    +---\PSScriptAnalyzer
|    +---\whatsnew
+---\Windows
|    +---\windows-powershell-docs
|    +---\winps-docs-archive-pr
```

## Get started

After you have installed and imported the module you need to complete the following steps:

1. Initialize the Git environment
2. Add startup commands to your PowerShell profile
3. Create environment variables for Personal Access Tokens (PATs) used for authentication

### Step 1 - Initialize your Git environment:

```powershell
New-RepoRootList
Get-MyRepos
```

The `New-RepoRootList` command scans all drives on your system for a `\Git` directory and creates a
list of the top-level directories that contain your Git repositories. This information is cached in
a file in your profile directory: `~/gitreporoots.csv`. The `Get-MyRepos` command scans each of the
repos in those locations and builds the data structure stored in the `$git_repos` global variable.

You need this data loaded when before you can use most of the commands in this module. I do this in
my PowerShell profile. Since scanning the repositories can take a few minutes, depending on how many
repositories you have, I cache the data in a file in your profile directory: `~/repocache.clixml`. I
load the cached data in my profile to minimize profile run time. You can re-run the `Get-MyRepos`
command at any time to refresh the data. Also, there are other commands to add and remove
repositories from the list and rewrite the cached data.

### Step 2 - Add startup commands to your PowerShell profile

Add the following commands to your PowerShell profile to load the cached repository data when you
start a new PowerShell session:

```powershell
Import-Module sdwheeler.GitTools

& {
    $cacheage = Get-RepoCacheAge
    if ($cacheage -lt 15) {
        'Loading repo cache...'
        $global:git_repos = Import-Clixml -Path ~/repocache.clixml
    } else {
        'Scanning repos...'
        Get-MyRepos
    }
}
```

The `Get-RepoCacheAge` command checks the age of the cache file. If the cache is less than 15 days
old it loads the cached data. If the cache is older than 15 days, it scans the repositories to
refresh the data. You can adjust the number of days to suit your needs.

### Step 3 - Create environment variables used for authentication

Several of the scripts in this module require environment variables that contain PATs used for
authentication. The names of the environment variables are:

```powershell
$env:GITHUB_TOKEN = "your-github-pat"
$env:CLDEVOPS_TOKEN = "your-azdo-pat"
```

I use Windows so I create these as User environment variables in the System Properties control
panel. This makes the values persistent across sessions. You can also store them in a Secret
Management vault and retrieve them as needed.

## Manage the Git environment

The module includes several commands to manage the Git environment.

- `Get-RepoRootList` - This command displays the list of top-level directories that contain your Git
  repositories. The output includes a column that indicates whether the directory is included in the
  scan for repositories. You can change that value to exclude a directory from the scan.

   ```powershell
   PS> Get-RepoRootList

   Path               Include
   ----               -------
   C:\Git\3rdParty    True
   C:\Git\APEX        True
   C:\Git\AzureDocs   True
   C:\Git\My-Repos    True
   C:\Git\PS-Docs     True
   C:\Git\PS-Other    True
   C:\Git\PS-Partners True
   C:\Git\PS-Src      True
   C:\Git\Windows     True
   ```

- `New-RepoRootList` - This command scans all drives on your system for a `\Git` directory
  and creates a list of the top-level directories that contain your Git repositories. This
  information is cached in a file in your profile directory: `~/gitreporoots.csv`. The **Include**
  column is set to `True` for all directories found. This command overwrites any existing
  `gitreporoots.csv` file.

- `Add-RepoRoot` - This command adds a new directory to the list of top-level directories that
  contain your Git repositories. The new directory is added with the **Include** column set to
  `True` by default.

- `Disable-RepoRoot` - This command disables a directory from being scanned for Git repositories.
  The **Include** column is set to `False` for the specified directory.

- `Enable-RepoRoot` - This command enables a directory to be scanned for Git repositories. The
  **Include** column is set to `True` for the specified directory.

- `Find-GitRepo` - This command searches the list of enabled repository roots and returns a list of
  repository folders. This list is used for tab completion in other commands and by the
  `Sync-AllRepos` command.

## Manage repository data

- `Get-MyRepos` - This command scans all enabled repository roots for Git repositories and builds
  the data structure stored in the `$git_repos` global variable.

- `Get-RepoCacheAge` - This command returns the age of the cached repository data in days.

- `Get-RepoData` - This command returns repository information stored in the global variable. You
  can specify a repository name or path to filter the results. If no parameters are specified and
  you are in a repo folder, it returns information for the current repo. It also supports wildcards
  and has tab completion for the **RepoName** parameter.

  ```powershell
  PS> Get-RepoData -RepoName PowerShell-Docs

  id           : MicrosoftDocs/PowerShell-Docs
  name         : PowerShell-Docs
  organization : MicrosoftDocs
  html_url     : https://github.com/MicrosoftDocs/PowerShell-Docs
  host         : github
  path         : C:\Git\PS-Docs\PowerShell-Docs
  remote       : @{upstream=https://github.com/MicrosoftDocs/PowerShell-Docs.git;
                 origin=https://github.com/sdwheeler/PowerShell-Docs.git}
  ```

- `Invoke-GitHubApi` - This command is a wrapper for `Invoke-RestMethod` that makes it easier to
  call the GitHub REST API. It automatically adds the required headers and authentication token. It
  depends on the `GITHUB_TOKEN` environment variable being set. This command is used by several
  other commands in this module.

- `New-RepoData` - This command creates a new repository object like this one shown by
  `Get-RepoData`. You must run this command in the repository folder for which you want the data.
  This command is used by other commands in this module. Normally you don't need to run this
  yourself.

- `Remove-RepoData` - This command removes a repository from the `$git_repos` global variable and
  updates the cached data file. You must specify a repository name. You can use tab completion for
  the **RepoName** parameter.

- `Update-RepoData` - This command updates the data for a repository in the `$git_repos` global
  variable and updates the cached data file. You must run this command in the repository folder for
  which you want to update the data. Use this command when information about the repository has
  changed, such as the remote URL, or to add a newly cloned repository.

## Manage repositories

The module contains several commands to manage your Git repositories.

- `Get-DefaultBranch` - This command returns the name of the default branch for a repository. You
  must run this command in the repository folder. The command returns the name of the default branch
  of the `upstream` remote if it exists, otherwise it returns the name of the default branch of the
  `origin` remote. The default branch information is used by the `Sync` commands to ensure that you
  don't accidentally sync the default branch into a working branch.

- `Get-GitRemote` - This command returns the remote URLs for a repository. You must run this
  command in the repository folder. The output is similar to the output of `git remote -v` command.

  ```powershell
  PS> Get-GitRemote

  remote   fetch push uri
  ------   ----- ---- ---
  origin    True True https://github.com/sdwheeler/PowerShell-Docs.git
  upstream  True True https://github.com/MicrosoftDocs/PowerShell-Docs.git
  ```

- `Set-LocationRepoRoot` - This command changes the current location to the root of a repository.
  You must run this command in a folder that is inside a Git repository. This is helpful when you
  are several layers down in a subfolder of a repository and want to change back to the root of the
  repository. This command can be invoked using the `cdr` alias.

- `Get-GitHubLabel` - This command returns the labels for a GitHub repository. You can specify the
  repository name (with tab completion). If you don't specify a repository name, it defaults to
  `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API and depends on the `GITHUB_TOKEN`
  environment variable.

- `Add-GitHubLabel` - This command adds a new label to a GitHub repository. The command uses the
  GitHub API and depends on the `GITHUB_TOKEN` environment variable.

- `Remove-GitHubLabel` - This command removes a label from a GitHub repository. The command uses the
  GitHub API and depends on the `GITHUB_TOKEN` environment variable.

- `Set-GitHubLabel` - This command changes settings of an existing label in a GitHub repository. The
  command uses the GitHub API and depends on the `GITHUB_TOKEN` environment variable.

- `Import-GitHubLabel` - This command imports label configuration data from a CSV file. You can
  create the CSV file by exporting the existing label data from a repository using
  `Get-GitHubLabel`. The command uses the GitHub API and depends on the `GITHUB_TOKEN` environment
  variable.

- `Get-RepoStatus` - This command creates a report showing the state of the current branch in each
  repository. You can specify the name of the repository to be scanned. If you don't specify a
  repository name, it scans all repositories. The output shows you if you have the default branch
  checked out or a working branch, and the current `git status` represented by the **posh-git**
  module.

```powershell
PS> Get-RepoStatus

RepoName                            Status  Default Current         GitStatus
--------                            ------  ------- -------         ---------
PowerShell                          ≡       master  master           ❮master ≡❯
AHK-v2-script-converter             ≡       master  master           ❮master ≡❯
PowerShell-Docs-archive             ≡       main    main             ❮main ≡❯
ToolModules                         ≡       main    main             ❮main ≡❯
tools-by-sean                       working main    docs-update      ❮docs-update ≡ +1 ~1 -0 !❯
PowerShell-Docs-Modules             ≡       main    main             ❮main ≡❯
windows-powershell-docs             ≡       main    main             ❮main ≡❯
```

- `Open-Repo` - The command opens a repository by changing to the repository folder or by opening
  the GitHub repository in your default web browser. You can specify the repository name (with tab
  completion). If you don't specify a repository name and you are in a repository folder, it opens
  that repository. When opening the GitHub page, there are parameters to choose the base repo or
  your fork.

- `Open-Branch` - This command opens a branch in the default editor.
- `Sync-Branch` - This command syncs a branch with its remote.
- `Sync-Repo` - This command syncs a repository with its remote.
- `Sync-AllRepos` - This command syncs all repositories with their remotes.
- `Remove-Branch` - This command removes a branch from the repository.
- `Get-BranchInfo` - This command returns information about a branch.
- `Get-GitMergeBase` - This command returns the merge base of two branches.
- `Get-BranchDiff` - This command returns the differences between two branches.
- `Get-LastCommit` - This command returns the last commit in a branch.
- `Get-PrFiles` - This command returns the files in a pull request.
- `Get-PrMerger` - This command returns the merger of a pull request.
- `New-MergeToLive` - This command creates a new merge to live.
- `New-PrFromBranch` - This command creates a new pull request from a branch.
- `Get-Issue` - This command returns information about an issue.
- `Close-Issue` - This command closes an issue.
- `New-Issue` - This command creates a new issue.
- `Add-IssueComment` - This command adds a comment to an issue.
- `Add-IssueLabel` - This command adds a label to an issue.
- `Get-IssueLabel` - This command returns the labels for an issue.
- `Remove-IssueLabel` - This command removes a label from an issue.
- `Set-IssueLabel` - This command sets the labels for an issue.
- `Get-DevOpsGitHubConnections` - This command returns the GitHub connections for a DevOps project.
- `Get-DevOpsWorkItem` - This command returns information about a DevOps work item.
- `New-DevOpsWorkItem` - This command creates a new DevOps work item.
- `Update-DevOpsWorkItem` - This command updates an existing DevOps work item.
- `Import-GHIssueToDevOps` - This command imports a GitHub issue into a DevOps project.
- `New-IssueBranch` - This command creates a new issue branch.