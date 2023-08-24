---
ms.date: 08/24/2023
---
# Configuring your Git environment

## Global configuration

For consistent behavior across all of your repositories you can create global configuration files
in your Windows user profile directory (e.g. %USERPROFILE% or C:\users\\*username*\\). There are
two files:

- .gitconfig - This file should already exist. Add the `[color]` and `[core]` sections shown below.
- .gitignore - This file contains a list of files and folders to be ignored by Git.

Adjust the settings in these files to meet your personal needs.

## Customizing your Git environment

To contribute to a project on GitHub you must identify yourself so that your commits are tagged
with your identity. You may want to customize some of the settings of your Git environment. The
default colors used by Git in the shell could be hard to read. You can customize the colors to make
them more visible.

The following commands configure global settings for Git, you only need to run them one time.

```powershell
# Configure your user information to match your GitHub profile
git config --global user.name "John Doe"
git config --global user.email "alias@example.com"
git config --global color.ui true
git config --global color.status.changed "magenta bold"
git config --global color.status.untracked "red bold"
git config --global color.status.added "red bold"
git config --global color.unmerged "yellow bold"
git config --global color.branch.remote "magenta bold"
git config --global color.branch.upstream "blue bold"
git config --global color.branch.current "green bold"
git config --global core.excludesfile ~/.gitignore
```

For more information, see the [Customizing Git](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)
topic in the Git documentation.

### Git ignore settings

Creating the .gitignore as a global configuration ensures that you are ignoring the same files
across all repositories.

The tools you use to create and edit your content may create hidden, system, or temporary files
that you do not want Git to sync to Github. Also, you can create workspace-specific settings for VS
Code in a .vscode folder in your repository. This folder can contain code snippets or style sheets
that you use in VS Code for that group of content. A .gitignore file tells Git which files and
folders ignore for change tracking.

#### %USERPROFILE%\\.gitignore

```ini
.vscode/

# Windows image file caches
Thumbs.db
ehthumbs.db

# Folder config file
Desktop.ini

# Recycle Bin used on file shares
$RECYCLE.BIN/

# Windows Installer files
*.cab
*.msi
*.msm
*.msp

# Windows shortcuts
*.lnk
```