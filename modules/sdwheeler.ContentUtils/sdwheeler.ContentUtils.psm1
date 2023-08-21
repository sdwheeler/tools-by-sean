#-------------------------------------------------------
#region Private functions
#-------------------------------------------------------
function GetDocsVersions {
    Get-ChildItem D:\Git\PS-Docs\PowerShell-Docs\reference -dir |
    Where-Object Name -Match '\d\.\d' |
    Select-Object -ExpandProperty Name
}
#-------------------------------------------------------
#endregion Private functions
#-------------------------------------------------------
#region Public functions
#-------------------------------------------------------
function Edit-PSDoc {
    param(
        [Parameter(Mandatory)]
        [string[]]$Cmdlet,
        [string]$Version = '7.3',
        [string]$basepath = 'D:\Git\PS-Docs\PowerShell-Docs\reference'
    )

    $aboutFolders = '\Microsoft.PowerShell.Core\About', '\Microsoft.PowerShell.Security\About',
    '\Microsoft.WSMan.Management\About', '\PSReadLine\About'

    $pathlist = @()
    foreach ($c in $Cmdlet) {
        if ($c -like 'about_*') {
            $result = @()
            foreach ($folder in $aboutFolders) {
                $aboutPath = (Join-Path -Path $basepath -child $version -add $folder, ($c + '.md'))
                if (Test-Path $aboutPath) { $result += $aboutPath }
            }
            if ($result.Count -gt 0) {
                $pathlist += $result | Sort-Object -Descending | Select-Object -First 1
            }
        } else {
            $cmd = Get-Command $c
            if ($cmd) {
                $pathParams = @{
                    Path                = $basepath
                    ChildPath           = $Version
                    AdditionalChildPath = $cmd.Source, ($cmd.Name + '.*')
                    Resolve             = $true
                }
                $path = Join-Path @pathParams
                if ($path) { $pathlist += $path }
            }
        }
    }
    if ($pathlist.Count -gt 0) {
        code ($pathlist)
    }
}
Set-Alias -Name edit -Value Edit-PSDoc
#-------------------------------------------------------
function Get-ArticleCount {
    $repoPath = $git_repos['PowerShell-Docs'].path
    Push-Location "$repoPath\reference"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs'
        reference  = [int](Get-ChildItem .\5.1\, .\7.2\, .\7.3\, .\7.4\ -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
        conceptual = [int](Get-ChildItem docs-conceptual -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-DSC'].path
    Push-Location "$repoPath\dsc"
    $refdocs = (Get-ChildItem docs-conceptual\dsc-1.1\reference,
        docs-conceptual\dsc-2.0\reference  -Filter *.md -rec).count
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-DSC'
        reference  = (Get-ChildItem dsc-1.1, dsc-2.0, dsc-3.0 -Filter *.md -rec).count + $refdocs
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count - $refdocs
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-Modules'].path
    Push-Location "$repoPath\reference"
    $rulesref = (Get-ChildItem docs-conceptual\PSScriptAnalyzer\Rules -Filter *.md -rec).count
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-Modules'
        reference  = (Get-ChildItem ps-modules -Filter *.md -rec).count + $rulesref
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count - $rulesref
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-PSGet'].path
    Push-Location "$repoPath\powershell-gallery"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-PSGet'
        reference  = (Get-ChildItem powershellget-1.x, powershellget-2.x, powershellget-3.x -Filter *.md -rec).count
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count
    }
    Pop-Location

    $repoPath = $git_repos['azure-docs-pr'].path
    Push-Location "$repoPath\articles\cloud-shell"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/azure-docs-pr:cloud-shell'
        reference  = 0
        conceptual = (Get-ChildItem *.md,*.yml -rec).count
    }

    Set-Location "$repoPath\articles\governance\machine-configuration"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/azure-docs-pr:machine-config'
        reference  = 0
        conceptual = (Get-ChildItem *.md,*.yml -rec).count
    }
    Pop-Location

    $repoPath = $git_repos['powershell-docs-sdk-dotnet'].path
    Push-Location "$repoPath\dotnet"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/powershell-docs-sdk-dotnet'
        reference  = [int](Get-ChildItem *.xml -file -rec |
                        Measure-Object).Count
        conceptual = 0
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-archive'].path
    Push-Location "$repoPath\archived-reference"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-archive'
        reference  = [int](Get-ChildItem .\3.0, .\4.0, .\5.0, .\6\, .\7.0, .\7.1\ -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
        conceptual = [int](Get-ChildItem docs-conceptual -file -rec |
                        Group-Object Extension |
                        Where-Object { $_.name -in '.md','.yml'} |
                        Measure-Object count -sum).Sum
    }
    Pop-Location
}
#-------------------------------------------------------
function Get-ArticleIssueTemplate {
    param(
        [uri]$articleurl
    )
    $meta = Get-HtmlMetaTags $articleurl

    if ($meta.'ms.prod') {
        $product = "* Product: **$($meta.'ms.prod')**"
        if ($meta.'ms.technology') {
            $product += "`r`n* Technology: **$($meta.'ms.technology')**"
        }
    } elseif ($meta.'ms.service') {
        $product = "* Service: **$($meta.'ms.service')**"
        if ($meta.'ms.subservice') {
            $product += "`r`n* Sub-service: **$($meta.'ms.subservice')**"
        }
    }
    $template = @"
---
#### Document Details

⚠ *Do not edit this section. It is required for docs.microsoft.com ➟ GitHub issue linking.*

* ID: $($meta.document_id)
* Version Independent ID: $($meta.'document_version_independent_id')
* Content: [$($meta.title)]($($meta.articleurl))
* Content Source: [$(($meta.original_content_git_url -split '/live/')[-1])]($($meta.original_content_git_url))
$product
* GitHub Login: @$($meta.author)
* Microsoft Alias: **$($meta.'ms.author')**
"@
    $template
}
#-------------------------------------------------------
function Get-DocsUrl {
    param(
        [string]$filepath,
        [switch]$show
    )
    $folders = (GetDocsVersions), 'docs-conceptual'
    $learnUrl = 'https://learn.microsoft.com/powershell/'
    Push-Location (Get-Item ((Get-GitStatus).GitDir) -Force).Parent
    try {
        $file = Get-Item $filepath -ErrorAction Stop
        $relpath = (Resolve-Path $file -Relative).Trim('.\').Replace('\', '/').Replace($file.Extension,'')
        $parts = $relpath -split '/'
        if (($parts[0] -ne 'reference') -and ($parts[1] -notin $folders)) {
            Write-Error "No docs url published for $filepath"
            return
        } else {
            if ($parts[1] -eq 'docs-conceptual') {
                $url = $relpath.Replace('reference/docs-conceptual/', ($learnUrl + 'scripting/'))
            } else {
                $moniker = "?view=powershell-$($parts[1])"
                $url = $relpath.Replace("reference/$($parts[1])/", ($learnUrl + 'module/')) + $moniker
            }
            if ($show) {
                Start-Process $url
            } else {
                Write-Output $url
            }
        }
    } catch {
        $_.Exception.ErrorRecord.Exception.Message
    }
}
#-------------------------------------------------------
function Get-MDRule {
    param(
        [string[]]$Rule
    )
    $url = 'https://raw.githubusercontent.com/DavidAnson/markdownlint/main/doc/Rules.md'
    $rules = (Invoke-WebRequest $url).Content.split("`n") |
        Select-String -Pattern '^##[\s~]+`MD' -Raw
    if ($Rule) {
        $pattern = $Rule -join '|'
        $rules | Select-String -Pattern $pattern -Raw
    } else {
        $rules
    }
}
#-------------------------------------------------------
function Get-VersionedContent {
<#
.SYNOPSIS
This script extracts content from a markdown file that uses moniker ranges.

.DESCRIPTION
This script extracts content from a markdown file that uses moniker ranges. It allows you to split a markdown file that contains multiple moniker ranges into multiple files, each containing content for a single moniker.

.PARAMETER Path
The path to the markdown file to be processed. This can be a folder or a file. You can use wildcards to specify multiple files.

.PARAMETER Moniker
The moniker for the version of content to be extracted.

.PARAMETER OutputPath
The location where you want the extracted files to be placed. If the folder does not exist, it will be created.

.EXAMPLE
Get-VersionedContent -Path marketing\integrations\community-management\organizations\*.md -Moniker li-lms-2022-07 -OutputPath .\li-lms-2022-07
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SupportsWildcards()]
        [string[]]$Path,

        [Parameter(Mandatory)]
        [string]$Moniker,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    if (!(Test-Path $OutputPath)) {
        mkdir $OutputPath
    }

    Get-ChildItem $Path | ForEach-Object {
        $mdtext = Get-Content $_
        $newtext = @()
        $currentMoniker = ''
        $op = '='
        foreach ($line in $mdtext) {
            if ($line -match ':::\s?moniker') {
                if ($line -match ':::\s?moniker-end') {
                    $currentMoniker = ''
                    $op = '='
                } else {
                    if ($line -match ':::\s?moniker\srange="(?<op>=|>=|>|<|<=)?(?<moniker>[\w-]+)"') {
                        $currentMoniker = $Matches.moniker
                        $op = $Matches.op
                    }
                }
                $newtext += $line
            } else {
                if ($currentMoniker -eq '') {
                    $newtext += $line # Line is not in a moniker range
                } else {
                    # Check to see if Line is in the current moniker range
                    switch ($op) {
                        '='  {
                            if ($Moniker -eq $currentMoniker) {
                                $newtext += $line
                            }
                        }
                        '<'  {
                            if ($Moniker -lt $currentMoniker) {
                                $newtext += $line
                            }
                        }
                        '>'  {
                            if ($Moniker -gt $currentMoniker) {
                                $newtext += $line
                            }
                        }
                        '>=' {
                            if ($Moniker -ge $currentMoniker) {
                                $newtext += $line
                            }
                        }
                        '<=' {
                            if ($Moniker -le $currentMoniker) {
                                $newtext += $line
                            }
                        }
                    }
                }
            }
        }

        $newtext | Out-File -FilePath "$outputPath\$($_.name)" -Encoding utf8
    }
}
#-------------------------------------------------------
function Show-Help {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$topic,

        [ValidateScript({$_ -in (GetDocsVersions)})]
        [string]$Version = $PSVersionTable.PSVersion.ToString().SubString(0,3),

        [switch]$UseBrowser
    )

    $aboutpath = @(
        'Microsoft.PowerShell.Core\About',
        'Microsoft.PowerShell.Security\About',
        'Microsoft.WsMan.Management\About',
        'PSDesiredStateConfiguration\About',
        'PSReadline\About',
        'PSScheduledJob\About',
        'PSWorkflow\About'
    )

    $repoPath = $git_repos['PowerShell-Docs'].path
    $basepath = "$repoPath\reference"
    if ($version -eq '7') { $version = '7.0' }
    if ($version -eq '5') { $version = '5.1' }

    if ($topic -like 'about*') {
        foreach ($path in $aboutpath) {
            $cmdlet = ''
            $mdpath = '{0}\{1}\{2}.md' -f $version, $path, $topic
            if (Test-Path "$basepath\$mdpath") {
                $cmdlet = $topic
                break
            }
        }
    } else {
        $cmdlet = Get-Command $topic
        if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }
        $mdpath = '{0}\{1}\{2}.md' -f $version, $cmdlet.ModuleName, $cmdlet.Name
    }

    if ($cmdlet) {
        if (Test-Path "$basepath\$mdpath") {
            Get-ContentWithoutHeader "$basepath\$mdpath" |
                Out-String |
                Show-Markdown -UseBrowser:$UseBrowser
        } else {
            Write-Error "$mdpath not found!"
        }
    } else {
        Write-Error "$topic not found!"
    }
}
#-------------------------------------------------------
function Switch-WordWrapSettings {
    $settingsfile = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
    $c = Get-Content $settingsfile
    $s = ($c | Select-String -Pattern 'editor.wordWrapColumn', 'reflowMarkdown.preferredLineLength', 'editor.rulers').line
    $n = $s | ForEach-Object {
        if ($_ -match '//') {
            $_ -replace '//'
        } else {
            $_ -replace ' "', ' //"'
        }
    }
    for ($x = 0; $x -lt $s.count; $x++) {
        $c = $c -replace [regex]::Escape($s[$x]), $n[$x]
        #if ($n[$x] -notlike "*//*") {$n[$x]}
    }
    Set-Content -Path $settingsfile -Value $c -Force
}
Set-Alias -Name ww -Value Switch-WordWrapSettings
#-------------------------------------------------------
#-------------------------------------------------------
$sbDocVersions = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    GetDocsVersions |
        Where-Object {$_ -like "*$wordToComplete*"} |
        ForEach-Object { "'$_'" }
}
$cmdlist = 'Show-Help'
Register-ArgumentCompleter -ParameterName Version -ScriptBlock $sbDocVersions -CommandName $cmdList
#-------------------------------------------------------
#endregion Public functions
#-------------------------------------------------------
#region Argument completers
#-------------------------------------------------------
$cmdlist = 'Show-Help'
$sbDocVersions = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    GetDocsVersions |
        Where-Object {$_ -like "*$wordToComplete*"} |
        ForEach-Object { "'$_'" }
}
$registerArgumentCompleterSplat = @{
    ParameterName = 'Version'
    ScriptBlock = $sbDocVersions
    CommandName = $cmdList
}
Register-ArgumentCompleter @registerArgumentCompleterSplat
#-------------------------------------------------------
#endregion Argument completers
#-------------------------------------------------------
