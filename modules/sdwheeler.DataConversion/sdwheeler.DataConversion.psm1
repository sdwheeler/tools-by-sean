#-------------------------------------------------------
#region Data Conversion Functions
#-------------------------------------------------------
function ConvertFrom-Base64 {
    [CmdletBinding(DefaultParameterSetName = 'AsHex')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'AsHex')]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'AsText')]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'AsRaw')]
        [string]$String,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'PipeAsHex')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'PipeAsText')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'PipeAsRaw')]
        [string]$InputObject,

        [Parameter(ParameterSetName = 'AsHex')]
        [Parameter(Mandatory, ParameterSetName = 'AsText')]
        [Parameter(Mandatory, ParameterSetName = 'PipeAsText')]
        [switch]$AsText,

        [Parameter(ParameterSetName = 'AsHex')]
        [Parameter(Mandatory, ParameterSetName = 'AsRaw')]
        [Parameter(Mandatory, ParameterSetName = 'PipeAsRaw')]
        [switch]$Raw
    )
    process {
        if ($PSCmdlet.ParameterSetName -match 'Pipe') {
            $bytes = [System.Convert]::FromBase64String($InputObject)
        } else {
            $bytes = [System.Convert]::FromBase64String($String)
        }

        if ($AsText) {
            [System.Text.Encoding]::UTF8.GetString($bytes)
        } elseif ($Raw) {
            $bytes
        } else {
            $bytes | Format-Hex
        }
    }
}
#-------------------------------------------------------
function ConvertTo-Base64 {
    param (
        [Parameter(Position = 0, Mandatory)]
        [byte[]]$Bytes
    )
    [System.Convert]::ToBase64String($Bytes)
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
#endregion
