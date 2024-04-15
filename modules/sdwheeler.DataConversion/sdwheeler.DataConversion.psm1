#-------------------------------------------------------
#region Data Conversion Functions
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
#endregion
