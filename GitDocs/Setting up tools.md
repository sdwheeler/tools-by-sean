---
ms.date: 08/24/2023
---
# Getting started with standard authoring tools

The [Microsoft Docs contributor guide](https://learn.microsoft.com/contribute) provides a concise
guide for getting started with Git, GitHub, and VS Code.

Rather than duplicating that information here, please read the contributor guide.

## Using VS Code

[VS Code](https://code.visualstudio.com/) is the editor of choice to author content for
learn.microsoft.com. The contributor guide also recommends installing the
[Microsoft Learn Authoring Pack](https://learn.microsoft.com/contribute/how-to-write-docs-auth-pack).

### VS Code Extensions

When you install the Docs Authoring Pack it automatically installs the following extensions:

- learn-preview - Learn Markdown Preview Extension
- learn-markdown - Learn Markdown Extension
- learn-article-templates - Learn article templates (optional)
- learn-yaml - YAML schema validation and auto-completion for learn.microsoft.com authoring
- markdownlint -Markdown linting and style checking for VS Code
- learn-images - Learn Images Extension
- learn-validation - Enables you to run build validation on a Learn content (REMOVE or DISABLE)
- learn-scaffolding - Provide scaffolding and updating Learn modules (REMOVE - only for MSFT employees)

I also recommend installing the following extensions. To install an extension, launch VS Code Quick
Open (Ctrl+P), enter the install command, and press enter. You need to restart VS Code for the new
extensions to be loaded. However, to save time, you can install all of these extensions then
restart VS Code only once after all extensions have been installed.

**Must have extensions**

- ms-vscode.powershell - PowerShell extension
- chrischinchilla.vale-vscode - VSCode integration for Vale, your style and grammar checker
- marvhen.reflow-markdown - Reflow Markdown lines in a paragraph to a preferred line-length
- redhat.vscode-yaml - Provides validation, document outlining, autocompletion, hover support, and
  formatting
- streetsidesoftware.code-spell-checker - Spell checker for source code and text documents
- vscode-icons-team.vscode-icons - Provides icons for specific file types in VS Code

**Markdown and writing-related extenisons**

- bierner.markdown-yaml-preamble - Format YAML front matter as a table in Markdown preview
- csholmq.excel-to-markdown-table - Copy rows and columns from Excel and paste as a Markdown table
- DrMattSm.replace-smart-characters - Replaces _smart_ Unicode characters with their ASCII
  equivalents
- ionutvmi.path-autocomplete - Provides path completion as you enter a file path in the editor
- kukushi.pasteurl - Paste URL from clipboard as a Markdown link
- medo64.code-point - Displays the Unicode code point of the character at the cursor position
- ms-vscode.wordcount - Provides a word count for the current document
- nhoizey.gremlins - Helps identify invisible and ambiguous Unicode characters
- shuworks.vscode-table-formatter - Pretty formatting for Markdown tables
- tomoki1207.selectline-statusbar - Shows the number of selected lines in the status bar
- Tyriar.sort-lines - Sorts lines of text in specific order
- wmaurer.change-case - Quickly change the case of the current selection or word (many different
  formats)

**Code-related extensions**

- chouzz.vscode-better-align - Aligns code in a column
- DotJoshJohnson.xml - XML formatting, XQuery, and XPath tools
- EditorConfig.EditorConfig - EditorConfig support for VS Code
- GitHub.copilot - AI pair programmer
- naumovs.color-highlight - Highlights web color codes in your editor
- redhat.vscode-xml - XML language support for VS Code
- richie5um2.vscode-sort-json - Sorts JSON objects by key
- usernamehw.errorlens - Highlights and provides actions for errors and warnings

**Git/GitHub-related extensions**

- codezombiech.gitignore - Language support for .gitignore files
- donjayamanne.githistory - View git log, file history, compare branches or commits
- eamodio.gitlens - GitLens supercharges the Git capabilities built into VS Code
- GitHub.vscode-pull-request-github - Pull Request Provider for GitHub
- ms-vscode.github-issues-prs - View and manage GitHub issues and pull requests

**File format extensions**

- jock.svg - SVG language support for VS Code
- ms-vscode.hexeditor - Hex editor for VS Code

**Remote development extensions**

- GitHub.codespaces - GitHub Codespaces extension
- GitHub.remotehub - Quickly browse, search, edit, and commit to any remote GitHub repository
- ms-vscode-remote.remote-containers - Use a Docker container as a full-featured development
  environment
- ms-vscode-remote.remote-wsl -  Lets you use VS Code in WSL just as you would from Windows
- ms-vscode.azure-repos - Quickly browse and search any remote Azure Repos repository
- ms-vscode.remote-repositories - Integrates with the GitHub Repositories and Azure Repos extensions

## Installing Git for Windows

The contributor guide instructs you to install the Git client tools. When installing the
[Git](https://git-scm.com/downloads) on Windows use the following suggested settings:

**Select Components**

- Additional icons - optional (my preference = don't install)
- Windows Explorer integration - optional (my preference = don't install)
- Git LFS (Large File Support) - depends on your project needs (my preference = install)
- Associate .git* configuration files with the default text editor
- Associate .sh files to be run with Bash - if you are using Git bash
- Use VS Code as Git's default editor
- Check daily for Git for Windows updates - optional (my preference = install)
- (NEW!) Add a Git Bash Profile to Windows Terminal - optional (your preference)
- (NEW!) Scalar (Git add-on to manage large-scale repositories) - recommended

**Choosing the default editor used by Git**

- Use VS Code as Git's default editor

**Adjusting the name of the initial branch in new repositories**

- Override the default branch name for new repositories
  - Name = main

**Adjusting your PATH environment**

- Git from the command line and also from 3rd-party software

**Choosing the SSH executable**

- Use bundled OpenSSH - default
- Use external OpenSSH - if you have installed a different version of OpenSSH

**Choosing HTTPS transport backend**

- Use the native Windows Secure Channel library

**Configuring the line edit conversions**

- Checkout Windows-style, commit Unix-style line endings

**Configuring the terminal emulator to use with Git Bash**

- Use Windows' default console window

**Choose the default behavior of `git pull`**

- Default (Fast-forward or merge)

**Choose a credential helper**

- Git Credential Manager

**Configuring extra options**

- Enable file system caching
- Enable symbolic links

**Configuring experimental options**

- Enable experimental support for pseudo consoles
- Enable experimental built-in file system monitor

## Installing and configuring posh-git

**posh-git** is a PowerShell module that integrates Git and PowerShell by providing Git status
summary information that is displayed in the PowerShell prompt. `posh-git` also provides tab
completion support for common git commands, branch names, paths and more.

For more information, see:

- [`posh-git` on the PowerShell Gallery](https://www.powershellgallery.com/packages/posh-git)
- [`posh-git` on GitHub](https://github.com/dahlbyk/posh-git)

Install `posh-git` using the following command:

```powershell
Install-Module posh-git
```

Add the following command to your profile script.

```powershell
Import-Module posh-git
```

## Next steps

[Configuring Git](Configuring%20Git.md)
