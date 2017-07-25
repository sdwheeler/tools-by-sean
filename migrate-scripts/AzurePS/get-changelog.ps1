[CmdletBinding()]
Param(
  [string]$ModuleVersion = (get-date -f 'yyyy-MM-dd'),
  [string]$outputPath = 'C:\temp\psgallery\changelog.md'
)
$repoRoot = 'C:\git\AzurePS\azure-powershell\'
$azuremRMPath = 'src\ResourceManager'

$path = $repoRoot + $azuremRMPath

$changeLogs = dir $path -Include changelog.md -Recurse
$changeLogContent = @()
$changeLogContent +=  "## $ModuleVersion"

foreach ($log in $changeLogs) {
  $service = $log.directory.basename
  $content = Get-Content $log -Encoding UTF8
  $newContent = @()
  $found = $False

  foreach ($line in $content)
  {
    if (($line -ne $null) -and ($line.StartsWith("## Current Release")))
    {
      $newContent += "* $service"
      $found = $True
    }
    elseif ($line -like "##*")
    {
      # end of Current Release section
      $found = $False
    }
    elseif ($found)
    {
      $newContent += "    $line"
    }
  }
  if ($newContent.Count -gt 2) {
    $changeLogContent += $newContent
  }
}
$result = $changeLogContent -join "`r`n"
Set-Content -Value $result -path $outputPath -Encoding UTF8
