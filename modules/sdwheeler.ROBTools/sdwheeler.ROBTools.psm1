$issueQuery = @'
{
    "query": "query { repository(name: \"PowerShell-Docs\", owner: \"MicrosoftDocs\") { issues(filterBy: {since: \"2015-10-01T10:00:00.000Z\"}, first: 100) { nodes { number state createdAt closedAt author { ... on User { login name email } ... on Bot { login } } labels(first: 50) { nodes { name } } title } pageInfo { hasNextPage endCursor } } } }"
}
'@
$prQuery = @'
{
  "query": "query { repository(owner: \"MicrosoftDocs\", name: \"PowerShell-Docs\") { pullRequests(states: MERGED, first: 100) { pageInfo { endCursor hasNextPage } nodes { number title changedFiles createdAt mergedAt baseRefName author { ... on User { login name email } ... on Bot { login } } } } } }"
}
'@
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

    $endpoint = 'https://api.github.com/graphql'
    $headers = @{
        Authorization = "bearer $env:GITHUB_TOKEN"
        Accept        = 'application/vnd.github.v4.json'
    }
    $body = $issueQuery -replace 'PowerShell-Docs', $repo -replace 'MicrosoftDocs', $owner
    Write-Verbose $body

    $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $body -Method POST
    $result.data.repository.issues.nodes |
        Select-Object number,
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

    while ($result.data.repository.issues.pageInfo.hasNextPage -eq 'true') {
        $after = 'first: 100, after: \"{0}\"' -f $result.data.repository.issues.pageInfo.endCursor
        $query = $body -replace 'first: 100', $after
        $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Body $query -Method POST
        $result.data.repository.issues.nodes |
            Select-Object number,
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
        Select-Object number,
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
            Select-Object number,
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
function Get-GHPullRequest {
    [CmdletBinding(DefaultParameterSetName='Converted')]
    param(
        [string[]]$BaseBranch,
        [validateset(
            'open',
            'closed',
            'merged',
            'all'
        )]
        [string[]]$State,
        [ValidateSet(
            'additions',
            'assignees',
            'author',
            'baseRefName',
            'body',
            'changedFiles',
            'closed',
            'closedAt',
            'comments',
            'commits',
            'createdAt',
            'deletions',
            'files',
            'headRefName',
            'headRepository',
            'headRepositoryOwner',
            'id',
            'isCrossRepository',
            'isDraft',
            'labels',
            'latestReviews',
            'maintainerCanModify',
            'mergeCommit',
            'mergeStateStatus',
            'mergeable',
            'mergedAt',
            'mergedBy',
            'milestone',
            'number',
            'potentialMergeCommit',
            'projectCards',
            'reactionGroups',
            'reviewDecision',
            'reviewRequests',
            'reviews',
            'state',
            'statusCheckRollup',
            'title',
            'updatedAt',
            'url'
        )]
        [string[]]$Field,
        [int]$Limit,
        [Parameter(ParameterSetName='Converted')]
        [object[]]$CalculatedProperty,
        [parameter(ParameterSetName='Raw')]
        [switch]$RawJson
    )
    begin {
        $BaseParams = @(
            'pr', 'list'
        )
    }
    process {
        if ([string]::IsNullOrEmpty($BaseBranch)) {
            'Not implemented yet, but could be.'
        }
        foreach($Base in $BaseBranch) {
            $QueryParams = $BaseParams
            $QueryParams += '--base'
            $QueryParams += $Base
            foreach ($s in $State) {
                $QueryParams += '--state'
                $QueryParams += $s
            }
            if ($null -ne $Limit) {
                $QueryParams += '--limit'
                $QueryParams += $Limit
            }
            foreach ($f in $Field) {
                $QueryParams += '--json'
                $QueryParams += $f
            }
            Write-Verbose "Calling: gh $($QueryParams -join ' ')"
            $Results = gh @QueryParams
            if ($RawJson) {
                $Results
            } elseif ($CalculatedProperty.Count -gt 0) {
                $Results | ConvertFrom-Json | Select-Object -Property $Property
            } else {
                $Results | ConvertFrom-Json
            }
        }
    }
    end {}
}
#-------------------------------------------------------
function Get-GHIssue {
    [CmdletBinding(DefaultParameterSetName='Converted')]
    param(
        [ValidateSet(
            'assignees',
            'author',
            'body',
            'closed',
            'closedAt',
            'comments',
            'createdAt',
            'id',
            'labels',
            'milestone',
            'number',
            'projectCards',
            'reactionGroups',
            'state',
            'title',
            'updatedAt',
            'url'
        )]
        [string[]]$Field,
        [int]$Limit = 10000,
        [string]$Repository,
        [ValidateSet(
            'open',
            'closed',
            'all'
        )]
        [string]$State = 'all',
        [Parameter(ParameterSetName='Converted')]
        [object[]]$CalculatedProperty,
        [parameter(ParameterSetName='Raw')]
        [switch]$RawJson
    )
    begin {
        $BaseParams = @(
            'issue', 'list'
        )
    }
    process {
        $QueryParams = $BaseParams
        if ($null -ne $Repository) {
            $QueryParams += '--repo'
            $QueryParams += $Repository
        }
        if ($null -ne $State) {
            $QueryParams += '--state'
            $QueryParams += $State
        }
        if ($null -ne $Limit) {
            $QueryParams += '--limit'
            $QueryParams += $Limit
        }
        foreach ($f in $Field) {
            $QueryParams += '--json'
            $QueryParams += $f
        }
        Write-Verbose "Calling: gh $($QueryParams -join ' ')"
        $Results = gh @QueryParams
        if ($RawJson) {
            $Results
        } elseif ($CalculatedProperty.Count -gt 0) {
            $Results | ConvertFrom-Json | Select-Object -Property $Property
        } else {
            $Results | ConvertFrom-Json
        }
    }
    end {}
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
