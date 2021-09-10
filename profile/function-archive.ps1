function Get-PrList {
    param(
        [string]$start,
        [string]$end
    )
    if ($start -eq '') {
        $startdate = Get-Date -Format 'yyyy-MM-dd'
    }
    else {
        $startdate = Get-Date $start -Format 'yyyy-MM-dd'
    }
    if ($end -eq '') {
        $current = Get-Date $start
        $enddate = '{0}-{1:d2}-{2:d2}' -f $current.Year, $current.Month, [datetime]::DaysInMonth($current.year, $current.month)
    }
    else {
        $enddate = Get-Date $end -Format 'yyyy-MM-dd'
    }
    $hdr = @{
        Accept        = 'application/vnd.github.v3+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }

    $query = "q=type:pr+is:merged+repo:MicrosoftDocs/PowerShell-Docs+merged:$startdate..$enddate"

    $users = Import-Csv "$robFolder\github-users.csv"
    function getOrg {
        param($name)
        ($users | Where-Object { $_.opened_by -eq $name }).org
    }

    Write-Host "Querying GitHub PRs for $startdate..$enddate ..."
    $prlist = Invoke-RestMethod "https://api.github.com/search/issues?$query" -Headers $hdr -follow
    $prlist.items | ForEach-Object {
        $pr = Invoke-RestMethod $_.pull_request.url -Headers $hdr
        $pr | Select-Object number, state,
        @{l = 'merged_at'; e = { $_.closed_at.ToString() } },
        changed_files,
        @{n = 'base'; e = { $_.base.ref } },
        @{n = 'org'; e = { getOrg $_.user.login } },
        @{n = 'user'; e = { $_.user.login } },
        title
    } | Export-Csv -Path ('.\prlist-{0}.csv' -f (Get-Date $start -Format 'MMMMyyyy'))
}

#-------------------------------------------------------
function Get-IssueHistory {
    param([datetime]$startmonth)

    if ($null -eq $startmonth) { $startmonth = Get-Date }
    $startdate = Get-Date ('{0}-{1:d2}-{2:d2}' -f $startmonth.Year, $startmonth.Month, 1)

    $hdr = @{
        Accept        = 'application/vnd.github.symmetra-preview+json'
        Authorization = "token ${Env:\GITHUB_TOKEN}"
    }
    $apiurl = 'https://api.github.com/repos/MicrosoftDocs/PowerShell-Docs/issues?state=all&since=' + $startdate

    $users = Import-Csv "$robFolder\github-users.csv"
    function getOrg {
        param($name)
        ($users | Where-Object { $_.opened_by -eq $name }).org
    }

    function getAge {
        param($record)
        $start = $record.created_at
        $end = $record.closed_at
        if ($null -eq $end) { $end = Get-Date }
        (New-TimeSpan -Start $start -End $end).totaldays
    }

    Write-Host "Querying GitHub issues since $startdate ..."
    $issuepages = Invoke-RestMethod $apiurl -head $hdr -follow
    $x = $issuepages | ForEach-Object {
        $_ | Where-Object pull_request -EQ $null
    }
    $x | Select-Object number, state,
    @{l = 'created_at'; e = { $_.created_at.ToString() } },
    @{l = 'closed_at'; e = { $_.closed_at.ToString() } },
    @{l = 'age'; e = { '{0:f2}' -f (getAge $_) } },
    @{l = 'user'; e = { $_.user.login } },
    @{l = 'org'; e = { getOrg $_.user.login } },
    title |
        Export-Csv -Path ('.\issues-{0}.csv' -f (Get-Date $startdate -Format 'MMMMyyyy'))
}

#-------------------------------------------------------
function Merge-IssueHistory {
    param($csvtomerge)
    $ht = @{ }
    Import-Csv "$robFolder\issues.csv" | ForEach-Object { $ht[$_.number] = $_ }
    Import-Csv $csvtomerge | ForEach-Object { $ht[$_.number] = $_ }
    $ht.values | Export-Csv issues-merged.csv
}
#-------------------------------------------------------
function Get-IssueAgeReport {
    param([datetime]$startmonth)

    if ($null -eq $startmonth) { $startmonth = Get-Date }
    $startdate = Get-Date ('{0}-{1:d2}-{2:d2}' -f $startmonth.Year, $startmonth.Month, 1)
    $csv = Import-Csv "$robFolder\issues.csv"

    $range = @(
        (New-Object -type psobject -prop @{
                range   = 'Less than 14 days'
                count   = 0
                sum     = 0.0
                average = 0.0
                min     = 99999.99
                max     = 0.00
            }),
        (New-Object -type psobject -prop @{
                range   = '14-30 days'
                count   = 0
                sum     = 0.0
                average = 0.0
                min     = 99999.99
                max     = 0.00
            }),
        (New-Object -type psobject -prop @{
                range   = 'More than 30 days'
                count   = 0
                sum     = 0.0
                average = 0.0
                min     = 99999.99
                max     = 0.00
            }),
        (New-Object -type psobject -prop @{
                range   = 'Total'
                count   = 0
                sum     = 0.0
                average = 0.0
                min     = 99999.99
                max     = 0.00
            })
    )

    $csv | Where-Object state -EQ 'closed' |
        Where-Object { (([datetime]$_.closed_at) -ge $startdate) -and
            (([datetime]$_.closed_at) -lt $startdate.AddMonths(1)) } | ForEach-Object {
            $range[3].count++
            $range[3].sum += [decimal]$_.age
            $range[3].average = $range[3].sum / $range[3].count
            if ([decimal]$_.age -lt $range[3].min) { $range[3].min = [decimal]$_.age }
            if ([decimal]$_.age -gt $range[3].max) { $range[3].max = [decimal]$_.age }

            switch ([decimal]$_.age) {
                { $_ -le 14 } {
                    $range[0].count++
                    $range[0].sum += $_
                    $range[0].average = $range[0].sum / $range[0].count
                    if ($_ -lt $range[0].min) { $range[0].min = $_ }
                    if ($_ -gt $range[0].max) { $range[0].max = $_ }
                }
                { $_ -gt 14 -and $_ -le 31 } {
                    $range[1].count++
                    $range[1].sum += $_
                    $range[1].average = $range[1].sum / $range[1].count
                    if ($_ -lt $range[1].min) { $range[1].min = $_ }
                    if ($_ -gt $range[1].max) { $range[1].max = $_ }
                }
                { $_ -ge 31 } {
                    $range[2].count++
                    $range[2].sum += $_
                    $range[2].average = $range[2].sum / $range[2].count
                    if ($_ -lt $range[2].min) { $range[2].min = $_ }
                    if ($_ -gt $range[2].max) { $range[2].max = $_ }
                }
            }
        }

    $range | ForEach-Object { if ($_.count -eq 0) { $_.min = 0 } }

    $range | Select-Object range, count,
    @{l = 'minimum'; e = { '{0,7:N2}' -f $_.min } },
    @{l = 'average'; e = { '{0,7:N2}' -f $_.average } },
    @{l = 'maximum'; e = { '{0,7:N2}' -f $_.max } } | Format-Table -a
}
#-------------------------------------------------------
function filter-name {
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string[]]$path
    )
    begin { $base = ($pwd -replace '\\', '/') + '/' }
    process {
        $path | ForEach-Object {
            ($_ -replace '\\', '/') -replace $base
        }
    }
}
#-------------------------------------------------------
function New-RandomString {
    param($length=16,$numspecials=6)
    [System.Web.Security.Membership]::GeneratePassword($length,$numspecials)
}
#-------------------------------------------------------
<#
function color {
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
<#
function woot {
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
}
#>
#-------------------------------------------------------
