# Getting started with standard authoring tools

The [Microsoft Docs contributor guide](https://docs.microsoft.com/contribute) provides a concise guide for getting started with Git, GitHub, and VS Code.

Rather than duplicating that information here, please read the contributor guide.

## Using Visual Studio Code

[VS Code](https://code.visualstudio.com/) is the editor of choice to author content for
Docs.microsoft.com. The contributor guide also recommends installing the 
[Microsoft Docs Authoring Pack](https://docs.microsoft.com/contribute/how-to-write-docs-auth-pack).

### VS Code Extensions

When you install the Docs Authoring Pack it automatically installs the following extensions:

- markdownlint, a popular linter by David Anson.
- Code Spell Checker, a fully offline spell checker by Street Side Software.
- Docs Preview, which uses the docs.microsoft.com CSS for more accurate Markdown preview, including
  custom Markdown.
- Docs Markdown, which provides Markdown authoring assistance, including support for inserting
  custom Markdown syntax specific to docs.microsoft.com. The rest of this readme provides details
  on the Docs Markdown extension.
- Docs Article Templates, which allows users to apply Markdown skeleton content to new files.

I also recommend installing the following extensions. To install an extension, launch VS Code Quick
Open (Ctrl+P), enter the install command, and press enter. You need to restart VS Code for the new
extensions to be loaded. However, to save time, you can install all of these extensions then
restart VS Code only once after all extensions have been installed.

| |
|--------------------------------|
|**Extension:** Reflow paragraph<BR>**Install command:** ext install troelsdamgaard.reflow-paragraph<BR>**Description:** This extension formats lines in a paragraph to a preferred line-length.|
|**Extension:** C# for Visual Studio Code<BR>**Install command:** ext install csharp<BR>**Description:** The C# extension for Visual Studio Code provides the following features inside VS Code:<BR>- Lightweight development tools for .NET Core.<BR>- Great C# editing support, including Syntax Highlighting, IntelliSense, Go to Definition, Find All References, etc.<BR>- Debugging support for .NET Core (CoreCLR). NOTE: Mono and Desktop CLR debugging is not supported.<BR>- Support for project.json and csproj projects on Windows, macOS and Linux.|
|**Extension:** JS-CSS-HTML Formatter<BR>**Install command:** ext install vscode-JS-CSS-HTML-formatter<BR>**Description:** This extension wraps js-beautify to format your JS, CSS, HTML, JSON file.|
|**Extension:** PowerShell Language Support for Visual Studio Code<BR>**Install command:** ext install PowerShell<BR>**Description:** This extension provides rich PowerShell language support for Visual Studio Code. Now you can write and debug PowerShell scripts using the excellent IDE-like interface that Visual Studio Code provides.|
|**Extension:** XML Formatter<BR>**Install command:** ext install vs-code-xml-format<BR>**Description:** A simple wrapper around https://github.com/FabianLauer/tsxml/ for formatting XML in VS Code. Currently, only complete documents can be formatted. Formatting selections is planned.|
| |

## Installing Git for Windows

The contributor guide instructs you to install the Git client tools. When installing the 
[Git client for Windows](https://gitforwindows.org/) you want to select the following options:

- Use Visual Studio Code as Git's default editor
- Use Git from the Windows Command Prompt
- Use the native Windows Secure Channel library
- Checkout Windows-style, commit Unix-style line endings
- Use Windows’ default console window
- Check Enable file system caching
- Enable Git Credential Manager
- Enable symbolic links

## Installing and configuring Posh-Git

`posh-git` is a PowerShell module that integrates Git and PowerShell by providing Git status
summary information that can be displayed in the PowerShell prompt. `posh-git` also provides tab
completion support for common git commands, branch names, paths and more.

For more information, see:

- [`posh-git` on the PowerShell Gallery](https://www.powershellgallery.com/packages/posh-git)
- [`posh-git` on GitHub](https://github.com/dahlbyk/posh-git)

Install `posh-git` using the following command:

```powershell
Install-Module posh-git
```

This command must be run from an elevated PowerShell session. It is also recommended that you have
the latest version of [PowerShellGet](https://www.powershellgallery.com/packages/PowerShellGet).


### Integrate Git into your PowerShell environment

Integrating Git into PowerShell is simple. There are three main things to do:

1. Load the Posh-Git module
2. Start the SSH Agent Service
3. Configure your prompt to show the Git status

Add the following lines to your PowerShell profile script.

```powershell
Import-Module posh-git
Start-SshAgent -Quiet
function global:prompt {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    $name = ($identity.Name -split '\\')[1]
    $path = Convert-Path $executionContext.SessionState.Path.CurrentLocation
    $prefix = "($env:PROCESSOR_ARCHITECTURE)"

    if($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { $prefix = "Admin: $prefix" }
    $realLASTEXITCODE = $LASTEXITCODE
    $prefix = "Git $prefix"
    Write-Host ("$prefix[$Name]") -nonewline
    Write-VcsStatus
    ("`n$('+' * (get-location -stack).count)") + "PS $($path)$('>' * ($nestedPromptLevel + 1)) "
    $global:LASTEXITCODE = $realLASTEXITCODE
    $host.ui.RawUI.WindowTitle = "$prefix[$Name] $($path)"
}
```

The prompt function integrates Git into your PowerShell prompt to show an abbreviated git status.
See the README for Posh-Git for a full explanation of the abbreviated status. Customize this
function to meet your needs or preferences. The prompt function above is customized to show the
user context, the process architecture (64 or 32-bit), and an `Admin` label when running elevated.

## Next steps

[Configuring Git](Configuring%20Git.md)
