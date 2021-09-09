#-------------------------------------------------------
function err {
  param([string]$errcode)
  [xml]$err = err.exe /:xml $errcode
  if ($err.ErrV1.err) {
    $err.ErrV1.err
  }
  else {
    $err.ErrV1 | Format-List
  }
}
#-------------------------------------------------------
function get-weeknum {
  param($date = (get-date))

  $Calendar = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
  $Calendar.GetWeekOfYear($date, [System.Globalization.CalendarWeekRule]::FirstFullWeek, [System.DayOfWeek]::Sunday)
}
#-------------------------------------------------------
function soma {
  & "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe" http://ice1.somafm.com/illstreet-128-aac
}
#-------------------------------------------------------
<# function color {
  param($hexColor = '', [Switch]$Table)

  if ($Table) {
    for ($bg = 0; $bg -lt 0x10; $bg++) {
      for ($fg = 0; $fg -lt 0x10; $fg++) {
        Write-Host -nonewline -background $bg -foreground $fg (' {0:X}{1:X} ' -f $bg, $fg)
      }
      Write-Host
    }
  }
  else {
    if ($hexColor -eq '') {
      # Output the current colors as a string.
      'Current Color = {0:X}{1:X} ' -f [Int] $HOST.UI.RawUI.BackgroundColor, [Int] $HOST.UI.RawUI.ForegroundColor
    }
    else {
      # Assume -color specifies a hex value and cast it to a [Byte].
      $newcolor = [Byte] ('0x{0}' -f $hexColor)
      # Split the color into background and foreground colors. The
      # [Math]::Truncate method returns a [Double], so cast it to an [Int].
      $bg = [Int] [Math]::Truncate($newcolor / 0x10)
      $fg = $newcolor -band 0xF

      # If the background and foreground colors match, throw an error;
      # otherwise, set the colors.
      if ($bg -eq $fg) {
        Write-Error 'The background and foreground colors must not match.'
      }
      else {
        $HOST.UI.RawUI.BackgroundColor = $bg
        $HOST.UI.RawUI.ForegroundColor = $fg
      }
    }
  }
}
 #>
#-------------------------------------------------------
<# function woot {
    param([switch]$notable = $false)
    $apikey = '029075373ff94c7da98799eeb3532034'
    $url = 'https://api.woot.com/2/events.json?eventType=Daily&key={0}' -f $apikey
    $daily = invoke-restmethod $url
    $url = 'https://api.woot.com/2/events.json?eventType=WootOff&key={0}' -f $apikey
    $daily += invoke-restmethod $url
    $results = $daily | sort site |
      Select-Object @{l = 'site'; e = { ($_.site -split '\.')[0] } },
        type,
        @{l = 'title'; e = { $_.offers.Title } },
        @{l = 'Price'; e = { $_.offers.items.SalePrice | Sort-Object | Select-Object -first 1 -Last 1 } },
        @{l = '%Sold'; e = { 100 - $_.offers.PercentageRemaining } },
        @{l = 'Condition'; e = { $_.offers.items.Attributes | Where-Object Key -eq 'Condition' | Select-Object -ExpandProperty Value -First 1 } }
    if ($notable) { $results } else { $results | ft -AutoSize }
} #>
#-------------------------------------------------------
