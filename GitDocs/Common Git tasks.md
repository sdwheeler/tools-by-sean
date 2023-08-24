---
ms.date: 08/24/2023
---
# Common Git Workflow Tasks

This sections describe several common tasks you will perform to accomplish work.

## Throw away an uncommitted branch and start over

1. Revert all files back to the previous commit.

   ```powershell
   git reset --hard
   ```

   This resets all files that have changed since the last commit. This is a way to undo your
   changes and get back to a known state.

## Keeping your repos in sync

1. Pull the upstream main into your working branch again.

   ```powershell
   cd C:\github
   cd C:\github\azure-docs-pr
   git checkout main
   git pull upstream main
   ```

   The checkout command ensures that you are in the main branch of your local repository. The pull
   command copies the current version of the main branch from the upstream remote into the currently
   selected branch (main).

1. Push the local main branch into your fork.

   ```powershell
   git push origin main
   ```

   The push command uploads the current state of your local repository into your fork on GitHub.

   > [NOTE]
   > While this is not required, it is recommended as a best practice to keep your local repository
   > and your remote fork in sync with the official source repository. This is a good practice to
   > do if you have been away from working in a repository for any extended period of time.

## Deleting a branch

1. Delete the local branch.

   ```powershell
   git branch -d branchName
   ```

   This prevents it from being accidentally pushed later. If the branch has unmerged changes, git
   warns you and won't delete the branch.

1. Delete the remote tracking branch.

   ```powershell
   git branch -vr
   git branch -dr upstream/branchName
   ```

   Depending on how you check out a branch there may be a remote tracking branch. This happens
   automatically for `main` when you clone. The show-branch command shows you all the remote
   tracking branches.

1. Delete branch from your fork.

   ```powershell
   git push origin --delete branchName
   ```

   This updates your fork by telling it to delete the branch from the repository in GitHub.

   > [NOTE]
   > Branches should be deleted after they're merged into the official repository. This prevents
   > the visual clutter of a long list of branches in your repository. These branches also get
   > propagated to all forks of the repository.

## Restore a file from a previous commit

For this scenario, you need to recover an older version of a file that was committed. For example, I
did a bulk change on 300+ articles. One of the articles I changed overwrote the changes that another
writer, Tom, made. We need to recover Tom's version of the article then reapply my changes. Tom's
change was in PR#2437. The file in question is:

`azure-resource-manager/powershell-azure-resource-manager.md`.

The secret to this is that you need to find the SHA associated with the version of the file you want
restored.

1. Go to `https://github.com/MicrosoftDocs/azure-docs-pr/pull/2437/files` and scroll down to the
   file.
1. Click the View button on the title bar of the diff display of that file. This takes to you the
   updated version of the file in GitHub.
1. Click the History button on the header bar of the file viewer pane. This shows you the commit
   history for that file.
1. Click on commit history for the version of the file you want. On the right side of the page you
   will see the full SHA for this commit.
1. Copy the SHA value for the commit. In this case, the SHA is
   `30218c2013292a951253757bba9cef1beae3d7ae`
1. Check out the branch that overwrote the file.

   ```powershell
   git checkout mybranch
   ```

   This can be the branch where you did the bulk update. Or this could be a new branch for restoring
   this one file.

1. Restore the previous version with the following command:

   ```syntax
   git checkout <SHA of commit> -- <path to file>
   ```

   For example:

   ```powershell
   git checkout 30218c2013292a951253757bba9cef1beae3d7ae -- azure-resource-manager/powershell-azure-resource-manager.md
   ```

   Now the file has been restored. You can use this same checkout process to restore any number of
   files. This could be useful if you accidentally deleted files and need them restored.

1. Update the file using VS Code, as necessary.

1. Add and commit your changes.

   ```powershell
   git add --all
   git commit -m "description of the changes"
   ```

1. Push your changes up into your fork.

   ```powershell
   git push origin mybranch
   ```

   Now your fork is in sync with your local repository. You are ready to send a pull request to have
   your changes merged into the official repository.

## Squashing a working branch

1. `git checkout <main>`
1. `git pull upstream <main>`
1. `git checkout <working-branch>`
1. `git merge-base <main> <working-branch>`

   This gets the SHA of the where we started `<working-branch>`.

1. `git rebase -i <SHA of merge-base>`
1. `git rebase <main>`
1. `git push <remote> <working-branch> -f`

## Editing someone else's PR

1. Pull their PR into a new local working branch.

   `git fetch upstream pull/<pull_request_number>/head:newbranch`

1. Checkout the new working branch
1. Make your changes
1. Submit a PR to merge your working branch into theirs

## Update local repo after master is renamed to main

```powershell
# Update local repo after master is renamed to main
# Go to the master branch
git checkout master
# Rename master to main locally
git branch -m master main
# Get the latest commits from the server
git fetch
# Remove the link to origin/master
git branch --unset-upstream
# Add a link to origin/main
git branch -u origin/main
# Update the default branch to be origin/main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
# push main to your fork
git push origin main
# delete master from your fork
git push origin --delete master
```

## Find common ancestor of a branch

```powershell
# get common ancestor
git merge-base <base-branch-ref> <working-branch-ref>
# restore file from base branch
git checkout <base-SHA> <filepath>
```

For example:

```powershell
PS> git merge-base main sdw-2022-rename
744dde6e63b50ec39c4bea28f0830ea58da65857
PS> git checkout 744dde6e63b50ec39c4bea28f0830ea58da65857 .\WindowsUpdate\WindowsUpdate.md
Updated 1 path from f419ea8f9
```
