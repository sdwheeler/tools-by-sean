#-------------------------------------------------------
#region Content Scripts
function bcsync {
  param([string]$path)
  $basepath = 'C:\Git\PS-Docs\PowerShell-Docs\reference\'
  $startpath = (get-item $path).fullname
  $vlist = '5.1','6','7.0','7.1','7.2'
  if ($startpath) {
    $relpath = $startpath -replace [regex]::Escape($basepath)
    $version = ($relpath -split '\\')[0]
    foreach ($v in $vlist) {
      if ($v -ne $version) {
        $target = $startpath -replace [regex]::Escape($version), $v
        if (Test-Path $target) {
          Start-Process -wait "${env:ProgramFiles}\Beyond Compare 4\BComp.exe" -ArgumentList $startpath,$target
        }
      }
    }
  } else {
      "Invalid path: $path"
  }
}
function Get-ContentWithoutHeader {
  param(
    $path
  )

  $doc = Get-Content $path -Encoding UTF8
  $start = $end = -1

 # search the the first 30 lines for the Yaml header
 # no yaml header in our docset will ever be that long

  for ($x = 0; $x -lt 30; $x++) {
    if ($doc[$x] -eq '---') {
      if ($start -eq -1) {
        $start = $x
      } else {
        if ($end -eq -1) {
          $end = $x+1
          break
        }
      }
    }
  }
  if ($end -gt $start) {
    Write-Output ($doc[$end..$($doc.count)] -join "`r`n")
  } else {
    Write-Output ($doc -join "`r`n")
  }
}

