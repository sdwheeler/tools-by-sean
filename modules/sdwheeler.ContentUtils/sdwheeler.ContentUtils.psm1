#-------------------------------------------------------
function Sync-BeyondCompare {
    param([string]$path)
    $repoPath = $git_repos['PowerShell-Docs'].path
    $basepath = "$repoPath\reference\"
    $startpath = (Get-Item $path).fullname
    $vlist = '5.1', '7.0', '7.1', '7.2', '7.3'
    if ($startpath) {
        $relpath = $startpath -replace [regex]::Escape($basepath)
        $version = ($relpath -split '\\')[0]
        foreach ($v in $vlist) {
            if ($v -ne $version) {
                $target = $startpath -replace [regex]::Escape($version), $v
                if (Test-Path $target) {
                    Start-Process -Wait "${env:ProgramFiles}\Beyond Compare 4\BComp.exe" -ArgumentList $startpath, $target
                }
            }
        }
    }
    else {
        "Invalid path: $path"
    }
}
Set-Alias bcsync Sync-BeyondCompare
#-------------------------------------------------------
function Get-ArticleCount {
    $repoPath = $git_repos['PowerShell-Docs'].path
    Push-Location "$repoPath\reference"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs'
        reference  = (Get-ChildItem .\5.1\, .\7.0\, .\7.1\, .\7.2\ -Filter *.md -rec).count
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-Modules'].path
    Push-Location "$repoPath\reference"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-Modules'
        reference  = (Get-ChildItem ps-modules -Filter *.md -rec).count
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count
    }
    Pop-Location

    $repoPath = $git_repos['PowerShell-Docs-DSC'].path
    Push-Location "$repoPath\dsc"
    [PSCustomObject]@{
        repo       = 'MicrosoftDocs/PowerShell-Docs-DSC'
        reference  = (Get-ChildItem dsc-1.1, dsc-2.0, dsc-3.0 -Filter *.md -rec).count
        conceptual = (Get-ChildItem docs-conceptual -Filter *.md -rec).count
    }
    Pop-Location
}
#-------------------------------------------------------
function Get-DocsUrl {
    param(
        [string]$filepath,
        [switch]$show
    )
    $folders = '5.1', '6', '7.0', '7.1', 'docs-conceptual'
    try {
        $file = Get-Item $filepath -ErrorAction Stop
        $reporoot = (Get-Item (Get-GitStatus).GitDir -Force).Parent.FullName
        $relpath = ($file.FullName -replace [regex]::Escape($reporoot)).Trim('\') -replace '\\', '/'
        $parts = $relpath -split '/'
        if (($parts[0] -ne 'reference') -and ($parts[1] -notin $folders)) {
            Write-Verbose "No docs url published for $filepath"
        }
        else {
            if ($parts[1] -eq 'docs-conceptual') {
                $url = ($relpath -replace 'reference/docs-conceptual', 'https://docs.microsoft.com/powershell/scripting/').TrimEnd($file.Extension).TrimEnd('.')
            }
            else {
                $ver = $parts[1]
                $moniker = "?view=powershell-$ver".TrimEnd('.0')
                $url = (($relpath -replace "reference/$ver", 'https://docs.microsoft.com/powershell/module') -replace $file.Extension).TrimEnd('.') + $moniker
            }
            if ($show) {
                Start-Process $url
            }
            else {
                Write-Output $url
            }
        }
    }
    catch {
        $_.Exception.ErrorRecord.Exception.Message
    }
}
#-------------------------------------------------------
function Show-Help {
    param(
        [string]$cmd,

        [ValidateSet('5.1', '6', '7', '7.0', '7.1')]
        [string]$version = '7.0',

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

    if ($cmd -like 'about*') {
        foreach ($path in $aboutpath) {
            $cmdlet = ''
            $mdpath = '{0}\{1}\{2}.md' -f $version, $path, $cmd
            if (Test-Path "$basepath\$mdpath") {
                $cmdlet = $cmd
                break
            }
        }
    }
    else {
        $cmdlet = Get-Command $cmd
        if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }
        $mdpath = '{0}\{1}\{2}.md' -f $version, $cmdlet.ModuleName, $cmdlet.Name
    }

    if ($cmdlet) {
        if (Test-Path "$basepath\$mdpath") {
            Get-ContentWithoutHeader "$basepath\$mdpath" |
                Show-Markdown -UseBrowser:$UseBrowser
        }
        else {
            Write-Error "$mdpath not found!"
        }
    }
    else {
        Write-Error "$cmd not found!"
    }
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
    }
    elseif ($meta.'ms.service') {
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
function Get-DocMetadata {
    param(
        $path = '*.md',
        [switch]$recurse
    )

    $docfxmetadata = (Get-Content .\docfx.json | ConvertFrom-Json -AsHashtable).build.fileMetadata

    Get-ChildItem $path -Recurse:$recurse | ForEach-Object {
        Get-YamlBlock $_.fullname | ConvertFrom-Yaml | Set-Variable temp
        $filemetadata = [ordered]@{
            file                 = $_.fullname -replace '\\', '/'
            author               = ''
            'ms.author'          = ''
            'manager'            = ''
            'ms.date'            = ''
            'ms.prod'            = ''
            'ms.technology'      = ''
            'ms.topic'           = ''
            'title'              = ''
            'keywords'           = ''
            'description'        = ''
            'online version'     = ''
            'external help file' = ''
            'Module Name'        = ''
            'ms.assetid'         = ''
            'Locale'             = ''
            'schema'             = ''
        }
        foreach ($item in $temp.Keys) {
            if ($temp.$item.GetType().Name -eq 'Object[]') {
                $filemetadata.$item = $temp.$item -join ','
            }
            else {
                $filemetadata.$item = $temp.$item
            }
        }

        foreach ($prop in $docfxmetadata.keys) {
            if ($filemetadata.$prop -eq '') {
                foreach ($key in $docfxmetadata.$prop.keys) {
                    $pattern = ($key -replace '\*\*', '.*') -replace '\.md', '\.md'
                    if ($filemetadata.file -match $pattern) {
                        $filemetadata.$prop = $docfxmetadata.$prop.$key
                        break
                    }
                }
            }
        }
        New-Object -type psobject -prop $filemetadata
    }
}
#-------------------------------------------------------
function Swap-WordWrapSettings {
    $settingsfile = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
    $c = Get-Content $settingsfile
    $s = ($c | Select-String -Pattern 'editor.wordWrapColumn', 'reflowMarkdown.preferredLineLength', 'editor.rulers').line
    $n = $s | ForEach-Object {
        if ($_ -match '//') {
            $_ -replace '//'
        }
        else {
            $_ -replace ' "', ' //"'
        }
    }
    for ($x = 0; $x -lt $s.count; $x++) {
        $c = $c -replace [regex]::Escape($s[$x]), $n[$x]
        #if ($n[$x] -notlike "*//*") {$n[$x]}
    }
    Set-Content -Path $settingsfile -Value $c -Force
}
Set-Alias -Name ww -Value Swap-WordWrapSettings
#-------------------------------------------------------
function Invoke-Pandoc {
    param(
        [string[]]$Path,
        [string]$OutputPath = '.',
        [switch]$Recurse
    )
    $pandocExe = 'C:\Program Files\Pandoc\pandoc.exe'
    dir $Path -Recurse:$Recurse | % {
        $outfile = Join-Path $OutputPath "$($_.BaseName).help.txt"
        $pandocArgs = @(
            "--from=gfm",
            "--to=plain+multiline_tables",
            "--columns=79",
            "--output=$outfile",
            "--quiet"
        )
        Get-ContentWithoutHeader $_ | & $pandocExe $pandocArgs
    }
}
#-------------------------------------------------------
