# sdwheeler.GitTools module

This module provides a collection of tools for interacting with Git repositories. I designed this
module to setup a working environment for my own use, but I hope others find it useful as well.

The module creates a global variable `$git_repos` that contains a list of all Git repositories found
in the `\Git` directory at the root of all drives on the system. Many of the commands in this module
depend on this data to function properly.

## Requirements

This module require PowerShell 7 or later. It also depends on the following tools:

- The **posh-git** module for Git status information
- The **Git** command line tool

Many of the commands rely on the `git` command line tool to perform Git operations. Most `git`
commands must be run in a Git repository folder. Therefore, many of the commands in this module
require you to be in a Git repository folder when you run them. Some of the command change the
working directory to the root of the repository before running the `git` commands. Then they change
back to the original working directory when they are done.

## Layout of Git repositories

I keep all my Git repositories in a `\Git` directory at the root of each drive on my system. For
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
Build-MyRepoData
```

The `New-RepoRootList` command scans all drives on your system for a `\Git` directory and creates a
list of the top-level directories that contain your Git repositories. This information is cached in
a file in your profile directory: `~/gitreporoots.csv`. The `Build-MyRepoData` command scans each of
the repos in those locations and builds the data structure stored in the `$git_repos` global
variable.

You need this data loaded when before you can use most of the commands in this module. I do this in
my PowerShell profile. Since scanning the repositories can take a few minutes, depending on how many
repositories you have, I cache the data in a file in your profile directory: `~/repocache.clixml`. I
load the cached data in my profile to minimize profile run time. You can re-run the
`Build-MyRepoData` command at any time to refresh the data. Also, there are other commands to add
and remove repositories from the list and rewrite the cached data.

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
        Build-MyRepoData
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

- `Build-MyRepoData` - This command scans all enabled repository roots for Git repositories and
  builds the data structure stored in the `$git_repos` global variable.

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
  You must run this command in a folder that's inside a Git repository. This is helpful when you are
  several layers down in a subfolder of a repository and want to change back to the root of the
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
  your fork. You can invoke this command using the `goto` alias.

## Manage branches

- `Get-BranchDiff` - This command returns the files that are different between the current branch
  and the default branch. You can specify a different base branch to compare against. But the
  command always compares the current branch to the base branch. You must be in a repository folder
  when you run this command.

- `Get-BranchInfo` - This command returns information about a branch. If the branch has a remote
  tracking branch, it shows the remote that the branch is tracking.

  ```powershell
  PS> Get-BranchInfo

  branch remote sha     message
  ------ ------ ---     -------
  main   origin ab50fbd Add readme and fix bug
  rob           4a0f072 update rob
  ```

- `Get-GitMergeBase` - This command returns the merge base of the current branch in relation to the
  default branch. You can specify a different base branch to compare against. But the command always
  compares the current branch to the base branch. You must be in a repository folder when you run
  this command.

- `Get-LastCommit` - This command returns the last commit message for the current branch. This is
  used by the pull request commands to create a default title for the pull request.

- `Switch-Branch` - This command checks a branch. Specify the name of the branch. If the branch does
  not exist, it creates a new branch with that name based on the current branch, but doesn't switch
  to the new branch. If the branch exists, it switches to that branch. If you run it without a
  branch name, it switches to the default branch. You must be in a repository folder when you run
  this command. You can invoke this command using the `checkout` alias.

- `Remove-Branch` - This command removes a branch from the repository. You specify multiple branch
  names as an array of strings. You can use tab completion for the branch names. You can use
  wildcards in the branch names. You must be in a repository folder when you run this command. The
  command deletes the local branch and any remote tracking branch. It also attempts to delete the
  branch from the `origin` remote. If the branch does not exist on the `origin` remote, `git`
  returns an error, which you can ignore.

- `Sync-Branch` - This command does a `git pull upstream` then a `git push origin`. For the current
  branch. You must be in a repository folder when you run this command.

- `Sync-Repo` - This command syncs the current repository with its remotes. You must must be in the
  repository folder with the default branch checked out. If the current branch is not the default
  branch, the sync is skipped. This prevents you from accidentally syncing a default branch into
  a working branch. This command performs the following operations:

  - `git fetch --all --prune` - fetches all remotes and prunes deleted branches
  - `git rebase upstream/$($default_branch)` - rebases the local default branch be be in sync with
    the `upstream` remote's default branch
  - `git push origin ($default_branch) --force-with-lease` - force pushes the local default branch
    to your fork on the `origin` remote

- `Sync-AllRepos` - This command syncs all repositories with their remotes. This command uses
  `Find-GitRepo` to get the list of repositories to sync. Then it runs `Sync-Repo` in each
  repository. This is an easy way to keep all your repositories in sync. The command skips any
  repository that does not have the default branch checked out.

## Manage pull requests

- `Get-PrFiles` - This command queries GitHub and returns a list of files that changed in a pull
  request. You must specify the pull request number and the repository name. You can use tab
  completion for the repository name. If you don't specify a repository name, it defaults to
  `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API and depends on the
  `GITHUB_TOKEN`.

  ```powershell
  PS> Get-PRFileList 12345

  status   changes filename                                                        previous_filename
  ------   ------- --------                                                        -----------------
  modified      43 reference/7.6/Microsoft.PowerShell.Utility/Invoke-RestMethod.md
  modified      43 reference/7.6/Microsoft.PowerShell.Utility/Invoke-WebRequest.md
  ```

