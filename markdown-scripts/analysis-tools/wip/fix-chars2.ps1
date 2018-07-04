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
  q1open  = 0x90
  q1close = 0x91
  q2open  = 0x92
  q2close = 0x94
  ndash   = 0x96
  mdash   = 0x97
  tm      = 0x99
  copy    = 0xA9
  regtm   = 0xAE
}

dir *.md -rec | %{
  $newtext = ([System.Collections.ArrayList]@())
  $found = $false
  $mdtext = gc $_ -enc byte 

  $_.fullname

  foreach ($char in $chars.keys) {
    if ($mdtext -contains $chars[$char]) { 
      "-- characters found"
      $found = $true
      break
    }
  }
  if ($found) {
    for ($x=0; $x -lt $mdtext.Length;  $x++) {
      if ($mdtext[$x] -lt 0x7f) {
        $r = $newtext.Add($mdtext[$x]) 
      } else {
        switch ($mdtext[$x]) {
          $chars.reg {
            $r = $newtext.Add(([byte][char]'&'))
            $r = $newtext.Add(([byte][char]'r'))
            $r = $newtext.Add(([byte][char]'e'))
            $r = $newtext.Add(([byte][char]'g'))
            $r = $newtext.Add(([byte][char]';'))
          }
          $chars.copy {
            $r = $newtext.Add(([byte][char]'&'))
            $r = $newtext.Add(([byte][char]'c'))
            $r = $newtext.Add(([byte][char]'o'))
            $r = $newtext.Add(([byte][char]'p'))
            $r = $newtext.Add(([byte][char]'y'))
            $r = $newtext.Add(([byte][char]';'))
          }
          $chars.tm {
            $r = $newtext.Add(([byte][char]'&'))
            $r = $newtext.Add(([byte][char]'t'))
            $r = $newtext.Add(([byte][char]'r'))
            $r = $newtext.Add(([byte][char]'a'))
            $r = $newtext.Add(([byte][char]'d'))
            $r = $newtext.Add(([byte][char]'e'))
            $r = $newtext.Add(([byte][char]';'))
          }
          $chars.ndash {$r = $newtext.Add(([byte][char]'-'))}
          $chars.mdash {$r = $newtext.Add(([byte][char]'-'))}
          $chars.q1close {$r = $newtext.Add(([byte][char]"'"))}
          $chars.q1open {$r = $newtext.Add(([byte][char]"'"))}
          $chars.q2close {$r = $newtext.Add(([byte][char]'"'))}
          $chars.q2open {$r = $newtext.Add(([byte][char]'"'))}
          default { 
            # skip this high bit char - do nothing 
          }
        } # end switch
      } # end if high-bit
    } # end for loop
    $newtext | set-content $_ -enc byte
  } # end if found
}
