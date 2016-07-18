#requires -Version 3

$linkpattern = '(?<mdlink>\[(?<text>[^\]]*)\]\((?<link>(?<path>[^\)#]*)?(?<bkmk>#[^\)\s]*)?)\s*(?<title>[^\)]*)?\))'
$simplepattern = '\[[^\]]*\]\([^\)]*\)'

dir *.md -rec | ForEach-Object {
  $filename = $_.name
  $filepath = $_.fullname

    $hash = new-object -type psobject -prop ([ordered]@{
      linkfile = ""
      linkpath = ""
      linktype = ""
      srcfile  = ""
      fullpath = ""
      label    = ""
      bookmark = ""
      title    = ""
    })

  $hash.linkfile = $filename
  $hash.linktype = "self"
  $hash.srcfile  = $filename
  $hash.fullpath = $filepath
  $hash

  $finds = (select-string -path $filepath -Pattern $simplepattern -AllMatches).Matches
  foreach ($find in $finds.Value) {
    if ($find -match $linkpattern) {
      $target = ($Matches["path"] -split "/")[-1]
      $hash.linkfile = $target
      $hash.linkpath = $Matches["path"]
      $hash.linktype = "topic"
      if ($filename -eq "TOC.md") { $hash.linktype = "TOC" }
      $hash.srcfile  = $filename
      $hash.fullpath = $filepath
      $hash.label    = $Matches["text"]
      $hash.bookmark = $Matches["bkmk"]
      $hash.title    = $Matches["title"]
      $hash
    }
  }
}

