dir *.md -rec | % { 
  select-string -path $_ -Pattern "^\s*(\|\s*\|\s*\|)(\s*\|)*$" | 
    select Path | group-object Path | select count,name
}