#requires -Version 2
[CmdLetBinding()]
param(
  [Parameter(Mandatory = $True)]
  [ValidateScript({Test-Path $_})]
  [string]$topicRoot,
  
  [Parameter(Mandatory = $True)]
  [string]$logfile,
  
  [ValidateScript({Test-Path $_})]
  [string]$repoRoot = 'C:\MyRepos\WindowsServerDocs-pr\WindowsServerDocs'
)

function New-Log
{
  param(
    [string]$logfile
  )
  New-Item -Path $logfile -Force
}
function Write-Log
{
  param(
    [string]$logfile,
    [string]$message,
    [switch]$Error
  )
  if ($Error) { 
    Write-Warning -Message $message
    } else {
    Write-Output -InputObject $message
  }
  Out-File -FilePath $logfile -InputObject $message -Append
}
function Get-RelativePath 
{
  param(
    [string]$fn1,
    [string]$fn2,
    [string]$root
  )
  
  # Create the regex pattern for the common root path.
 
  if ($root.EndsWith('\')) 
  {
    $root = $root.Substring(0,$root.Length-1)
  }
  $rootpattern = (Get-Item $root).FullName -replace '\\', '\\'
 
  # Get the file name and its path parts relative to the common root folder 
  $srcFile = Get-ChildItem $fn1
  $targetFile = Get-ChildItem $fn2

  $srcpath = New-Object -TypeName psobject -Property @{
    filename   = $srcFile.Name
    folderpath = ($srcFile.Directory -replace $rootpattern) -split '\\'
  }
  if ($srcFile.Directory.FullName -eq $root) 
  {
    $srcpath.folderpath = '' 
  }

  $dstpath = New-Object -TypeName psobject -Property @{
    filename   = $targetFile.Name
    folderpath = ($targetFile.Directory -replace $rootpattern) -split '\\'
  }
  if ($tartgetFile.Directory.Fullname -eq $root) 
  {
    $dstpath.folderpath = '' 
  }
  
  # Get the longest path and iterate over the parts to build the new relative path
  $relsrc = ''
  $reldst = ''
  $count = $srcpath.folderpath.Count
  if ($count -lt $dstpath.folderpath.Count) 
  {
    $count = $dstpath.folderpath.Count
  }

  for ($x = 0; $x -lt $count; $x++) 
  {
    if ($srcpath.folderpath[$x] -ne $dstpath.folderpath[$x]) 
    {
      if ($srcpath.folderpath[$x]) 
      {
        $relsrc += '../'
      }
      if ($dstpath.folderpath[$x]) 
      {
        $reldst += ('{0}/' -f $dstpath.folderpath[$x])
      }
    }
  }

  $newpath = '{0}{1}{2}' -f $relsrc, $reldst, $dstpath.filename
  Write-Output -InputObject $newpath
}
function Get-FileList 
{
  param([string]$filespec, [string]$root)
  $hash = @{}
 
  $EAPref = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'

  Get-ChildItem -Path $root -Include $filespec -Recurse | ForEach-Object -Process {
    if ($_.PSIsContainer -ne $True) 
    {
      $linkpath = $_.fullname
      $filename = $_.name
    
      try 
      {
        $hash.Add($filename,$linkpath)
      }
      catch 
      {
        Write-Log $logfile "ERROR: Duplicate file name: $linkpath" -Error
        Write-Log $logfile ('- Duplicate of {0}' -f $hash[$filename]) -Error
      }
    }
  }
  $ErrorActionPreference = $EAPref
  Write-Output -InputObject $hash   
}
function Get-Links 
{
  param(
    [string]$filepath
  )
  $linkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#]*)?(?<anchor>#.+)?\))'
  $mdtext = Select-String -Path $filepath -Pattern $linkpattern
  $mdtext | ForEach-Object -Process {
    if ($_ -match $linkpattern) 
    {
      Write-Output $Matches
    }
  }
}

New-Log $logfile




Write-Log $logfile "Creating list of all files in $repoRoot"
$filelist = Get-FileList -filespec '*' -root $repoRoot

Get-ChildItem -Path $topicRoot -Filter *.md -Recurse | ForEach-Object -Process {
  $fn1 = $_.FullName
  $fn2 = ''
  
  Write-Log $logfile '-------------------'
  Write-Log $logfile $fn1
  
  $links = Get-Links -filepath $fn1
  foreach ($link in $links) 
  {
    if (
      ($link['file'].startswith('http') -ne $true) -and 
      ($link['file'].startswith('assetId:') -ne $true) -and 
      ($link['file'] -ne '') 
    )
    {
      $linkedfile = ($link['file'] -split '/')[-1]
      $fn2 = $filelist[$linkedfile]
      if ($fn2) 
      { 
        $newpath = Get-RelativePath -fn1 $fn1 -fn2 $fn2 -root $repoRoot
        try 
        { 
          $newlink = $link['link'] -replace $link['file'], $newpath
          if ($link['file'] -ne $newpath) 
          {
            Write-Log $logfile "New Link: $newlink"
          }
        }
        catch 
        {
          Write-Log $logfile ("Invalid link: '{0}'" -f $link['file']) -Error
        }
      }
      else 
      {
        Write-Log $logfile "Missing file: $linkedfile" -Error
      }
    }
  }
}