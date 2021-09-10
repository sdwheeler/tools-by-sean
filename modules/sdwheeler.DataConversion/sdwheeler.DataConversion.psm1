#-------------------------------------------------------
#region Data Conversion Functions
#-------------------------------------------------------
function ConvertFrom-Base64 {
    param(
        [string]$string,
        [switch]$raw,
        [switch]$text
    )
    $bytes = [System.Convert]::FromBase64String($string);
    if ($text) {
        [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    elseif ($raw) {
        $bytes
    }
    else {
        format-bytes $bytes
    }
}
#-------------------------------------------------------
function ConvertTo-Base64 {
    param (
        [parameter(Position = 0, Mandatory = $true)]
        [byte[]]$bytes
    )
    [System.Convert]::ToBase64String($bytes);
}
#-------------------------------------------------------
function ConvertTo-UrlEncoding($str) { return [system.net.webutility]::UrlEncode($str) }
Set-Alias -Name urlencode -Value ConvertTo-UrlEncoding
#-------------------------------------------------------
function ConvertFrom-UrlEncoding($str) { return [system.net.webutility]::UrlDecode($str) }
Set-Alias -Name urldecode -Value ConvertFrom-UrlEncoding
#-------------------------------------------------------
function ConvertTo-HtmlEncoding($str) { return [system.net.webutility]::HtmlEncode($str) }
Set-Alias -Name htmlencode -Value ConvertTo-HtmlEncoding
#-------------------------------------------------------
function ConvertFrom-HtmlEncoding($str) { return [system.net.webutility]::HtmlDecode($str) }
Set-Alias -Name htmldecode -Value ConvertFrom-HtmlEncoding
#-------------------------------------------------------
function Format-Bytes {
    param([parameter(ValueFromPipeline = $true, Position = 0, Mandatory = $true)] $bytes )
    function byteToChar([byte]$b) {
        if ( $b -lt 32 -or ( $b -gt 127 -and $b -lt 160)) { '.' }
        else { [char]$b }
    }
    $bytesPerLine = 16
    $buffer = New-Object system.text.stringbuilder
    [void]$buffer.Append("          00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F    0123456789ABCDEF`n")
    [void]$buffer.Append("[Offset]: -----------------------------------------------    ----------------`n")
    for ( $offset = 0; $offset -lt $bytes.Length; $offset += $bytesPerLine ) {
        [void]$buffer.AppendFormat('{0:X8}: ', $offset)
        $numBytes = [math]::min($bytesPerLine, $bytes.Length - $offset)
        for ( $i = 0; $i -lt $numBytes; $i++ ) {
            [void]$buffer.AppendFormat('{0:X2} ', [byte]$bytes[$offset + $i])
        }
        [void]$buffer.Append(' ' * ((($bytesPerLine - $numBytes) * 3) + 3))
        for ( $i = 0; $i -lt $numBytes; $i++ ) {
            [void]$buffer.Append( (byteToChar $bytes[$offset + $i]) )
        }
        [void]$buffer.Append("`n")
    }
    $buffer.ToString()
}
#-------------------------------------------------------
function Get-AsciiTable { format-bytes (0..255) }
Set-Alias ascii get-asciitable
#-------------------------------------------------------
#endregion
