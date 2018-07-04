# Setting up your working environment

Follow the instructions for setting up the tools as described in the Azure Contributor Guide Tools
and Setup document for the following tasks:

- [GitHub and Livefyre account setup][contrib-tools]
- [Local repository setup][contrib-repo]

The document also includes instructions for setting up the Git client and a markdown editor. Those
instructions are accurate and valid but I recommend the following changes:

- Install the GitHub Desktop client for Windows
- Install Visual Studio Code as your markdown editor

### Install the Git for Windows and Posh-Git

Follow the instructions to install Git for Windows as I have outlined in my blog at:
[Using Git from PowerShell][seanonit-git]

These instructions enable you to use Git from PowerShell. I also include instructions to setup a
Git-enabled command prompt and to configure Git settings. Following these instructions will install
the Windows Credential Manager for Git. Using the Windows Credential Manager means that you don't
have to provide your Git username and token in the upstream URL.

### Install Visual Studio Code as your markdown editor

Visual Studio Code is a lightweight but powerful source code editor which runs on your desktop and
is available for Windows, OS X and Linux. It comes with built-in support for JavaScript, TypeScript
and Node.js and has a rich ecosystem of extensions for other languages (C++, C#, Python, PHP) and
runtimes.

VS Code ships monthly releases and supports auto-update when a new release is available. If you're
prompted by VS Code, accept the newest update and it will be installed (you won't need to do
anything else to get the latest bits).

The benefits of using VS Code are the availability of extensions powerful extensions and the wide
support of a growing community of users. Being a Microsoft open source project means that we have
unique access to the project owners.

#### Installation

1. Download the [Visual Studio Code installer][vscode] for Windows.
2. Once it is downloaded, run the installer. This will only take a minute.
3. By default, VS Code (64-bit) is installed under `C:\Program Files\Microsoft VS Code`.

#### VS Code Extensions

I recommend installing the following extensions for the best user experience when using VS Code. VS
Code has an internal command interface that is used to install extensions. To install an extension,
launch VS Code Quick Open (Ctrl+P), enter the install command, and press enter. You need to restart
VS Code for the new extensions to be loaded. However, to save time, you can install all of these
extensions then restart VS Code only once after all extensions have been installed.

|**Markdown-oriented Extensions**|
|--------------------------------|
|**Extension:** markdownlint<BR>**Install command:** ext install vscode-markdownlint<BR>**Description:** markdownlint includes a library of more than 40 rules to encourage standards and consistency for Markdown files. This helps you avoid rendering problems in staging.|
|**Extension:** Markdown Shortcuts<BR>**Install command:** ext install markdown-shortcuts<BR>**Description:** Allows you to use shortcuts to edit Markdown (.md, .markdown) files. Add hotkeys for bold, italics, code blocks, bullets, numbered lists, and easy hyperlink creation.|
|**Extension:** Code Spellchecker<BR>**Install command:** ext install code-spell-checker<BR>**Description:** Load up a file and get highlights and hovers for spelling and grammar issues. Checking will occur as you type. The extension will offer spelling and grammar suggestions when you hover over the problem text.|
|**Extension:** Reflow paragraph<BR>**Install command:** ext install reflow-paragraph<BR>**Description:** Format the current paragraph to have lines no longer than your preferred line length, using alt+q (may be overriden in user-specific keyboard-bindings.) This extension defaults to reflowing lines to be no more than 80 characters long. The preferred line length may be overriden using the config value of reflow.preferredLineLength. By default, preserves indent for paragraph, when reflowing. This behavior may be switched off, by setting the configuration option reflow.preserveIndent to false.|
|**Extension:** Acrolinx for APEX<BR>**Install command:** See [Acrolinx for APEX technical content][acrolinx]<BR>**Description:** Acrolinx is software that provides content authors with automated feedback on grammar, spelling, punctuation, writing style, terminology, and voice. Acrolinx is available both upstream and locally - upstream, users get automatic results from the Acrolinx integration for GitHub, which writes Acrolinx results to each pull request. The tool is seamlessly integrated into the pull request workflow. Locally, the Acrolinx extension for Visual Studio Code is now available so you can obtain the Acrolinx feedback before you push content to the upstream repository.|
|**Extension:** Gauntlet Authoring Services and VS Code Extension<BR>**Install command:** See [Gauntlet Authoring Services and VS Code Extension][gauntlet]<BR>**Description:** The Gauntlet VS Code extension for OPS authoring provides Markdown authoring assistance to writers working in OPS and publishing to docs.microsoft.com. It includes several functions, including applying templates to new Markdown files, applying common formatting to strings, and inserting links, images, tokens, snippets, tables, and lists, as well as previewing content using your site's CSS.|
|**Extension:** Replace Smart Characters<BR>**Install command:** ext install DrMattSm.replace-smart-characters<BR>**Description:** This extension replaces those pesky "smart" characters from Word (and also some fancy HTML characters) with their more common and friendly counterparts.|

|**Language-oriented Extensions**|
|--------------------------------|
|**Extension:** C# for Visual Studio Code<BR>**Install command:** ext install csharp<BR>**Description:** The C# extension for Visual Studio Code provides the following features inside VS Code:<BR>- Lightweight development tools for .NET Core.<BR>- Great C# editing support, including Syntax Highlighting, IntelliSense, Go to Definition, Find All References, etc.<BR>- Debugging support for .NET Core (CoreCLR). NOTE: Mono and Desktop CLR debugging is not supported.<BR>- Support for project.json and csproj projects on Windows, macOS and Linux.|
|**Extension:** JS-CSS-HTML Formatter<BR>**Install command:** ext install vscode-JS-CSS-HTML-formatter<BR>**Description:** This extension wraps js-beautify to format your JS, CSS, HTML, JSON file.|
|**Extension:** PowerShell Language Support for Visual Studio Code<BR>**Install command:** ext install PowerShell<BR>**Description:** This extension provides rich PowerShell language support for Visual Studio Code. Now you can write and debug PowerShell scripts using the excellent IDE-like interface that Visual Studio Code provides.|
|**Extension:** XML Formatter<BR>**Install command:** ext install vs-code-xml-format<BR>**Description:** A simple wrapper around https://github.com/FabianLauer/tsxml/ for formatting XML in VS Code. Currently, only complete documents can be formatted. Formatting selections is planned.|

<!-- Hyperlinks -->
[progit4]: https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols
[contrib-tools]: https://review.docs.microsoft.com/en-us/help/contribute/contribute-get-started-setup-github?branch=master
[contrib-repo]: https://review.docs.microsoft.com/en-us/help/contribute/contribute-get-started-setup-local?branch=master
[seanonit-git]: https://seanonit.wordpress.com/2016/12/05/using-git-from-powershell
[vscode]: https://go.microsoft.com/fwlink/?LinkID=534107
[acrolinx]: https://review.docs.microsoft.com/en-us/help/contribute/contribute-acrolinx-vscode?branch=master
[gauntlet]: https://review.docs.microsoft.com/en-us/help/contribute/contribute-vscode-extension?&branch=master
