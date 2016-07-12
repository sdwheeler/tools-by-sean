#requires -Version 3

$articlepattern = '[^!]\[(?<label>(?<!\!INCLUDE\[)([^\[\]]*))\]\(((?<file>[^)#]*)?)((?<bkmk>#[^)]*)?)\)'
  $hash = new-object -type psobject -prop @{
    link = ""
    linktype = ""
    file = ""
    fullpath = ""
    fulllink = ""
  }

dir *.md -rec | ForEach-Object {
  $filename = $_.name
  $filepath = $_.fullname
  $hash.link = $filename
  $hash.linktype = "self"
  $hash.file = $filename
  $hash.fullpath = $filepath
  $hash
  if (select-string -path $filepath -Pattern $articlepattern) {
    Get-Content $filepath | ForEach-Object {
      if ($_ -match $articlepattern) {
        foreach ($m in $matches) {
          $target = ($m.file -split "/")[-1]
          if ($target.EndsWith('.md')) {
            $hash.link = $target
            if ($filename -eq "TOC.md") {
              $hash.linktype = "TOC"
            } else {
              $hash.linktype = "topic"
            }
            $hash.file = $filename
            $hash.fullpath = $filepath
            $hash.fulllink = $m.file
            $hash
          }
        }
      }
    }
  }
}

