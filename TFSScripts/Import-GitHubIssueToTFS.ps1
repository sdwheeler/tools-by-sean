function Import-GitHubIssueToTFS {
  param(
    [Parameter(Mandatory=$true)]
    [uri]$issueurl,

    [ValidateSet(
      'TechnicalContent\Carmon Mills Org',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\Cmdlet Ref',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\Core',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\Developer',
      'TechnicalContent\Carmon Mills Org\Management\PowerShell\DSC'
      )]
    [string]$areapath='TechnicalContent\Carmon Mills Org\Management\PowerShell',

    [ValidateSet(
      'TechnicalContent\Future',
      'TechnicalContent\CY2019\06_2019',
      'TechnicalContent\CY2019\07_2019',
      'TechnicalContent\CY2019\08_2019',
      'TechnicalContent\CY2019\09_2019',
      'TechnicalContent\CY2019\10_2019',
      'TechnicalContent\CY2019\11_2019',
      'TechnicalContent\CY2019\12_2019',
      'TechnicalContent\CY2020\01_2020',
      'TechnicalContent\CY2020\02_2020',
      'TechnicalContent\CY2020\03_2020',
      'TechnicalContent\CY2020\04_2020',
      'TechnicalContent\CY2020\05_2020'
      )]
    [string]$iterationpath='TechnicalContent\Future',

    [ValidateSet('Sean Wheeler','Bobby Reed','David Coulter','George Wallace','David Smatlak')]
    [string]$assignee='Sean Wheeler'
  )

  if (!(Test-Path Env:\GITHUB_OAUTH_TOKEN)) {
    Write-Error "Error: missing Env:\GITHUB_OAUTH_TOKEN"
    exit
  }

  # load the required dll
  $dllpath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
  Add-Type -path "$dllpath\Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
  Add-Type -path "$dllpath\Microsoft.TeamFoundation.Client.dll"

  $vsourl = "https://mseng.visualstudio.com"

  function GetIssue {
    param(
      [Parameter(ParameterSetName='bynamenum',Mandatory=$true)]
      [string]$repo,
      [Parameter(ParameterSetName='bynamenum',Mandatory=$true)]
      [int]$num,

      [Parameter(ParameterSetName='byurl',Mandatory=$true)]
      [uri]$issueurl
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token ${Env:\GITHUB_OAUTH_TOKEN}"
    }
    if ($issueurl -ne '') {
      $repo = ($issueurl.Segments[1..2] -join '').trim('/')
      $issuename = $issueurl.Segments[1..4] -join ''
      $num = $issueurl.Segments[-1]
    }

    $apiurl = "https://api.github.com/repos/$repo/issues/$num"
    $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
    $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | select -ExpandProperty body
    $retval = New-Object -TypeName psobject -Property ([ordered]@{
        number = $issue.number
        name = $issuename
        url=$issue.html_url
        created_at=$issue.created_at
        assignee=$issue.assignee.login
        title='[GitHub #{0}] {1}' -f $issue.number,$issue.title
        labels=$issue.labels.name
        #body=$issue.body
        #comments=$comments -join "`n"
    })
    $retval
  }


  $issue = GetIssue -issueurl $issueurl
  if ($issue) {
    $description = "Issue: <a href='{0}'>{1}</a><BR>" -f $issue.url,$issue.name
    $description += "Created: {0}<BR>" -f $issue.created_at
    $description += "Labels: {0}<BR>" -f ($issue.labels -join ',')
    #$description += "Description:<BR>{0}<BR>" -f ($issue.body -replace '\n','<BR>')
    #$description += "Comments:<BR>{0}" -f ($issue.comments -replace '\n','<BR>')

    $vsts = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($vsourl)
    $WIStore=$vsts.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
    $project=$WIStore.Projects["TechnicalContent"]

    #Create Task
    $type=$project.WorkItemTypes["Task"]
    $item = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItem $type
    $item.Title = $issue.title
    $item.AreaPath = $areapath
    $item.IterationPath = $iterationpath
    $item.Description = $description
    $item.Fields['Assigned To'].Value = $assignee
    $item.save()
    $item | select Id,AreaPath,IterationPath,@{n='AssignedTo';e={$_.Fields['Assigned To'].Value}},Title,Description
  } else {
    Write-Error "Error: unable to retrieve issue."
  }
}