- `Get-PRMerger` - This command queries GitHub for all merged PR s in a respository. It returns
  information about each PR that includes the user who merged a pull request. You must specify the
  repository name. You can use tab completion for the repository name. The command uses the GitHub
  API and depends on the `GITHUB_TOKEN`.

- `New-MergeToLive` - This command creates a new PR to merge the default branch into the live
  branch. You must be in a repository folder when you run this command. If the PR is created
  successfully, the command opens the PR in your default web browser. The command uses the GitHub
  API and depends on the `GITHUB_TOKEN`.

- `New-PRFromBranch` - This command creates a new pull request to merge the current branch into the
  default branch. You must be in a repository folder when you run this command. If the PR is created
  successfully, the command opens the PR in your default web browser. The command uses the GitHub
  API and depends on the `GITHUB_TOKEN`.

## Manage issues

- `Close-Issue` - This command closes an issue. You can provide a closing comment. There are
  switches to close the issue as a duplicate or as spam. You must specify the issue number and the
  repository name. You can use tab completion for the repository name. If you don't specify a
  repository name, it defaults to `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API
  and depends on the `GITHUB_TOKEN`.

- `Get-Issue` - This command returns information about an issue. You must specify the issue number
  and the repository name. You can use tab completion for the repository name. If you don't specify
  a repository name, it defaults to current repository. The command uses the GitHub API and depends
  on the `GITHUB_TOKEN`.

- `New-Issue` - This command creates a new issue. You must specify the title and description for the
  issue. You can also specify labels and assignees for the issue. You can use tab completion for
  issue labels. You can use tab completion for the repository name. If you don't specify a
  repository name, it defaults to `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API
  and depends on the `GITHUB_TOKEN`.

- `Add-IssueComment` - This command adds a comment to an issue. You must specify the issue number,
  the text of the comment as a string, and the repository name. You can use tab completion for the
  repository name. If you don't specify a repository name, it defaults to
  `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API and depends on the
  `GITHUB_TOKEN`.

- `Add-IssueLabel` - This command adds a label to an issue. You must specify the issue number, the
  label to add, and the repository name. You can use tab completion for issue labels and the
  repository name. If you don't specify a repository name, it defaults to
  `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API and depends on the
  `GITHUB_TOKEN`.

- `Get-IssueLabel` - This command returns the labels for an issue. You must specify the issue number
  and the repository name. You can use tab completion for the repository name. If you don't specify
  a repository name, it defaults to `MicrosoftDocs/PowerShell-Docs`. The command uses the GitHub API
  and depends on the `GITHUB_TOKEN`.

- `Remove-IssueLabel` - This command removes a label from an issue. You must specify the issue
  number, the label to remove, and the repository name. You can use tab completion for issue labels
  and the repository name. If you don't specify a label, the all labels are removed. If you don't
  specify a repository name, it defaults to `MicrosoftDocs/PowerShell-Docs`. The command uses the
  GitHub API and depends on the `GITHUB_TOKEN`.

- `Set-IssueLabel` - This command sets the labels for an issue. You must specify the issue number,
  an array of labels to set, and the repository name. You can use tab completion for issue labels
  and the repository name. This command replace any existing labels with the new labels. If you
  don't specify a repository name, it defaults to `MicrosoftDocs/PowerShell-Docs`. The command uses
  the GitHub API and depends on the `GITHUB_TOKEN`.

## Manage DevOps work items

- `Get-DevOpsGitHubConnections` - This command returns the GitHub connections for the
  `msft-skilling/Content` DevOps project. The command uses the DevOps REST API and depends on the
  `CLDEVOPS_TOKEN` environment variable. The token must have the `GitHub Connections (Read)` scope.

- `Get-DevOpsWorkItem` - This command returns information about a DevOps work item in the
  `msft-skilling/Content` project. You must specify the work item ID. The command uses the DevOps
  REST API and depends on the `CLDEVOPS_TOKEN` environment variable. The token must have the
  `Work Items (Read)` scope.

- `Import-GHIssueToDevOps` - This command creates a new **Task** DevOps work item in the
  `msft-skilling/Content` project. You must specify the Url to the issue in GitHub. You can specify
  the DevOps Area Path and Iteration Path, but the command defaults the the current iteration and
  the PowerShell area path. You can use tab completion for the Area Path and Iteration Path. The
  description of the work item contains a link to the GitHub issue. The title of the work item is
  the title of the GitHub issue. The command uses both the GitHub and DevOps REST APIs and depends
  on the `GITHUB_TOKEN` and `CLDEVOPS_TOKEN` environment variables. The DevOps token must have the
  `Work Items (Read & Write)` scope.

- `New-DevOpsWorkItem` - This command creates a new DevOps work item. There are parameters to set
  the title, description, work item type, area path, iteration path, parent item ID and assigned
  user. The command uses the DevOps REST API and depends on the `CLDEVOPS_TOKEN` environment
  variable. The token must have the `Work Items (Read & Write)` scope.

- `New-IssueBranch` - This command creates a new working branch in GitHub based on an issue. There
  are options for creating a new DevOps work item based on the issue. The command uses both the
  GitHub and DevOps REST APIs. The DevOps token must have the `Work Items (Read & Write)` scope.

- `Update-DevOpsWorkItem` - This command updates an existing DevOps work item with information about
  a GitHub issue similar to the `Import-GHIssueToDevOps` command. Use this command to link a GitHub
  issue to an existing DevOps work item. The command uses the GitHub DevOps REST APIs and depends on
  the `GITHUB_TOKEN` and `CLDEVOPS_TOKEN` environment variables. The DevOps token must have the
  `Work Items (Read & Write)` scope.
