param([string]$mapfile)

function get-replacement {
  param($byteArr)
  $hexArr = @()
  $byteArr| %{ $hexArr += ('{0:X2}' -f $_) }
  $key = $hexArr -join " "
  $char = $charlist.$key
  $replacement = $byteArr
  if ($char) {
    if ($char.replace -eq "true") {
      $replacement = [System.Text.Encoding]::UTF8.GetBytes($char.alt)
    }
  } 
  Write-Output $replacement
}

$scripthome = (get-item $MyInvocation.MyCommand.Path).Directory

if ($mapfile -eq "") {
  $mapfile = "$scripthome\charlist.json"
}
$charlist = gc $mapfile | ConvertFrom-Json


dir *.md -rec | %{
  $mdtext = gc $_ -enc byte 
  $newtext = ([System.Collections.ArrayList]@())
  [byte[]]$hbits = @()
  
  foreach ($b in $mdtext) {
    if ($b -gt 0x7f) {
      switch ($hbits.Length) {
        0 {
          if ($b -le 0xC0) {
            $hbits += [byte]$b
            $tmpBytes = get-replacement $hbits
            $tmpBytes | %{ $r = $newtext.Add($_) }
            $hbits = @()
          } else {
            $hbits += [byte]$b
          }
        }
        1 {
          $x = [byte]("0x{0:X2}" -f $hbits[0])
          if ($b -le 0xbf) {
            if ($x -le 0xdf) {
              $hbits += [byte]$b
              $tmpBytes = get-replacement $hbits
              $tmpBytes | %{ $r = $newtext.Add($_) }
              $hbits = @()
            } else {
              $hbits += [byte]$b
            }
          } else {
            $tmpBytes = get-replacement $hbits
            $tmpBytes | %{ $r = $newtext.Add($_) }
            $hbits = @()
            $hbits += [byte]$b
          }
        }
        2 {
          if ($b -le 0xbf) {
            $hbits += [byte]$b
            $tmpBytes = get-replacement $hbits
            $tmpBytes | %{ $r = $newtext.Add($_) }
            $hbits = @()
          } else {
            $tmpBytes = get-replacement $hbits
            $tmpBytes | %{ $r = $newtext.Add($_) }
            $hbits = @()
            $hbits += [byte]$b
          }
        }
      } # end switch
    } else { # else lowbit
      $r = $newtext.Add([byte]$b)
    } # end if highbit
  } # end foreach byte

  if ($newtext -ne $mdtext) {
    $_.FullName
    [byte[]]$newtext | set-content $_ -enc byte
  }
} # end foreach file