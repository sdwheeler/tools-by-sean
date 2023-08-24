# Configuring your Git environment

## Global configuration

For consistent behavior across all of your repositories you can create global configuration files in
your Windows user profile directory (e.g. %USERPROFILE% or `C:\users\<username>\`). There are two
files:
- .gitconfig - This file should already exist. Add the `[color]` and `[core]` sections shown below.
- .gitignore - This file contains a list of files and folders to be ignored by Git.

Adjust the settings in these files to meet your personal needs. Creating the .gitignore as a global
configuration ensures that you are ignoring the same files across all repositories.

## Git Shell colors

The settings documented here will help improve your user experience with Git. By default, the colors
that Git uses in the shell can be hard to see. You can change the colors however you want. I find
that making the colors "bold" will improve the readability on a black shell background.

### .gitconfig

```ini
[color]
    ui = true
[color "status"]
    changed = magenta bold
    untracked = red bold
    added = green bold
    unmerged = yellow bold
[color "branch"]
    remote = magenta bold
    upstream = blue bold
    current = green bold
[core]
    excludesfile = ~/.gitignore
```

Alternatively you can use the following Git commands to configure the same settings:

```powershell
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

## Git ignore settings

When using creating and editing content in your repository, the tools you use may create system,
hidden, or temporary files that you do not want Git to sync into your repository on Github. For
example, you can create workspace-specific settings for VS Code in a .vscode folder in your
repository. This may contain specific snippets or style sheets that you want to use with VS Code for
that group of content. You can create a .gitignore file to tell Git which files and folders not to
track.

### .gitignore

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