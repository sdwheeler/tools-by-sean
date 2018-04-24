param(
  [Parameter(Mandatory=$true)]
  [uri]$issueurl,

  [ValidateSet('TechnicalContent\OMS-SC-PS', 'TechnicalContent\OMS-SC-PS\Azure Monitor', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\App Insights', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Automation', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Backup', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Log Analytics', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Monitoring', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Site Recovery', 'TechnicalContent\OMS-SC-PS\Operations Mgmt Suite\Solutions', 'TechnicalContent\OMS-SC-PS\PowerShell', 'TechnicalContent\OMS-SC-PS\PowerShell\AzurePS', 'TechnicalContent\OMS-SC-PS\PowerShell\Cmdlet Ref', 'TechnicalContent\OMS-SC-PS\PowerShell\Core', 'TechnicalContent\OMS-SC-PS\PowerShell\Developer', 'TechnicalContent\OMS-SC-PS\PowerShell\DSC', 'TechnicalContent\OMS-SC-PS\System Center', 'TechnicalContent\OMS-SC-PS\System Center\Config Mgr 2012', 'TechnicalContent\OMS-SC-PS\System Center\Config Mgr 2016', 'TechnicalContent\OMS-SC-PS\System Center\DPM', 'TechnicalContent\OMS-SC-PS\System Center\Operations Mgr', 'TechnicalContent\OMS-SC-PS\System Center\Orchestrator', 'TechnicalContent\OMS-SC-PS\System Center\Service Management Automation', 'TechnicalContent\OMS-SC-PS\System Center\Service Manager', 'TechnicalContent\OMS-SC-PS\System Center\VMM')]
  [string]$areapath='TechnicalContent\OMS-SC-PS\PowerShell',

  [ValidateSet('TechnicalContent\backlog', 'TechnicalContent\CY2017\11_2017', 'TechnicalContent\CY2017\12_2017', 'TechnicalContent\CY2018\01_2017', 'TechnicalContent\CY2018\02_2017', 'TechnicalContent\CY2018\03_2017', 'TechnicalContent\CY2018\04_2017', 'TechnicalContent\CY2018\05_2017', 'TechnicalContent\CY2018\06_2017', 'TechnicalContent\CY2018\07_2017', 'TechnicalContent\CY2018\08_2017', 'TechnicalContent\CY2018\09_2017', 'TechnicalContent\CY2018\10_2017', 'TechnicalContent\CY2018\11_2017', 'TechnicalContent\CY2018\12_2017')]
  [string]$iterationpath='TechnicalContent\backlog',

  [ValidateSet('Sean Wheeler','Bobby Reed','David Coulter','George Wallace')]
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
    $repo = ($issueurl.Segments[1..2]) -join ''
    $repo = $repo.Substring(0,($repo.length-1))
    $num = $issueurl.Segments[-1]
  }

  $apiurl = "https://api.github.com/repos/$repo/issues/$num"
  $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
  $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
  $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | select -ExpandProperty body
  $retval = New-Object -TypeName psobject -Property ([ordered]@{
      number = $issue.number
      url=$issue.html_url
      created_at=$issue.created_at
      assignee=$issue.assignee.login
      title='[GitHub #{0}] {1}' -f $issue.number,$issue.title
      labels=$issue.labels.name
      body=$issue.body
      comments=$comments -join "`n"
  })
  $retval
}


$issue = GetIssue -issueurl $issueurl
if ($issue) {
  $description = "Issue: {0}<BR>" -f $issue.url
  $description += "Created: {0}<BR>" -f $issue.created_at
  $description += "Labels: {0}<BR>" -f ($issue.labels -join ',')
  $description += "Description:<BR>{0}<BR>" -f ($issue.body -replace '\n','<BR>')
  $description += "Comments:<BR>{0}" -f ($issue.comments -replace '\n','<BR>')

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