function Get-DocsUrl {
  param(
      [string]$filepath,
      [switch]$show
  )
  $folders = '5.1','6','7.0','7.1','docs-conceptual'
  try {
      $file = Get-Item $filepath -ErrorAction Stop
      $reporoot = (Get-Item (Get-GitStatus).GitDir -force).Parent.FullName
      $relpath = ($file.FullName -replace [regex]::Escape($reporoot)).Trim('\') -replace '\\','/'
      $parts = $relpath -split '/'
      if (($parts[0] -ne 'reference') -and ($parts[1] -notin $folders)) {
          Write-Verbose "No docs url published for $filepath"
      } else {
          if ($parts[1] -eq 'docs-conceptual') {
              $url = ($relpath -replace 'reference/docs-conceptual', 'https://docs.microsoft.com/powershell/scripting/').TrimEnd($file.Extension).TrimEnd('.')
          } else {
              $ver = $parts[1]
              $moniker = "?view=powershell-$ver".TrimEnd('.0')
              $url = (($relpath -replace "reference/$ver", 'https://docs.microsoft.com/powershell/module') -replace $file.Extension).TrimEnd('.') + $moniker
          }
          if ($show) {
              start $url
          } else {
              Write-Output $url
          }
      }
  }
  catch {
      $_.Exception.ErrorRecord.Exception.Message
  }
}
function Show-Help {
  param(
    [string]$cmd,

    [ValidateSet('5.1','6','7','7.0','7.1')]
    [string]$version='7.0',

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

  $basepath = 'C:\Git\PS-Docs\PowerShell-Docs\reference'
  if ($version -eq '7') {$version = '7.0'}
  if ($version -eq '5') {$version = '5.1'}

  if ($cmd -like 'about*') {
    foreach ($path in $aboutpath) {
      $cmdlet = ''
      $mdpath = '{0}\{1}\{2}.md' -f $version, $path, $cmd
      if (Test-Path "$basepath\$mdpath") {
        $cmdlet = $cmd
        break
      }
    }
  } else {
    $cmdlet = Get-Command $cmd
    if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }
    $mdpath = '{0}\{1}\{2}.md' -f $version, $cmdlet.ModuleName, $cmdlet.Name
  }

  if ($cmdlet) {
    if (Test-Path "$basepath\$mdpath") {
      Get-ContentWithoutHeader "$basepath\$mdpath" |
        Show-Markdown -UseBrowser:$UseBrowser
    } else{
      write-error "$mdpath not found!"
    }
  } else {
    write-error "$cmd not found!"
  }
}

function get-metatags {
  param(
    [uri]$articleurl,
    [switch]$ShowRequiredMetadata
  )

  $hash = [ordered]@{}

  $x = iwr $articleurl
  $lines = (($x -split "`n").trim() | select-string -Pattern '\<meta').line | %{
      $_.trimstart('<meta ').trimend(' />') | sort
  }
  $pattern = '(name|property)="(?<key>[^"]+)"\s*content="(?<value>[^"]+)"'
  foreach ($line in $lines){
      if ($line -match $pattern) {
        if ($hash.Contains($Matches.key)) {
            $hash[($Matches.key)] += ',' + $Matches.value
          } else {
            $hash.Add($Matches.key,$Matches.value)
          }
      }
  }

  $result = new-object -type psobject -prop ($hash)
  if ($ShowRequiredMetadata) {
    $result | select title,description,'ms.manager','ms.author',author,'ms.service','ms.date','ms.topic','ms.subservice','ms.prod','ms.technology','ms.custom','ROBOTS'
  } else {
    $result
  }
}
function get-articleissuetemplate {
  param(
    [uri]$articleurl
  )
  $meta = get-metatags $articleurl

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
function hash2yaml {
  param( $meta )
  ForEach-Object {
      "---"
      ForEach ($key in ($meta.keys | Sort-Object)) {
          if ('' -ne $meta.$key) {
              '{0}: {1}' -f $key, $meta.$key
          }
      }
      "---"
  }
}

function get-yamlblock {
  param($mdpath)
  $doc = Get-Content $mdpath
  $start = $end = -1
  $hdr = ""

  for ($x = 0; $x -lt 30; $x++) {
  if ($doc[$x] -eq '---') {
      if ($start -eq -1) {
      $start = $x + 1
      } else {
      if ($end -eq -1) {
          $end = $x - 1
          break
      }
      }
  }
  }
  if ($end -gt $start) {
  $hdr = $doc[$start..$end]
  $hdr
  }
}

function get-metadata {
  param(
      $path,
      [switch]$Recurse
  )


  foreach ($file in (dir -rec:$Recurse -file $path)) {
      $ignorelist = 'keywords','helpviewer_keywords','ms.assetid'
      $lines = get-yamlblock $file
      $meta = @{}
      #$meta.Add('path',$file.name)
      foreach ($line in $lines) {
          $i = $line.IndexOf(':')
          if ($i -ne -1) {
              $key = $line.Substring(0,$i)
              if (!$ignorelist.Contains($key)) {
                  $value = $line.Substring($i+1).replace('"','')
                  switch ($key) {
                      'title' {

                          $value = $value.split('|')[0].trim()
                      }
                      'ms.date' {
                          $value = Get-Date $value -Format 'MM/dd/yyyy'
                      }
                      Default {
                          $value = $value.trim()
                      }
                  }

                  $meta.Add($key,$value)
              }
          }
      }
      [pscustomobject]@{
          file = $file.fullname
          metadata = [pscustomobject]$meta
      }
  }
}
#-------------------------------------------------------
function get-docmetadata {
  param(
    $path='*.md',
    [switch]$recurse
  )

  $docfxmetadata = (Get-Content .\docfx.json | ConvertFrom-Json -AsHashtable).build.fileMetadata

  Get-ChildItem $path -Recurse:$recurse | ForEach-Object {
    get-yamlblock $_.fullname | ConvertFrom-YAML | Set-Variable temp
    $filemetadata = [ordered]@{
      file = $_.fullname -replace '\\','/'
      author = ''
      'ms.author' = ''
      'manager' = ''
      'ms.date' = ''
      'ms.prod' = ''
      'ms.technology' = ''
      'ms.topic' = ''
      'title' = ''
      'keywords' = ''
      'description' = ''
      'online version' = ''
      'external help file' = ''
      'Module Name' = ''
      'ms.assetid' = ''
      'Locale' = ''
      'schema' = ''
    }
    foreach ($item in $temp.Keys) {
      if ($temp.$item.GetType().Name -eq 'Object[]') {
        $filemetadata.$item = $temp.$item -join ','
      } else {
        $filemetadata.$item = $temp.$item
      }
    }

    foreach ($prop in $docfxmetadata.keys) {
      if ($filemetadata.$prop -eq '') {
        foreach ($key in $docfxmetadata.$prop.keys) {
          $pattern = ($key -replace '\*\*','.*') -replace '\.md','\.md'
          if ($filemetadata.file -match $pattern) {
            $filemetadata.$prop = $docfxmetadata.$prop.$key
            break
          }
        }
      }
    }
    new-object -type psobject -prop $filemetadata
  }
}

#-------------------------------------------------------
function Get-MDLinks {
    param(
      [string]$filepath
    )
    $linkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#\?]*)?(?<anchor>#[^\?]+)?)(?<query>\?[^#]+)?\)'
    $mdtext = Select-String -Path $filepath -Pattern $linkpattern
    $mdtext | ForEach-Object -Process {
      if ($_ -match $linkpattern)
      {
        Write-Output $Matches |
        Select-Object @{l='link';e={$_.link}},
        @{l='label';e={$_.label}},
        @{l='file';e={$_.file}},
        @{l='anchor';e={$_.anchor}},
        @{l='query';e={$_.query}}
      }
    }
}
#-------------------------------------------------------
function make-linkrefs {
  param([string[]]$path)
  foreach ($p in $path) {
    $linkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#]*)?(?<anchor>#.+)?\))'
    $mdtext = Select-String -Path $p -Pattern $linkpattern

    $mdtext.matches| ForEach-Object{
      $link = @()
      foreach ($g in $_.Groups) {
        if ($g.Name -eq 'label') { $link += $g.value }
        if ($g.Name -eq 'file') { $link += $g.value }
        if ($g.Name -eq 'anchor') { $link += $g.value }
      }
      "[{0}]: {1}{2}" -f $link #$link[0],$link[1],$link[2]
    }
  }
}
#-------------------------------------------------------
function do-pandoc {
  param($aboutFile)
  $file = get-item $aboutFile
  $aboutFileOutputFullName = $file.basename + '.help.txt'
  $aboutFileFullName = $file.fullname

  $pandocArgs = @(
      "--from=gfm",
      "--to=plain+multiline_tables+inline_code_attributes",
      "--columns=75",
      "--output=$aboutFileOutputFullName",
      "--quiet"
  )
  Get-ContentWithoutHeader $aboutFileFullName | & pandoc.exe $pandocArgs
}
#-------------------------------------------------------
function Get-Syntax {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true,Position=0)]
    [string]$cmdletname,
    [switch]$Markdown
  )

  function formatString {
    param(
        $cmd,
        $pstring
    )

    $parts = $pstring -split ' '
    $parameters = @()
    for ($x=0; $x -lt $parts.Count; $x++) {
      $p = $parts[$x]
      if ($x -lt $parts.Count-1) {
        if (!$parts[$x+1].StartsWith('[')) {
            $p += ' ' +  $parts[$x+1]
            $x++
        }
        $parameters += ,$p
      }
    }

    $line = $cmd + ' '
    $temp = ''
    for ($x=0; $x -lt $parameters.Count; $x++) {
        if ($line.Length+$parameters[$x].Length+1 -lt 100) {
            $line += $parameters[$x] + ' '
        } else {
            $temp += $line + "`r`n"
            $line = ' ' + $parameters[$x] + ' '
        }
    }
    $temp + $line.TrimEnd()
  }


  try {
    $cmdlet = Get-Command $cmdletname -ea Stop
    if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }

    $syntax = (Get-Command $cmdlet.name).ParameterSets |
      Select-Object -Property @{n='Cmdlet'; e={$cmdlet.name}},
                              @{n='ParameterSetName';e={$_.name}},
                              @{n='Parameters';e={$_.ToString()}}
  } catch [System.Management.Automation.CommandNotFoundException] {
    $_.Exception.Message
  }

  $mdHere = @'
