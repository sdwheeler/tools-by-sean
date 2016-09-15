# Sean's VSCode hacks

This folder contains various files and notes on customizing VSCode.

## [markdown.css](markdown.css)

This stylesheet has been changed so that markdown tables are rendered in the preview with full borders on all sides of each cell. This matches with the view on GitHub.

To install this file, copy it to *C:\Program Files (x86)\Microsoft VS Code\resources\app\out\vs\languages\markdown\common*. I suggest making a backup copy of the original file first.

> **NOTE**<br />
> It is possible that this file could get overwritten when VSCode is updated each month.

## [markdown.json](markdown.json)
This file contains reusable snippets that will auto-insert blocks of markdown text.

One of the snippets will autogenerate the metadata header for your content. You need to edit this section of the json file to customize it for your author name and content areas.

Copy this file to %USERPROFILE%\AppData\Roaming\Code\User\snippets

For more information on using this Content Wiki article: [Azure.com Markdown extension snippets](https://microsoft.sharepoint.com/teams/azurecontentguidance/wiki/Pages/Azure.com%20Markdown%20extension%20snippets.aspx)

## [specialchars.md](specialchars.md)
This shows examples of how to encode special characters in markdown so that they are render in a browser-agnostic way.

## [acom-rewrite-fix.reg](acom-rewrite-fix.reg)

To successfully run ACOM on your local development machine, you need to increase the file size limit for ASP.NET configuration files. This process requires editing registry settings.

Import this registry file on the computer where Visual Studio is installed. For more information, see http://acomdocs.azurewebsites.net/articles/contributing-acom-increase-config-limit/

You also may need to enable SSL for the project and use the port number displayed in the SSL URL settings.
