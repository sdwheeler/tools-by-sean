function GetIssueQuery {
    param(
        [string]$org = 'MicrosoftDocs',
        [string]$repo = 'PowerShell-Docs',
        [string]$after = 'null'
    )
    $issueQuery = @"
query {
  repository(name: "$repo", owner: "$org") {
    issues(filterBy: {since: "2015-10-01T10:00:00.000Z"}, first: 100, after: $after) {
      nodes {
        number
        state
        createdAt
        closedAt
        author {
          ... on User {
            login
            name
            email
          }
          ... on Bot {
            login
          }
        }
        labels(first: 10) {
          nodes {
            name
          }
        }
        title
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
"@
    $issueQuery
}
#-------------------------------------------------------
function GetPRQuery {
    param(
        [string]$org = 'MicrosoftDocs',
        [string]$repo = 'PowerShell-Docs',
        [string]$after = 'null'
    )
    $prQuery = @"
query {
  repository(owner: "$org", name: "$repo") {
    pullRequests(states: MERGED, first: 100, after: $after) {
      pageInfo {
        endCursor
        hasNextPage
      }
      nodes {
        number
        title
        changedFiles
        createdAt
        mergedAt
        baseRefName
        author {
          ... on User {
            login
            name
            email
          }
          ... on Bot {
            login
          }
        }
      }
    }
  }
}
"@
    $prQuery
}
#-------------------------------------------------------
function getAge {
    param(
        $record,
        [datetime]$now
    )
    $start = $record.createdAt
    $end = $record.closedAt
    if ($null -eq $end) { $end = $now }
    (New-TimeSpan -Start $start -End $end).totaldays
}
function lookupUser {
    param(
        $users,
        $author
    )
    $user = [PSCustomObject]@{
        org = ''
        login = $author.login
        name = $author.name
        email = $author.email
    }
    if ($null -eq $author -or $author.login -eq '') {
        $user.org = 'Deleted'
        $user.login = 'ghost'
    } else {
        $user.org = $users |
            Where-Object login -eq $author.login |
            Select-Object -ExpandProperty org
    }
    $user
}
#-------------------------------------------------------
function Get-AllIssues {
    [CmdletBinding()]
    param(
        [string]$repo = 'PowerShell-Docs',
        [string]$owner = 'MicrosoftDocs'
    )

    $now = Get-Date
    $users = Import-Csv '.\github-users.csv'

    $query = GetIssueQuery -org $owner -repo $repo -after 'null'
    $invokeRestMethodSplat = @{
        Uri = 'https://api.github.com/graphql'
        Headers = @{
            Authorization = "bearer $env:GITHUB_TOKEN"
            Accept        = 'application/vnd.github.v4.json'
        }
        Body = @{query = $query} | ConvertTo-Json -Compress
        Method = 'POST'
    }
    $hasNextPage = $true

    while ($hasNextPage) {
        $result = Invoke-RestMethod @invokeRestMethodSplat
        $result.data.repository.issues.nodes |
            Select-Object @{n='repo'; e={$repo}},
            number,
            state,
            createdAt,
            closedAt,
            @{n = 'age'; e = { getAge $_ $now } },
            @{n = 'org'; e = { (lookupUser $users $_.author).org } },
            @{n = 'login'; e = { (lookupUser $users $_.author).login } },
            @{n = 'name'; e = { $_.author.name } },
            @{n = 'email'; e = { $_.author.email } },
            @{n = 'labels'; e = { $_.labels.nodes.name -join ', ' } },
            title
        $hasNextPage = $result.data.repository.issues.pageInfo.hasNextPage
        $after = '"{0}"' -f $result.data.repository.issues.pageInfo.endCursor
        $query = GetIssueQuery -org $owner -repo $repo -after $after
        $invokeRestMethodSplat.Body = @{query = $query} | ConvertTo-Json -Compress

    }
}
#-------------------------------------------------------
function Get-AllPRs {
    [CmdletBinding()]
    param(
        [string]$repo = 'PowerShell-Docs',
        [string]$owner = 'MicrosoftDocs'
    )

    $users = Import-Csv '.\github-users.csv'

    $endpoint = 'https://api.github.com/graphql'
    $headers = @{
        Authorization = "bearer $env:GITHUB_TOKEN"
        Accept        = 'application/vnd.github.v4.json'
    }
    $body = $prQuery -replace 'PowerShell-Docs', $repo -replace 'MicrosoftDocs', $owner
    Write-Verbose $body

    $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $body -Method POST
    $result.data.repository.pullRequests.nodes |
        Select-Object @{n='repo'; e={$repo}},
        number,
        createdAt,
        mergedAt,
        baseRefName,
        @{n = 'org'; e = { (lookupUser $users $_.author).org } },
        @{n = 'login'; e = { (lookupUser $users $_.author).login } },
        @{n = 'name'; e = { $_.author.name } },
        @{n = 'email'; e = { $_.author.email } },
        changedFiles,
        title

    while ($result.data.repository.pullRequests.pageInfo.hasNextPage -eq 'true') {
        $after = 'first: 100, after: \"{0}\"' -f $result.data.repository.pullRequests.pageInfo.endCursor
        $query = $body -replace 'first: 100', $after
        $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $query -Method POST
        $result.data.repository.pullRequests.nodes |
            Select-Object @{n='repo'; e={$repo}},
            number,
            createdAt,
            mergedAt,
            baseRefName,
            @{n = 'org'; e = { (lookupUser $users $_.author).org } },
            @{n = 'login'; e = { (lookupUser $users $_.author).login } },
            @{n = 'name'; e = { $_.author.name } },
            @{n = 'email'; e = { $_.author.email } },
            changedFiles,
            title
    }
}
#-------------------------------------------------------
function Invoke-KustoForGitHubId {
    [CmdletBinding(DefaultParameterSetName = 'ByGitHubId')]
    param (
      [Parameter(Mandatory, ParameterSetName = 'ByGitHubId')]
      [string[]]
      $githubId
    )
    $clusterUrl = 'https://1es.kusto.windows.net;Fed=True'
    $databaseName = 'GitHub'
    $kcsb = New-Object Kusto.Data.KustoConnectionStringBuilder ($clusterUrl, $databaseName)
    $queryProvider = [Kusto.Data.Net.Client.KustoClientFactory]::CreateCslQueryProvider($kcsb)
    $crp = New-Object Kusto.Data.Common.ClientRequestProperties
    $crp.ClientRequestId = 'MyPowershellScript.ExecuteQuery.' + [Guid]::NewGuid().ToString()
    $crp.SetOption([Kusto.Data.Common.ClientRequestProperties]::OptionServerTimeout, [TimeSpan]::FromSeconds(30))

    $querylist = "('$($githubId -join "','")')"

    #   Execute the query
    $query = @"
  //cluster('1es.kusto.windows.net').database('GitHub')
  githubemployeelink
  | where githubUserName in $querylist
  | project githubUserName, aadName, aadUpn, serviceAccountContact
"@

    Write-Verbose $query
    $reader = $queryProvider.ExecuteQuery($query, $crp)
    $dataTable = [Kusto.Cloud.Platform.Data.ExtendedDataReader]::ToDataSet($reader).Tables[0]
    $dataView = New-Object System.Data.DataView($dataTable)
    $dataView
}
#-------------------------------------------------------
