# Common Git Workflow Tasks

This sections describe several common tasks you will perform to accomplish work.

------

### One-time setup for contributing to a new repository

1. Fork the repository in GitHub

   Log into GitHub and navigate to the private repository. Go to the top-right of the page and
   click the Fork button. If prompted, select your account as the location where the fork should be
   created.

   This creates a copy of the repository within your Git Hub account. Generally speaking, technical
   writers and program managers need to fork the private repo (azure-docs-pr or
   azure-docs-powershell).

   Community contributors need to fork the public repo.

2. Clone your fork to your local machine

   Open your Git Shell and run the following commands:

   ```
   cd C:\github
   git clone https://github.com/<your GitHub user name>/azure-docs-pr.git
   ```

   In this example, your git repositories are contained in `C:\github` on the local disk.

   This copies you fork of the official repository to your local machine. A files are downloaded
   and the master branch is checked out automatically. Also the 'origin' alias is created
   automatically to refer to your remote fork on GitHub.

3. Create the upstream reference to the official source repository.

   This creates the 'upstream' alias for the remote private repository on GitHub. There is nothing
   special about the name 'upstream'. This is just a common practice. All Git documentation will
   use this name to refer to the repository that is the source of your fork.

   Run the following command from your Git Shell:

   ```
   cd C:\github\azure-docs-pr
   git remote add upstream https://github.com/MicrosoftDocs/azure-docs-pr.git
   ```

> [NOTE]
> These tasks only need to be done once for a given repository. Once you have forked the repository
> you can clone it to as many machines as you want. The fork is a cloud-based backup of your work.
> If your local hard drive crashed, you could clone your fork to a new machine. You will only have
> lost any changes that were not pushed into your fork.

------

### Normal editing workflow

1. Create a new working branch

   This will pull the latest contents from the upstream remote and create a new branch named
   'newbranch'.

   ```
   cd C:\github\azure-docs-pr
   git pull upstream master
   git checkout -B newbranch
   ```

   You can skip this step if you are returning to continue work on the same branch.

2. Check out the working branch

   ```
   git checkout -B newbranch
   ```

   This tells git create a new branch and switch to that branch context. The command prompt in the Git Shell
   should show this branch name.

3. Make additions and changes to your content.

   This is done using your content editing and creation tools like VS Code.

4. Add your changes to Git's tracking database.

   ```
   git status
   git add --all
   ```

   Git keeps an index of all of the files that are being tracked. When you add or change files in
   the repository you need to update the Git index. The status command will show you which files
   are being tracked and which are not. The add command adds files to the index. If a file is not
   being tracked, it cannot be committed to the repository.

5. Commit your changes.

   ```
   git commit -m "description of the changes"
   ```

   This checks-in the changes to your local git repository.

6. Pull the upstream master into your working branch again.

   ```
   git pull upstream master
   ```

   While you were working, the upstream repository could have changed. Other contributors could
   have checked-in updates that you do not have synced to your local repository. The pull command
   ensures that your branch contains the latest version of the content.

   You may now have conflicts that need to be resolved. If so, fix the conflicts and commit the
   changes again.

7. Push your changes to your fork.

   ```
   git push origin newbranch
   ```

   Now your fork is in sync with your local repository. You are ready to send a pull request to
   have your changes merged into the official repository.

8. Submit a pull request.

   Log into GitHub and navigate to your fork. You should see that new commits have been added.
   There will be a button to create a pull request. Click that button, review your changes, and
   submit.

   Unless you are an Admin for the repository you do not have write permissions. So you cannot push
   changes into the official repository. You must create a Pull Request (PR). An Admin for the
   repository will review your request. If there are no validation errors or other problems, the
   Admin will pull the changes from your fork and merge them into the master branch of the official
   repository.

------

### Working in release branch

Working in a release branch is the same as your daily work flow. The only change is that you want
to create a tracking branch. When you have a tracking branch set up, git pull will look up what
server and branch your current branch is tracking, fetch from that server and then try to merge
that into your local branch.

1. Fetch the latest list of branches

   ```
   git fetch upstream
   ```

   This fetches a list of the branches from the upstream repo. Before running this command, your
   local repo does not know about the release branch.

2. Create a new tracking branch

   ```
   git checkout -b <branch> -t <upstream/branch>
   ```

   This command creates a new branch, checks it out, and links it for tracking to the remote branch
   in the upstream repo.

3. Pull the upstream branch into local branch.

   ```
   git pull upstream
   ```

   This copies the latest content in release branch down into your local branch.

4. Make additions and changes to your content.

   This is done using your content editing and creation tools like VS Code.

5. Add and commit your changes.

   ```
   git add --all
   git commit -m "description of the changes"
   ```

6. Push your changes up into your fork.

   ```
   git push origin branch
   ```

   Now your fork is in sync with your local repository. You are ready to send a pull request to
   have your changes merged into the official repository.

