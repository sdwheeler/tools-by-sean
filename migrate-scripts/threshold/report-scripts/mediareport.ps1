[CmdletBinding()]
param($outfile=".\media-report.csv")

$pattern = "!\[\]\([\./\w]*/?(?<file>media/[^)]*)\)"

$links = @()
 
dir *.md -rec | ForEach-Object {
  $mdFile = $_

  ### Look for linked media
  $mediataglines = Select-String -Path $_ -Pattern $pattern
  foreach ($tag in $mediataglines.matches) {
    if ($tag.value -match $pattern) {
      $links += New-Object -type psobject -prop @{
        mediafile = $Matches["file"];
        mdfile = $mdFile.FullName
      }
    }
  }
}
$links | Export-Csv -notype $outfile
