[CmdletBinding()]
param(
    [ValidateScript({ Test-Path $_ })]
    $reporoot = 'C:\Git\AzurePS\azure-docs-powershell\azureps-cmdlets-docs\ResourceManager\docs-conceptual'
)

function resolveURL {
    param($startURL)

    $result = [ordered]@{
        status = $null
        message = $null
        resolvedURL = $null
    }

    $ErrorActionPreference = 'SilentlyContinue'
    $Error.Clear()

    function getURL {
        param($url)

        try
        {
            $wr = [System.Net.WebRequest]::CreateHttp($url)
            $wr.Method= 'GET';
            $wr.Timeout = 25000;
            $wr.AllowAutoRedirect = $true
            $wr.UserAgent = 'Redirect crawler'
            $resp = [System.Net.HttpWebResponse]$wr.GetResponse()
        } catch [System.Net.WebException] {
            $resp = $Error[0].Exception.InnerException.Response
            if ($resp.StatusCode -eq 'NotFound') {
                $Error.Clear()
            } else {
                break
            }
        } catch {
            break
        }
        $resp
    }

    $response = getURL $startURL
    if ($Error.Count -ne 0) {
        $result.status = $Error[0].Exception.Hresult
        $result.message = $Error[0].Exception.message
        $result.resolvedURL = $startURL
        break
    } else {
        switch ($response.StatusCode) {
            'NotFound' {
                '404 ' +$startUrl
                $result.status = 404
                $result.message = 'NotFound'
                $result.resolvedURL = $startURL
                    }
            'OK' {
                $result.status = 200
                $result.message = 'Found'
                $result.resolvedURL = $response.ResponseUri
            }
        }
        $response.Close()
    }
    new-object -type psobject -prop $result
}


#$DebugPreference = 'Continue'
$starttime = Get-Date

Write-Host "Start - $starttime"

$linkpattern = '[^!]*(?<link>!?\[(?<label>[^\]]*)\]\((?<uri>(?<file>[^)#\?]*)?(?<query>\?[^)#]*)?(?<anchor>#[^)]+)?)\)).*'

$startLocation = $PWD.Path

$files = dir $reporoot -Include *.md -Recurse
foreach ($file in $files) {
  $filelocation = $file.Directory.FullName
  if ($filelocation -ne $PWD.Path) { Set-Location $filelocation }
  '='*80 + "`r`n" + $file + "`r`n" +  '='*80
  $lines = Select-String -Path $file.FullName -Pattern $linkpattern -AllMatches
  $foundLinks = $lines.Matches
  foreach ($link in $foundLinks) {
    if ($link.groups['link'].value.StartsWith('!')) {
        $file = $link.groups['file'].value
        $test = Test-Path "$reporoot\$file"
        if (!$test) { '{0,-8} : {1,-5} : {2}' -f 'Media',$test,$file }
    }
    elseif ($link.groups['file'].value.EndsWith('.md')) {
        $file = $link.groups['file'].value
        $test = Test-Path "$reporoot\$file"
        if (!$test) { '{0,-8} : {1,-5} : {2}' -f 'Article',$test,$file }
    }
    elseif ($link.groups['file'].value.StartsWith('http')) {
        $url = $link.groups['uri'].value
            $r = resolveURL $url
        if ($url.tolower().Contains('go.microsoft.com/fwlink') -or $url.tolower().Contains('aka.ms')) {
            $outmessage = '{0,-8} : {1,-5} : {2}' -f 'Redirect',' ',$url
        } else {
            $outmessage = '{0,-8} : {1,-5} : {2}' -f 'Web URL',' ',$url
        }
        if ($r.status -ne 200) {
            '{0} ==> Error {1} {2}' -f $outmessage,$r.status,$r.message
        } else {
            $resolvedURL = $r.resolvedURL -replace 'en-us/',''
            if ($resolvedURL -ne $url -and -not $outmessage.StartsWith('Redirect')) {
                '{0} ==> {1}' -f $outmessage,$r.resolvedURL
            } else {
                $outmessage
            }
        }
    }
    elseif ($link.groups['file'].value.StartsWith('/')) {
        $url = $link.groups['file'].value
        '{0,-8} : {1,-5} : {2}' -f 'Docs URL',' ',$url
    }
    elseif ($link.groups['file'].value  -eq '' -and $link.groups['anchor'].value  -ne '') {
        $url = $link.groups['anchor'].value
        '{0,-8} : {1,-5} : {2}' -f 'Anchor',' ',$url
    }
    else {
        '{0,-8} : {1,-5} : {2}' -f 'Unknown',' ',$link.groups['link'].value
    }
  }
}
Set-Location $startLocation
$endtime = Get-Date
Write-Host "End   - $endtime"
Write-Host ('{0:N2} seconds' -f ($endtime - $starttime).TotalSeconds)