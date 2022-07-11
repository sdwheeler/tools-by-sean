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
    } elseif ($raw) {
        $bytes
    } else {
        $bytes | Format-Hex
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
function Get-AsciiTable {
    [byte[]](0..255) | Format-Hex
}
Set-Alias ascii get-asciitable
#-------------------------------------------------------
#endregion
