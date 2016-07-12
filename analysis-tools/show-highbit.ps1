function addto-list {
  param([string[]]$bytes) 
  if ($hbits.Length -gt 0) {
    $char = $bytes -join " "
    if ($script:list -notcontains $char) {
      $script:list += $char
    }
  }
}

  $charlist = @{
    "AE"       = "reg symbol"
    "C2 A0"    = "no-break space"
    "C2 A9"    = "copyright"
    "C2 AE"    = "reg symbol"
    "C2 B0"    = "degree sign"
    "C3 82"    = "A+circumflex"
    "C3 97"    = "multiplication"
    "C3 9F"    = "sharp-S"
    "C3 A2"    = "a+circumflex"
    "C3 A5"    = "a+ring above"
    "C3 A7" = "c with cedilla"
    "C3 AA" = "e with circumflex"
    "C3 B1" = "n with tilde"
    "C3 BC"    = "u+diaeresis"
    "C4 8D" = "c with caron"
    "C5 93"    = "small ligature oe"
    "C5 A1" = "s with caron"
    "CE 95" = "epsilon"
    "CE A3"    = "sigma"
    "CE A4"    = "tau"
    "CE AC" = "alpha with tonos"
    "CE B1"    = "alpha"
    "CE B2"    = "beta"
    "CE B7" = "eta"
    "CE B9" = "iota"
    "CE BA" = "kappa"
    "CE BB" = "lamda"
    "CE BD" = "nu"
    "CF 83"    = "gamma"
    "CF 84"    = "delta"
    "D0 B8" = "cyrillic small letter i"
    "D0 B9" = "cyrillic small letter short i"
    "D0 BA" = "cyrillic small letter ka"
    "D1 80" = "cyrillic small letter er"
    "D1 81" = "cyrillic small letter es"
    "D1 83" = "cyrillic small letter u"
    "E2 80 8B" = "ZERO WIDTH SPACE"
    "E2 80 93" = "ndash"
    "E2 80 94" = "mdash"
    "E2 80 98" = "left single quote"
    "E2 80 99" = "right single quote"
    "E2 80 9C" = "left double quote"
    "E2 80 9D" = "right double quote"
    "E2 80 A6" = "ellipsis"
    "E2 82 AC" = "Euro sign"
    "E2 84 A2" = "TM sign"
    "E2 88 92" = "minus sign"
    "E2 89 A4" = "less-than or equal to"
    "E2 89 A5" = "greater-than or equal to"
    "E2 94 94" = "box up and right"
    "E2 97 BE" = "medium small square"
    "E2 99 A5" = "black heart suit"
    "E4 B8 A5" = "CJK Ideograph"
    "E4 B8 AD" = "CJK Ideograph"
    "E4 BD 8E" = "CJK Ideograph"
    "E4 BD 93" = "CJK Ideograph"
    "E4 BD 9C" = "CJK Ideograph"
    "E5 85 B3" = "CJK Ideograph"
    "E5 87 86" = "CJK Ideograph"
    "E5 88 A5" = "CJK Ideograph"
    "E5 88 AB" = "CJK Ideograph"
    "E5 8D 80" = "CJK Ideograph"
    "E5 B7 B2" = "CJK Ideograph"
    "E6 89 B9" = "CJK Ideograph"
    "E6 93 8D" = "CJK Ideograph"
    "E6 94 BF" = "CJK Ideograph"
    "E6 96 87" = "CJK Ideograph"
    "E6 97 A5" = "CJK Ideograph"
    "E6 9C 9F" = "CJK Ideograph"
    "E6 9C AC" = "CJK Ideograph"
    "E6 B8 AF" = "CJK Ideograph"
    "E7 89 B9" = "CJK Ideograph"
    "E7 AE 80" = "CJK Ideograph"
    "E7 BA A7" = "CJK Ideograph"
    "E8 A1 8C" = "CJK Ideograph"
    "E8 AA 9E" = "CJK Ideograph"
    "E9 87 8D" = "CJK Ideograph"
    "E9 97 AD" = "CJK Ideograph"
    "E9 97 AE" = "CJK Ideograph"
    "E9 A2 98" = "CJK Ideograph"
    "E9 A6 99" = "CJK Ideograph"
    "E9 AB 98" = "CJK Ideograph"
    "EA B5 AD" = "Hangul"
    "EC 96 B4" = "Hangul"
    "ED 95 9C" = "Hangul"
    "EF BB BF" = "BOM"
    "EF BC 88" = "fullwidth left paren"
    "EF BC 89" = "fullwidth right"
    "EF BF BD" = "replacement char <?>"
  }
  $script:hbits = @()
  $script:list = @()

dir *.md -rec | %{
  $mdtext = gc $_ -enc byte 
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

  if ($script:list.Count -gt 0) { $_.fullname }
  foreach ($char in $script:list) {
    "{0} = {1}" -f $char,$charlist[$char]
  }

} # end foreach file