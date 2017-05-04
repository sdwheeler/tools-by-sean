param($url)

function show-redirects {
    param($startURL = 'https://msdn.microsoft.com/library/ms788967(v=vs.110')

    $ErrorActionPreference = 'SilentlyContinue'
    $Error.Clear()

    function getURL {
        param($url)

        try
        {
            $wr = [System.Net.WebRequest]::CreateHttp($url)
            $wr.Method= 'GET';
            $wr.Timeout = 25000;
            $wr.AllowAutoRedirect = $false
            $wr.UserAgent = 'Redirect crawler'
            $resp = [System.Net.HttpWebResponse]$wr.GetResponse()
        } catch [System.Net.WebException] {
            $resp = $Error[0].Exception.InnerException.Response
            if ($resp.StatusCode -eq 'NotFound') {
                $Error.Clear()
            } else {
                $errorStatus = "Exception Message: " + $_.Exception.Message;
                Write-Host $errorStatus;
                Write-Host ("Inner Exception: " + $_.Exception.InnerException.Message)
                break
            }
        } catch {
            $errorStatus = "Exception Message: " + $_.Exception.Message;
            Write-Host $errorStatus;
            Write-Host ("Inner Exception: " + $_.Exception.InnerException.Message)
            break
        }
        $resp
    }

    $startURL

    while ($startURL -ne '') {
        $response = getURL $startURL
        if ($Error.Count -ne 0) {
            break
        }
        switch ($response.StatusCode) {
            'MovedPermanently' {
                '301 ' + $response.Headers['Location']
                if ($response.Headers['Location'].StartsWith('/')) {
                    $baseURL = [uri]$response.ResponseUri
                    $startURL = $baseURL.Scheme + '://'+ $baseURL.Host + $response.Headers['Location']
                } else {
                    $startURL = $response.Headers['Location']
                }
            }
            'Redirect' {
                '302 ' + $response.Headers['Location']
                if ($response.Headers['Location'].StartsWith('/')) {
                    $baseURL = [uri]$response.ResponseUri
                    $startURL = $baseURL.Scheme + '://'+ $baseURL.Host + $response.Headers['Location']
                } else {
                    $startURL = $response.Headers['Location']
                }
            }
            'NotFound' {
                '404 ' +$startUrl
                $startURL = ''
            }
            'OK' {
                '200 ' + $response.ResponseUri
                $startURL = ''
            }
        }
        $response.Close()
    }
}

show-redirects $url