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
    Get-ChildItem $path -Recurse:$recurse | ForEach-Object{
      $file = $_.fullname
      $doc = Get-Content $file
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
        try {
          $hdr | ConvertFrom-YAML | Set-Variable temp
          $meta = [ordered]@{
            file = ''
            author = ''
            'ms.author' = ''
            'ms.date' = ''
            'ms.prod' = ''
            'ms.technology' = ''
            'ms.topic' = ''
            'contributor' = ''
            'keywords' = ''
            'description' = ''
            'Download Help Link' = ''
            'external help file' = ''
            'Help Version' = ''
            'Locale' = ''
            'Module Guid' = ''
            'Module Name' = ''
            'ms.assetid' = ''
            'online version' = ''
            'redirect_url' = ''
            'schema' = ''
            'title' = ''
          }
          $meta.file = $_
          foreach ($item in $temp.Keys) {
            $meta.$item = $temp.$item
          }
          new-object -type psobject -prop $meta
        }
        catch {
          Write-Warning -Message ("File: {0}`r`n{1}" -f $file, $Error[0].Exception.InnerException.Message)
          $Error.Clear()
        }
      }
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
#endregion
#-------------------------------------------------------