7. Submit a pull request.

   Log into GitHub and navigate to your fork. Be sure to select the release branch in the GitHub
   UI. There will be a button to create a pull request. Click that button, review your changes, and
   submit.

   Your PR will be processed and merged into the release branch of the official repo.

   When the release goes live, the PR admins will merge the release branch into the master branch.

------

### Throw away an uncommitted branch and start over

1. Revert all files back to the previous commit.

   ```
   git reset --hard
   ```

   This resets all files that have changed since the last commit. This is a way to undo your
   changes and get back to a known state.

------

### Keeping your repos in sync

1. Pull the upstream master into your working branch again. From your Git Shell (bash or PS):

   ```
   cd C:\github
   cd C:\github\azure-docs-pr
   git checkout master
   git pull upstream master
   ```

   The checkout command ensures that you are in the master branch of your local repository. The
   pull command copies the current version of the master branch from the upstream remote into the
   currently selected branch (master).

2. Push the local master branch into your fork.

   ```
   git push origin master
   ```
   The push command uploads the current state of your local repository into your fork on GitHub.

   > [NOTE]
   > While this is not required, it is recommended as a best practice to keep your local repository
   > and your remote fork in sync with the official source repository. This is a good practice to
   > do if you have been away from working in a repository for any extended period of time.

------

### Deleting a branch

1. Delete the local branch.

   ```
   git branch -d branchName
   ```

   This prevents it from being accidentally pushed later. If the branch has unmerged changes git
   will warn you and will not delete the branch.

2. Delete the remote tracking branch.

   ```
   git branch -vr
   git branch -dr upstream/branchName
   ```

   Depending on how you check out a branch there may be a remote tracking branch. This happens
   automatically for 'master' when you clone. The show-branch command shows you all of the remote
   tracking branches.

3. Delete branch from your fork.

   ```
   git push origin --delete branchName
   ```

   This updates your fork by telling it to delete the branch from the repository in GitHub.

   > [NOTE]
   > Branches should be deleted after they are merged into the official repository. This prevents
   > the visual clutter of a long list of branches in your repository. These branches also get
   > propagated to all forks of the repository.

------

### Restore a file from a previous commit

For this scenario, you need to recover an older version of a file that was committed. For example,
I did a bulk change on 300+ articles. One of the articles I changed overwrote the changes that
another writer, Tom, made. We need to recover Tom's version of the article then reapply my changes.
Tom's change was in PR#2437. The file in question is
azure-resource-manager/powershell-azure-resource-manager.md. The secret to this is that you need to
find the SHA associated with the version of the file you want restored.


1. Go to <https://github.com/MicrosoftDocs/azure-docs-pr/pull/2437/files> and scroll down to the file.
2. Click the View button on the title bar of the diff display of that file. This takes to you the
   updated version of the file in GitHub.
3. Click the History button on the header bar of the file viewer pane. This shows you the commit
   history for that file.
4. Click on commit history for the version of the file you want. On the right side of the page you
   will see the full SHA for this commit.
5. Copy the SHA value for the commit. In this case the SHA is 30218c2013292a951253757bba9cef1beae3d7ae
6. Check out the branch that overwrote the file.

   ```
   git checkout mybranch
   ```

   This can be the branch where you did the bulk update. Or this could be a new branch for restoring
   this one file.

7. Restore the previous version with the following command:

   ```
   git checkout <SHA of commit> -- <path to file>
   ```

   For example:

   ```
   git checkout 30218c2013292a951253757bba9cef1beae3d7ae -- azure-resource-manager/powershell-azure-resource-manager.md
   ```

   Now the file has been restored. You can use this same checkout process to restore any number of
   files. This could be useful if you accidentally deleted files and need them restored.

8. Update the file using VS Code, as necessary.

9. Add and commit your changes.

   ```
   git add --all
   git commit -m "description of the changes"
   ```

10. Push your changes up into your fork.

    ```
    git push origin mybranch
    ```

    Now your fork is in sync with your local repository. You are ready to send a pull request to
    have your changes merged into the official repository.

------

### Squashing a working branch

1. git checkout \<master\>

1. git pull upstream \<master\>

1. git checkout \<working-branch\>

1. git merge-base \<master\> \<working-branch\>

   This gets the SHA of the where we started \<working-branch\>.

1. git rebase -i \<SHA of merge-base\>

1. git rebase \<master\>

1. git push \<remote\> \<working-branch\> -f

------

### Editing someone else's PR

1. Pull their PR into a new local working branch.

   git fetch upstream pull/<pull_request_number>/head:newbranch

1. Checkout the new working branch
1. Make your changes
1. Submit a PR to merge your working branch into theirs

------

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

------

## Find common ancestor of a branch

```powershell
# get common ancestor
git merge-base <base-branch-ref> <working-branch-ref>
# restore file from base branch
git checkout <base-SHA> <filepath>
```

For example:

```powershell
PS> git merge-base master sdw-2022-rename
744dde6e63b50ec39c4bea28f0830ea58da65857
PS> git checkout 744dde6e63b50ec39c4bea28f0830ea58da65857 .\WindowsUpdate\WindowsUpdate.md
Updated 1 path from f419ea8f9
```
