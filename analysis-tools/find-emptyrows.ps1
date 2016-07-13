dir *.md -rec | % { 
  select-string -path $_ -Pattern "^\s*(\|\s*\|\s*\|)(\s*\|)*$" | 
    select LineNumber,Path
}