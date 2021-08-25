#-------------------------------------------------------
#region Data Conversion Functions
#-------------------------------------------------------
function ConvertFrom-Base64 {
    param(
      [string]$string,
      [switch]$raw,
      [switch]$text
    )
    $bytes  = [System.Convert]::FromBase64String($string);
    if ($text) {
      [System.Text.Encoding]::UTF8.GetString($bytes)
    } elseif ($raw) {
       $bytes
    } else {
      format-bytes $bytes
    }
}
#-------------------------------------------------------
function ConvertTo-Base64 {
    param (
      [parameter(Position=0, Mandatory=$true)]
      [byte[]]$bytes
    )
    [System.Convert]::ToBase64String($bytes);
}
#-------------------------------------------------------
function convertto-urlencoding($str) { return [system.net.webutility]::UrlEncode($str) }
Set-Alias -Name urlencode -Value convertto-urlencoding
#-------------------------------------------------------
function convertfrom-urlencoding($str) { return [system.net.webutility]::UrlDecode($str) }
Set-Alias -Name urldecode -Value convertfrom-urlencoding
#-------------------------------------------------------
function convertto-htmlencoding($str) { return [system.net.webutility]::HtmlEncode($str) }
Set-Alias -Name htmlencode -Value convertto-htmlencoding
#-------------------------------------------------------
function convertfrom-htmlencoding($str) { return [system.net.webutility]::HtmlDecode($str) }
Set-Alias -Name htmldecode -Value convertfrom-htmlencoding
#-------------------------------------------------------
function format-bytes {
    param([parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)] $bytes )
    function byteToChar([byte]$b) {
      if ( $b -lt 32 -or ( $b -gt 127 -and $b -lt 160)) { '.' }
      else { [char]$b }
    }
    $bytesPerLine = 16
    $buffer = new-object system.text.stringbuilder
    [void]$buffer.Append("          00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F    0123456789ABCDEF`n")
    [void]$buffer.Append("[Offset]: -----------------------------------------------    ----------------`n")
    for ( $offset=0; $offset -lt $bytes.Length; $offset += $bytesPerLine ) {
      [void]$buffer.AppendFormat('{0:X8}: ', $offset)
      $numBytes = [math]::min($bytesPerLine, $bytes.Length - $offset)
      for ( $i=0; $i -lt $numBytes; $i++ ) {
        [void]$buffer.AppendFormat('{0:X2} ', [byte]$bytes[$offset+$i])
      }
      [void]$buffer.Append(' ' * ((($bytesPerLine - $numBytes)*3)+3))
      for ( $i=0; $i -lt $numBytes; $i++ ) {
        [void]$buffer.Append( (byteToChar $bytes[$offset + $i]) )
      }
      [void]$buffer.Append("`n")
    }
    $buffer.ToString()
}
#-------------------------------------------------------
function get-asciitable { format-bytes  (0..255) }
set-alias ascii get-asciitable
#-------------------------------------------------------
function Get-TypeMember {
  [cmdletbinding()]
  param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [object]$InputObject
  )
  [type]$type = $InputObject.GetType()
  "`r`n    TypeName: {0}" -f $type.FullName
  $type.GetMembers() | Sort-Object membertype,name |
    Select-Object Name, MemberType, isStatic, @{ n='Definition'; e={$_} }
}
Set-Alias -Name gtm -Value Get-TypeMember
#endregion
#-------------------------------------------------------
