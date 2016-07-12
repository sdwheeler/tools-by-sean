# Some Key Concepts about Git and GitHub

## Terminology

- Fork â€" a clone of a repository hosted on a Git server
- Origin â€" an alias for your Fork on GitHub
- Upstream â€" an alias you create for the original Microsoft repository
- Clone â€" a copy of a repository on your local machine. This should be a copy of your Fork.
- Branch â€" a workspace for editing content within your local clone
- Pull â€" the operation to get the latest copy a remote repository
- Push â€" the operation to write the changes you made back into a remote repository
- Index â€" a database containing the state of the repository. Used to track, branches, files, and the changes. The Add command adds files to the index so that changes can be tracked.

## GitHub is not Git

GitHub is a Git server for hosting repositories. You can download and install a Git Server to any Windows machine. If you wanted to, you could create a Git Server in Azure or anywhere on the corporate network. There are other hosted Git Servers available on the internet (BitBucket, Codeplex, etc.).

## GitHub hierarchy

- Account (example: Microsoft or Azure)
  - Repository (example: WindowsServerDocs-pr or azure-content-pr)
    - Branch (example: July2016Freshness)
      - Git objects (commit, tree, blob)
      - Filesystem objects (files and folders)

## Forks and why you need one

- A Fork is a clone of a repository hosted on a Git server in your personal account. Your fork is also, yet another, backup of the main repository. This is a key feature of a distributed version control system.
- You canâ€™t write (push) to the Microsoft repositories. You must send a Pull Request. Then the admins of the Microsoft repository will pull a copy of your repository and merge it. This protects the main repository as the source of truth for your content.
- Github cannot pull the changes from the clone on your local machine, so a copy needs to be hosted on GitHub.

## When to delete a branch

Branches should be deleted after they are merged in. This prevents the visual clutter of a long list of branches in your repository. These branches also get propagated to all forks of the repository.

You can safely remove a branch. If the branch has unmerged changes git will warn you and will not delete it.

First, delete the local branch. This prevents it from being accidentally pushed later.

> git branch -d branchName

Then I delete the remote tracking branch

> git branch -dr remoteName\branchName

Then delete the branch on GitHub.

> git push remoteName --delete branchName

## Install the GitHub Desktop client for Windows

The GitHub Desktop client for Windows includes the following components:

- A very nice, modern Windows GUI application for managing git repositories
- A full install of the standard Git client for Windows (i.e. Git GUI and Git Bash)
- Posh-Git â€" a PowerShell environment for using the git client instead of Bash or CMD

The best reason for this using this client is the fact that you get a PowerShell command environment rather than Bash or CMD. This will be easier to support and customize and allows you to run the build scripts without having to launch a different shell environment.

### Installation steps

1. Download and run the GitHub Desktop client from https://desktop.github.com/
1. Open a new instance Git Shell and use git commands as described in the Contributor Guide

