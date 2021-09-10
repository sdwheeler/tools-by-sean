param([string]$mapfile)


function addto-list {
  param([string[]]$bytes)
  if ($hbits.Length -gt 0) {
    $char = $bytes -join " "
    if ($script:list -notcontains $char) {
      $script:list += $char
    }
  }
}

$scripthome = (get-item $MyInvocation.MyCommand.Path).Directory

if ($mapfile -eq "") {
  $mapfile = "$scripthome\charlist.json"
}
$charlist = gc $mapfile | ConvertFrom-Json


$script:hbits = @()
$script:list = @()

dir *.md -rec | %{
  $mdtext = gc $_ -AsByteStream -Raw
  $script:hbits = @()
  $script:list = @()

  foreach ($b in $mdtext) {
    if ($b -gt 0x7f) {
      switch ($script:hbits.Length) {
        0 {
          if ($b -le 0xC0) {
            $script:hbits += ('{0:X2}' -f $b)
            addto-list $script:hbits
            $script:hbits = @()
          } else {
            $script:hbits += ('{0:X2}' -f $b)
          }
        }
        1 {
          $x = [byte]("0x{0:X2}" -f $hbits[0])
          if ($b -le 0xbf) {
            if ($x -le 0xdf) {
              $script:hbits += ('{0:X2}' -f $b)
              addto-list $script:hbits
              $script:hbits = @()
            } else {
              $script:hbits += ('{0:X2}' -f $b)
            }
          } else {
            addto-list $script:hbits
            $script:hbits = @()
            $script:hbits += ('{0:X2}' -f $b)
          }
        }
        2 {
          if ($b -le 0xbf) {
            $script:hbits += ('{0:X2}' -f $b)
            addto-list $script:hbits
            $script:hbits = @()
          } else {
            addto-list $script:hbits
            $script:hbits = @()
            $script:hbits += ('{0:X2}' -f $b)
          }
        }
      } # end switch
    } # end if highbit
  } # end foreach byte

  if ($script:list.Count -gt 0) {
    foreach ($char in $script:list) {
      "{0} = {1}`t{2}" -f $char, $charlist.$char.name, $_.FullName
    }
  }
} # end foreach file