### {0}

```
{1}
```

'@

  if ($Markdown) {
    foreach ($s in $syntax) {
      $string = $s.Cmdlet, $s.Parameters -join ' '
      if ($string.Length -gt 100) {
        $string = formatString $s.Cmdlet $s.Parameters
      }
      $mdHere -f $s.ParameterSetName, $string
    }
  } else {
      $syntax
  }
}
Set-Alias syntax Get-Syntax
#-------------------------------------------------------
function Get-OutputType {
  param([string]$cmd)
  Get-PSDrive | Sort-Object Provider -Unique | ForEach-Object{
    Push-Location $($_.name + ':')
    [pscustomobject] @{
      Provider = $_.Provider.Name
      OutputType = (Get-Command $cmd).OutputType.Name | Select-Object -uni
    }
    Pop-Location
  }
}
#-------------------------------------------------------
function Get-ShortDescription {
  $crlf = "`r`n"
  Get-ChildItem .\*.md | ForEach-Object{
    if ($_.directory.basename -ne $_.basename) {
        $filename = $_.Name
        $name = $_.BaseName
        $headers = Select-String -path $filename -Pattern '^## \w*' -AllMatches
        $mdtext = Get-Content $filename
        $start = $headers[0].LineNumber
        $end = $headers[1].LineNumber - 2
        $short = $mdtext[($start)..($end)] -join ' '
        if ($short -eq '') { $short = '{{Placeholder}}'}

        '### [{0}]({1}){3}{2}{3}' -f $name,$filename,$short.Trim(),$crlf
    }
  }
}
#-------------------------------------------------------
function Swap-WordWrapSettings {
  $settingsfile = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
  $c = Get-Content $settingsfile
  $s = ($c | Select-String -Pattern 'editor.wordWrapColumn', 'reflowMarkdown.preferredLineLength','editor.rulers').line
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
  set-content -path $settingsfile -value $c -force
}
Set-Alias -Name ww -Value Swap-WordWrapSettings
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
