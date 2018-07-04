#$regtm = "\xAE"
#$mdash = [System.Text.Encoding]::UTF8.GetString([byte[]](0xEF,0xBF,0xBD))
#$closeq = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2,0x80,0x9D))
#$openq = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2,0x80,0x9C))
#$checks = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2,0x88,0x9A))
#$apos = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2,0x80,0x99))
#dir *.md -rec | %{ 
#  if (Select-String -path $_ -pattern $regtm,$openq,$closeq,$mdash) { 
#    $mdtext = gc $_ -enc UTF8
#    $newtext = $mdtext -replace $regtm,"&reg;"
#    $newtext = $newtext -replace $mdash,"-"
#    $newtext = $newtext -replace $closeq,'"'
#    $newtext = $newtext -replace $openq,'"'
#    $newtext = $newtext -replace $checks ,'&check;'
#    $newtext = $newtext -replace $apos ,"'"
#    if ($mdtext -ne $newtext) { 
#      $_.fullname
#      $newtext | set-content $_ -enc UTF8 
#    }
#  } 
#}

$chars = @{ 
  regtm = (0xC2,0xAE)
  mdash = 0x96
  close1q = 0x91
  open1q = 0x92
  close2q = 0x94
  open2q = 0x93
  dblquot = (0xEF,0xBF,0xBD)
}

dir *.md -rec | %{
  $newtext = ([System.Collections.ArrayList]@())
  $found = $false
  $mdtext = gc -enc byte $_

  foreach ($char in $chars.keys) {
    if ($mdtext -contains $chars[$char][0]) { 
      $found = $true
      break
    }
  }
  if ($found) {
    $x = 0
    foreach ($b in $mdtext) {
       switch ($b) {
         $chars.regtm[0] {
           if ($mdtext[$x+1] -eq 0xAE) {
             $r = $newtext.Add(([byte][char]'&'))
             $r = $newtext.Add(([byte][char]'r'))
             $r = $newtext.Add(([byte][char]'e'))
             $r = $newtext.Add(([byte][char]'g'))
             $r = $newtext.Add(([byte][char]';'))
           } else {
             $r = $newtext.Add($mdtext[$x])
             $r = $newtext.Add($mdtext[($x+1)])
           }
         }
         $chars.mdash {$r = $newtext.Add(([byte][char]'-'))}
         $chars.close1q {$r = $newtext.Add(([byte][char]"'"))}
         $chars.open1q {$r = $newtext.Add(([byte][char]"'"))}
         $chars.close2q {$r = $newtext.Add(([byte][char]'"'))}
         $chars.open2q {$r = $newtext.Add(([byte][char]'"'))}
         $chars.dblquot[0] {
           if (($mdtext[$x+1] -eq 0xBF) -and ($mdtext[$x+2] -eq 0xBD)) {
             $r = $newtext.Add(([byte][char]'"'))
           } else {
             $r = $newtext.Add($mdtext[$x])
             $r = $newtext.Add($mdtext[($x+1)])
             $r = $newtext.Add($mdtext[($x+2)])
           }
         }
         0xAE {}
         0xBF {}
         0xBD {}
         default { $r = $newtext.Add($b) }
       }
       $x++
    }
    if ($mdtext -ne $newtext) {
      $_.fullname
      $newtext | set-content $_ -enc byte
    }
  }
}
