<#

    .SYNOPSIS
    Migrates all of the linked media and fixes the linked references to match the new folder structure.

    .DESCRIPTION
    Run this script from the top most folder of your content hierarchy for your technology area. The
    script will scan the folder hierarchy and perform the following transformations on the content:
    - Scan for links to media files and copy the media files from the root media folder to media
    subfolder under the current location.
    - Fix all links to media files to point to the new media location.
    - Fix all links to MD files within the content to point to their new location in the folder 
    hierarchy.

    This assumes that the existing media folder is one-level above the current folder. This script 
    is intended to be run only once per technology-level folder.

    .PARAMETER logfile
    The full path to a file to log diagnostic output for review. The log file is used to identify runtime
    errors and invalid links.

    .OUTPUTS
    The script creates a log file. You must review the log file for errors and warning about missing content
    and invalid links.

    .EXAMPLE
    PS > cd "<repo-location>\networking"
    PS > <script-repository>\runonce\migrate-media.ps1


#>
[CmdletBinding()]
param([Parameter(Mandatory = $True)][string]$logfile)

function Create-Logfile
{
  param(
    [string]$logfile
  )
  New-Item -Path $logfile -Force
}
function Log-Output 
{
  param(
    [string]$logfile,
    [string]$message
  )
  Write-Output -InputObject $message
  Out-File -FilePath $logfile -InputObject $message -Append
}
function getMDfilelist 
{
  $pwd = ((Get-Location).Path.tostring() -replace '\\', '/') + '/'
  $hash = @{}
 
  Get-ChildItem -Path '*.md' -Recurse | ForEach-Object -Process {
    $filepath = $_.fullname -replace '\\', '/'
    $linkpath = $filepath -replace $pwd
    $filename = $_.name
    
    $EAPref = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try 
    {
      $hash.Add($filename,$linkpath)
    }
    catch 
    {
      Log-Output $logfile "ERROR: Duplicate file name: $linkpath"
      Log-Output $logfile ('- Duplicate of {0}' -f $hash[$filename])
    }
  }
  $ErrorActionPreference = $EAPref
  Write-Output -InputObject $hash   
}

function getDepth 
{
  param($fullpath)
  $pwd = ((Get-Location).Path.tostring() -replace '\\', '/') + '/'
  $fullpath = $fullpath -replace '\\', '/'
  $relativepath = $fullpath -replace $pwd
  $depth = ($relativepath -split '/').Count - 1
  Write-Output -InputObject $depth
}

Create-Logfile $logfile
Log-Output $logfile 'Creating list of MD files...'
$mdFilelist = getMDfilelist
$mediapattern = '!\[\]\((?<file>media/[^)]*)\)'
$articlepattern = '[^!]\[(?<label>(?<!\!INCLUDE\[)([^\[\]]*))\]\(((?<file>[^)#]*)?)((?<bkmk>#[^)]*)?)\)'

#region Fix media links
Log-Output $logfile 'Processing linked media files...'
Get-ChildItem -Path '*.md' -Recurse | ForEach-Object -Process {
  $mdFile = $_
  $fullname = $mdFile.fullname
  $article = $mdFile.basename
  $newMediaFolder = ".\media\$article"

  $medialinks = Select-String -Path $mdFile -Pattern $mediapattern
  if ($medialinks -ne $null) 
  {
    if ((Test-Path -Path $newMediaFolder) -ne $True) 
    {
      Log-Output $logfile "Creating $newMediaFolder"
      $null = mkdir $newMediaFolder
    }
    ### foreach link - update the link and copy the file to the new media folder 
    foreach ($medialink in $medialinks.matches) 
    {
      if ($medialink.value -match $mediapattern) 
      {
        $oldmediapath = $Matches['file']
        $pathPrefix = '../' * (getDepth($fullname))
        $newmediapath = $oldmediapath -replace 'media/', "media/$article/"
        $mediaSource = "../$oldmediapath"
        $mediaDestination = "./$newmediapath"
        Log-Output $logfile "- Copying $mediaSource to $mediaDestination"
        Copy-Item $mediaSource $mediaDestination

        Log-Output $logfile "- Rewriting media links $fullname"
        $mdText = Get-Content $fullname 
        $mdText = $mdText -replace $oldmediapath, ($pathPrefix+$newmediapath) 
        Set-Content -Path $fullname -Value $mdText
      }
    }
  }
}
#endregion

#region Fix article links
Log-Output $logfile 'Processing links to articles...'
Get-ChildItem -Path '*.md' -Recurse | ForEach-Object -Process {
  $mdFile = $_
  $fullname = $mdFile.fullname
  Log-Output $logfile "Processing article links for $fullname"

  $articlelinks = Select-String -Path $_ -Pattern $articlepattern
  if ($articlelinks -ne $null) 
  {
    ### foreach link - update the link to the new location
    foreach ($linkline in $articlelinks.matches) 
    {
      if ($linkline.value -match $articlepattern) 
      {
        $oldlinkpath = $Matches['file'].ToLower()
        if (($oldlinkpath -ne '') -and !$oldlinkpath.StartsWith('assetid') -and 
        !$oldlinkpath.StartsWith('http:') -and !$oldlinkpath.StartsWith('https:') ) 
        { 
          $articlefilename = ($oldlinkpath -split '/')[-1]
          if ($mdFilelist[$articlefilename] -eq $null) 
          {
            Log-Output $logfile "- Error Invalid link: $oldlinkpath does not exist"
          }
          else 
          {
            $pathPrefix = '../' * (getDepth($fullname))
            $newlinkpath = ($pathPrefix + $mdFilelist[$articlefilename])
            $mdText = Get-Content $fullname 
            $mdText = $mdText -replace $oldlinkpath, $newlinkpath
            Set-Content -Path $fullname -Value $mdText
          }
        }
      }
    }
  }
}
#endregion
