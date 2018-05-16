#-------------------------------------------------------
#region Generic Web stuff
function get-links {
    param([string]$url)
    $x = Invoke-WebRequest $url
    $x.links.href | Sort-Object -Unique
}
#-------------------------------------------------------
function get-url {
    param(
      [string[]]$filelist,
      $headers,
      [switch]$force
    )
    $curdir = (get-location).path
    $wc = New-Object System.Net.WebClient
    if ($headers) {
      foreach ($key in $headers.keys) {
        Write-Output $key,$headers[$key]
        $wc.Headers.Add($key,$headers[$key])
      }
    }
    $wc.Headers.Add('User-agent','Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; Touch; rv:11.0) like Gecko')
    $filelist | ForEach-Object{
      $uri = [system.uri]$_
      $file = '{0}\{1}' -f $curdir,$uri.Segments[-1]
      if ((!(Test-Path $file)) -or $force){
        "Downloading $file"
        $url = '{0}://{1}{2}' -f $uri.Scheme,$uri.Host,($uri.AbsolutePath -replace ':','%3A')
        try {
          $wc.DownloadFile($url,$file)
        } catch {
          Write-Host "Error downloading $url"
          Write-Host $_.Exception.InnerException.message
        }
      } else {
        "Skipping $file"
      }
    }
}
Set-Alias -Name graburl -Value get-url
#endregion
#-------------------------------------------------------
