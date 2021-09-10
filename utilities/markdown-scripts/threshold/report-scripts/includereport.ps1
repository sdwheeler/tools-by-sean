[CmdletBinding()]
param($outfile=".\include-report.csv")

$pattern = "\[\!INCLUDE\[[^\]]*\]\((?<file>[^)]*)\)"

$links = @()
 
dir *.md -rec | ForEach-Object {
  $mdFile = $_

  ### Look for linked media
  $includelines = Select-String -Path $_ -Pattern $pattern
  foreach ($tag in $includelines.matches) {
    if ($tag.value -match $pattern) {
      $links += New-Object -type psobject -prop @{
        include = $Matches["file"];
        mdfile = $mdFile.FullName
      }
    }
  }
}
$links | Export-Csv -notype $outfile
