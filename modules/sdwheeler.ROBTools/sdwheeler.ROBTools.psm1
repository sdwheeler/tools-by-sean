$robFolder = "$HOME\OneDrive - Microsoft\Documents\WIP\ROB-Data"
#-------------------------------------------------------
function Invoke-KustoForGitHubId {
  [CmdletBinding(DefaultParameterSetName = 'ByMonth')]
  param (
    [Parameter(Mandatory, ParameterSetName = 'ByMonth', Position = 0)]
    [datetime]
    $date,
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

  if ($PSCmdlet.ParameterSetName -eq 'ByMonth') {
    $month = Get-Date $date -Format 'MMMMyyyy'
    $newusers = Import-Csv ".\issues-$month.csv" |
      Where-Object { $_.org -eq '' } |
      Select-Object -exp login
    $newusers += Import-Csv ".\prlist-$month.csv" |
      Where-Object { $_.org -eq '' } |
      Select-Object -exp login
    $newusers += , 'sdwheeler'
    $newusers = $newusers | Sort-Object -Unique
    $querylist = "('$($newusers -join "','")')"
    Write-Verbose ($newusers -join ',')
  }
  else {
    $querylist = "('$($githubId -join "','")')"
  }

  #   Execute the query
  $query = @"
//cluster('1es.kusto.windows.net').database('GitHub')
githubemployeelink
| where githubUserName in $querylist
| project githubUserName, aadUpn, aadName, serviceAccountContact
"@

  Write-Verbose $query
  $reader = $queryProvider.ExecuteQuery($query, $crp)

  # Do something with the result datatable, for example: print it formatted as a table, sorted by the
  # "StartTime" column, in descending order
  $dataTable = [Kusto.Cloud.Platform.Data.ExtendedDataReader]::ToDataSet($reader).Tables[0]
  $dataView = New-Object System.Data.DataView($dataTable)
  $dataView
}
#-------------------------------------------------------
function Get-AllIssues {
    $body = @'
{
    "query": "query { repository(name: \"PowerShell-Docs\", owner: \"MicrosoftDocs\") { issues(filterBy: {since: \"2015-10-01T10:00:00.000Z\"}, first: 100) { nodes { number state createdAt closedAt author { ... on User { login name email } } labels(first: 50) { nodes { name } } title } pageInfo { hasNextPage endCursor } } } }"
}
'@
    $endpoint = 'https://api.github.com/graphql'
    $headers = @{
        Authorization = "bearer $env:GITHUB_TOKEN"
        Accept        = 'application/vnd.github.v4.json'
    }

    $users = Import-Csv '.\github-users.csv'
    function getOrg {
        param($name)
        ($users | Where-Object { $_.opened_by -eq $name }).org
    }

    function getAge {
        param($record)
        $start = $record.createdAt
        $end = $record.closedAt
        if ($null -eq $end) { $end = Get-Date }
        (New-TimeSpan -Start $start -End $end).totaldays
    }

    $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $body -Method POST
    $result.data.repository.issues.nodes |
        Select-Object number,
        state,
        createdAt,
        closedAt,
        @{n = 'age'; e = { getAge $_ } },
        @{n = 'org'; e = { if ($null -eq $_.author.login) { 'Deleted' } else { getOrg $_.author.login } } },
        @{n = 'login'; e = { if ($null -eq $_.author.login) { 'ghost' } else { $_.author.login } } },
        @{n = 'name'; e = { $_.author.name } },
        @{n = 'email'; e = { $_.author.email } },
        @{n = 'labels'; e = { $_.labels.nodes.name -join ', ' } },
        title

    while ($result.data.repository.issues.pageInfo.hasNextPage -eq 'true') {
        $after = 'first: 100, after: \"{0}\"' -f $result.data.repository.issues.pageInfo.endCursor
        $query = $body -replace 'first: 100', $after
        $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $query -Method POST
        $result.data.repository.issues.nodes |
            Select-Object number,
            state,
            createdAt,
            closedAt,
            @{n = 'age'; e = { getAge $_ } },
            @{n = 'org'; e = { if ($null -eq $_.author.login) { getOrg 'ghost' } else { getOrg $_.author.login } } },
            @{n = 'login'; e = { if ($null -eq $_.author.login) { 'ghost' } else { $_.author.login } } },
            @{n = 'name'; e = { $_.author.name } },
            @{n = 'email'; e = { $_.author.email } },
            @{n = 'labels'; e = { $_.labels.nodes.name -join ', ' } },
            title
    }
}
#-------------------------------------------------------
function Get-AllPRs {
    $body = @'
{
  "query": "query { repository(owner: \"MicrosoftDocs\", name: \"PowerShell-Docs\") { pullRequests(states: MERGED, first: 100) { pageInfo { endCursor hasNextPage } nodes { number title changedFiles createdAt mergedAt baseRefName author { ... on User { login name email } } } } } }"
}
'@
    $endpoint = 'https://api.github.com/graphql'
    $headers = @{
        Authorization = "bearer $env:GITHUB_TOKEN"
        Accept        = 'application/vnd.github.v4.json'
    }

    $users = Import-Csv '.\github-users.csv'
    function getOrg {
        param($name)
        ($users | Where-Object { $_.opened_by -eq $name }).org
    }

    $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $body -Method POST
    $result.data.repository.pullRequests.nodes |
        Select-Object number,
        createdAt,
        mergedAt,
        baseRefName,
        @{n = 'org'; e = { if ($null -eq $_.author.login) { 'Deleted' } else { getOrg $_.author.login } } },
        @{n = 'login'; e = { if ($null -eq $_.author.login) { 'ghost' } else { $_.author.login } } },
        @{n = 'name'; e = { $_.author.name } },
        @{n = 'email'; e = { $_.author.email } },
        changedFiles,
        title

    while ($result.data.repository.pullRequests.pageInfo.hasNextPage -eq 'true') {
        $after = 'first: 100, after: \"{0}\"' -f $result.data.repository.pullRequests.pageInfo.endCursor
        $query = $body -replace 'first: 100', $after
        $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $query -Method POST
        $result.data.repository.pullRequests.nodes |
            Select-Object number,
            createdAt,
            mergedAt,
            baseRefName,
            @{n = 'org'; e = { if ($null -eq $_.author.login) { 'Deleted' } else { getOrg $_.author.login } } },
            @{n = 'login'; e = { if ($null -eq $_.author.login) { 'ghost' } else { $_.author.login } } },
            @{n = 'name'; e = { $_.author.name } },
            @{n = 'email'; e = { $_.author.email } },
            changedFiles,
            title
    }
}
#-------------------------------------------------------
