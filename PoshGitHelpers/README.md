# Helper scripts for using Git and GitHub in PowerShell

## Prerequisites

- Install Git for Windows from https://git-for-windows.github.io/
- Install Posh-Git from https://www.powershellgallery.com/packages/posh-git

## set-gitcolors.ps1

This script sets the colors for any Git shell (bash or powershell). The colors were chosen to be more visible on a black console screen. You only need to run this script once. The script changes your global configuration for Git.

## git-snippets.ps1

This is a script that builds on Posh-Git to enable Git functionality in PowerShell. The posh-git module must be installed in one of your PowerShell module folders. If you used Install-Module to install posh-git it is installed in C:\Program Files\WindowsPowerShell\Modules. To import the module you may need to provide the full path to the location of the install location.

## Configuring the script

The script contains the following variables. Set these values for your environment.

```powershell
$env:GITHUB_ORG         = '<your org name here>'
$env:GITHUB_OAUTH_TOKEN = '<your oauth key here>'
$env:GITHUB_USERNAME        = '<your_github_username>'
$global:gitRepoRoots = 'C:\Git\Azure', 'C:\Git\AzureSDK', 'C:\Git\CSI-Repos', 'C:\Git\MyRepos'
```

### Helper functions

* **function get-myrepos**

    This function runs once in your profile. It is used to collect various information about the GitHub repos you work in. The information is stored in the global variable `$git_repos`. This information is used by the other helper functions to perform various tasks.

* **function sync-git**

    This function does a `pull upstream $branchname`/`push origin $branchname` on the current repo. The value of $branchname will be the default branch for the repo. The name of the default branch is retrieved from `$git_repos`.

* **function sync-all**

    This function checks to see if you are in one of the `$gitRepoRoots` folders. If you are then it will call sync-git on each repo folder in the current root folder. Repos with no upstream defined are skipped.

* **function show-diffs**

    This function shows you the files that have changed between the current HEAD and the previous commit. You can specify the number of commits to check, for example:

    ```powershell
    show-diffs 3
    ```
    Example output:

        PS C:\Git\MyRepos\tools-by-sean\PoshGitHelpers> show-diffs 3
        PoshGitHelpers/git-snippet.ps1
        vscode/specialchars.md

    This returns all of the files that have changed between HEAD~3 and HEAD.

* **function goto-remote**

    This function opens your browser to the GitHub page showing your fork.

* **function goto-myprlist**

    This function opens your browser to the GitHub page showing your PRs for the upstream remote.

* **function list-myprs**

    This function lists all of the PRs you submitted, anywhere in GitHub, for that current month. Using parameters you can change the date range and the GitHub username for the query. The output shows you basic information about the PR and lists the files that were changed.

    SYNTAX

        list-myprs [[-startdate] <string>] [[-enddate] <string>] [[-username] <string>]

    Dates must be in the format yyyy-MM-dd.

    OUTPUT

        number    : 1140
        html_url  : https://github.com/Microsoft/azure-docs-pr/pull/1140
        merged    : 2016-11-16T21:13:50Z
        closed    : 2016-11-16T21:13:51Z
        state     : closed
        title     : Adding article using TM with LB & AppGW to TOCs
        filecount : 4
        files     : articles/application-gateway/TOC.md
                    articles/dns/TOC.md
                    articles/load-balancer/TOC.md
                    articles/traffic-manager/TOC.md

        number    : 1044
        html_url  : https://github.com/Microsoft/azure-docs-pr/pull/1044
        merged    :
        closed    : 2016-11-15T14:53:06Z
        state     : closed
        title     : updating TOC for all load balancing tech
        filecount : 3
        files     : articles/application-gateway/TOC.md
                    articles/load-balancer/TOC.md
                    articles/traffic-manager/TOC.md

    In this example, PR 1140 was merged. PR 1044 was closed without merging.

* **function global:prompt**

    This function integrates Git into your PowerShell prompt to show the current working directory followed by an abbreviated `git status`. The status summary has the following format:

        Git (AMD64)[username] [{branch} +A ~B -C !D | +E ~F -G !H !]
        PS C:\Git\reponame>

    + `{branch}` is the current branch, or the SHA of a detached HEAD
        * Cyan means the branch matches its remote
        * Green means the branch is ahead of its remote (green light to push)
        * Red means the branch is behind its remote
        * Yellow means the branch is both ahead of and behind its remote
    + ABCD represent the index; EFGH represent the working directory
        * `+` = Added files
        * `~` = Modified files
        * `-` = Removed files
        * `!` = Conflicted files
        * As in `git status`, index status is dark green and working directory status is dark red
        * The trailing `!` means there are untracked files