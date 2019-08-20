#-------------------------------------------------------
#region Content Scripts
function show-metatags {
    param(
      [uri]$url,
      [switch]$all
    )
    $tags = @('author', 'description', 'manager', 'ms.author', 'ms.date', 'ms.devlang', 'ms.manager', 'ms.prod',
      'ms.product', 'ms.service', 'ms.technology', 'ms.component', 'ms.tgt_pltfr', 'ms.topic', 'title'
    )
    $pagetags = @()
    $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36 Edge/15.15063'

    $page = Invoke-WebRequest -Uri $url -UserAgent $UserAgent
    if ($all) {
      $page.ParsedHtml.getElementsByTagName('meta') | where name |
      %{ $pagetags += new-object -type psobject -Property ([ordered]@{'name'=$_.name; 'content'=$_.content}) }
    } else {
      $page.ParsedHtml.getElementsByTagName('meta') | where name |
      where {$tags -contains $_.name} | %{ $pagetags += new-object -type psobject -Property ([ordered]@{'name'=$_.name; 'content'=$_.content}) }
    }
    $pagetags += new-object -type psobject -Property ([ordered]@{'name'='title'; 'content'=$page.ParsedHtml.title})
    $pagetags | sort name
}
#-------------------------------------------------------
function get-metadata {
  param(
    $path='*.md',
    [switch]$recurse
  )

  function get-yamlblock {
    param($mdpath)
    $doc = Get-Content $mdpath
    $start = $end = -1
    $hdr = ""

    for ($x = 0; $x -lt 30; $x++) {
      if ($doc[$x] -eq '---') {
        if ($start -eq -1) {
          $start = $x
        } else {
          if ($end -eq -1) {
            $end = $x
            break
          }
        }
      }
    }
    if ($end -gt $start) {
      $hdr = $doc[$start..$end] -join "`n"
      $hdr | ConvertFrom-YAML | Set-Variable temp
      $temp
    }
  }

  $docfxmetadata = (gc .\docfx.json | ConvertFrom-Json -AsHashtable).build.fileMetadata

  Get-ChildItem $path -Recurse:$recurse | ForEach-Object {
    $temp = get-yamlblock $_.fullname
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
      $filemetadata.$item = $temp.$item
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

    $mdtext.matches| %{
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
    [string]$cmdletname
  )

  $common = "Debug", "ErrorAction", "ErrorVariable", "InformationAction", "InformationVariable",
            "OutVariable", "OutBuffer", "PipelineVariable", "Verbose", "WarningAction", "WarningVariable"

  $cmdlet = gcm $cmdletname
  if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = gcm $cmdlet.Definition }
  $cmdletname = $cmdlet.name
  foreach ($ps in $cmdlet.parametersets) {
    $hasCommonParams = $false
    $syntax = @()
    $line = "$cmdletname "
    if ($ps.name -eq '__AllParameterSets') {
      $msg = '### All'
    } else {
      $msg = '### ' + $ps.name
    }
    if ($ps.isdefault) {
      $msg += ' (Default)'
    }
    $msg += "`r`n`r`n" + '```' + "`r`n"
    $ps.Parameters | %{
      $token = ''
      if ($common -notcontains $_.name) {
        if ($_.position -gt -1) {
          $token += '[-' + $_.name + ']'
        } else {
          $token += '-' + $_.name
        }
        if ($_.parametertype.name -ne 'SwitchParameter') {
          $token += ' <'+ $_.parametertype.name + '>'
        }
        if (-not $_.ismandatory) {
           $token = '[' + $token + ']'
        }
        if (($line.length + $token.Length) -gt 100) {
          $syntax += $line.TrimEnd()
          $line = " $token "
        } else {
          $line += "$token "
        }
      } else {
        $hasCommonParams = $true
      }
    }
    if ($hasCommonParams) {
      if ($line.length -ge 80) {
        $syntax += $line.TrimEnd()
        $syntax += ' [<CommonParameters>]'
      } else {
        $syntax += "$line [<CommonParameters>]"
      }
    }
    $msg += ($syntax -join  "`r`n") + "`r`n" + '```' + "`r`n"
    $msg
  } # end foreach ps
}
Set-Alias syntax Get-Syntax
#-------------------------------------------------------
function Get-ShortDescription {
  $crlf = "`r`n"
  dir .\*.md | %{
      $filename = $_.Name
      $name = $_.BaseName
      $headers = Select-String -path $filename -Pattern '^## \w*' -AllMatches
      $mdtext = gc $filename
      $start = $headers[0].LineNumber
      $end = $headers[1].LineNumber - 2
      $short = $mdtext[($start)..($end)] -join ' '
      if ($short -eq '') { $short = '{{Placeholder}}'}

      '### [{0}]({1}){3}{2}{3}' -f $name,$filename,$short.Trim(),$crlf
  }
}
#-------------------------------------------------------
function Swap-WordWrapSettings {
  $settingsfile = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
  $c = gc $settingsfile
  $s = ($c | Select-String -Pattern 'editor.wordWrapColumn','reflowMarkdown.preferredLineLength').line
  $n = $s | %{ if ($_ -match '//') { $_ -replace '//' } else {$_ -replace ' "', ' //"' }}
  for ($x=0; $x -lt $s.count; $x++) { $c = $c -replace $s[$x],$n[$x] }
  set-content -path $settingsfile -value $c -force
}

#endregion
#-------------------------------------------------------
