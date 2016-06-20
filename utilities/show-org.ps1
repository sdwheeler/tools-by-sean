param([string]$rootname,$depth=-1)

function findDirects {
  param($manager)
  $filter = "Manager -eq ""{0}""" -f $manager.DistinguishedName
  $reports = get-aduser -filter $filter -prop SamAccountName,DisplayName,Title,Manager,DistinguishedName,enabled
   
  $depth--
  foreach ($report in $reports) {
    if ($report.enabled) {
      $user = [ordered]@{ 
        Login   = $report.SamAccountName;
        Name    = $report.DisplayName;
        Title   = $report.Title;
        Manager = $manager.DisplayName;
      }
      new-object -type PSObject -prop $user
      if ($depth -ne 0) {findDirects $report }
    }
  }
}

$rootuser = get-aduser $rootname -prop SamAccountName,DisplayName,Title,Manager,DistinguishedName
$rootmgr = get-aduser $rootuser.Manager -prop SamAccountName,DisplayName,Title,Manager
$user = [ordered]@{ 
           Login = $rootuser.SamAccountName;
           Name = $rootuser.DisplayName;           
           Title = $rootuser.Title;
           Manager = $rootmgr.DisplayName;
         }
new-object -type PSObject -prop $user
findDirects $rootuser