function GetAlertsQuery {
    param(
        [string]$org,
        [string]$repo,
        [string]$after
    )

    $graphQL = @"
query {
  repository(owner: "$Org", name: "$Repo") {
    vulnerabilityAlerts(first: 50, after: $after) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        state
        createdAt
        securityAdvisory {
          summary
          severity
        }
      }
    }
  }
}
"@
    $graphQL
}
function Get-RepoSecurityAlerts {
    param(
        [string]$Org = 'sdwheeler',
        [string]$Repo = 'seanonit'
    )
    $query = GetAlertsQuery -org $Org -repo $Repo -after 'null'
    $irmSplat = @{
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Uri     = 'https://api.github.com/graphql'
        Body    = @{ query = $query } | ConvertTo-Json -Compress
        Method  = 'POST'
    }
    $hasNextPage = $true

    while ($hasNextPage) {
        $result = Invoke-RestMethod @irmSplat
        $result.data.repository.vulnerabilityAlerts.nodes |
            Select-Object state,
            @{n = 'Date'; e = { '{0:yyyy-MM-dd}' -f $_.createdAt } },
            @{n = 'Severity'; e = { $_.securityAdvisory.severity } },
            @{n = 'Summary'; e = { $_.securityAdvisory.summary } }

        $hasNextPage = $result.data.repository.vulnerabilityAlerts.pageInfo.hasNextPage
        $after = '"',$result.data.repository.vulnerabilityAlerts.pageInfo.endCursor,'"' -join ''
        $query = GetAlertsQuery -org 'PowerShell' -repo 'PowerShell' -after $after
        $irmSplat.Body = @{ query = $query} | ConvertTo-Json -Compress
    }
}
Get-RepoSecurityAlerts