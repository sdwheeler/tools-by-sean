$pattern = '^\s*(\|\s*\|)(\s*\|)+$'
dir *.md -rec | % {
  select-string -path $_ -Pattern $pattern |
    select Path | group-object Path | select count,name
}