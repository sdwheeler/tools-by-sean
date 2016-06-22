[CmdLetBinding()]
param(
  [Parameter(Mandatory=$true)][string]$topicRoot,
  [string]$repoRoot='C:\MyRepos\WindowsServerDocs-pr\WindowsServerDocs'
)

function get-RelativePath {
  param(
    [string]$fn1,
    [string]$fn2,
    [string]$root
  )
  
  if ($root.EndsWith("\") -ne $true) {
    $rootpattern = $root + '\'
  } else {
    $root = $root.Substring(0,$root.Length-1)
  }
  $rootpattern = $rootpattern -replace '\\','\\'
  
  $srcFile = Get-ChildItem $fn1
  $targetFile = Get-ChildItem $fn2

  $srcpath = new-object -type psobject -prop @{
    filename = $srcFile.Name
    folderpath = ($srcFile.Directory -replace $rootpattern) -split '\\'
  }
  if ($srcFile.Directory.FullName -eq $root) { $srcpath.folderpath = '' }

  $dstpath = new-object -type psobject -prop @{
    filename = $targetFile.Name
    folderpath = ($targetFile.Directory -replace $rootpattern) -split '\\'
  }
  if ($tartgetFile.Directory.Fullname -eq $root) { $dstpath.folderpath = '' }
  
  $relsrc = ''
  $reldst = ''
  $count = $srcpath.folderpath.Count
  if ($count -lt $dstpath.folderpath.Count) {$count = $dstpath.folderpath.Count}

  for ($x=0; $x -lt $count; $x++) {
    if ($srcpath.folderpath[$x] -ne $dstpath.folderpath[$x]) {
      if ($srcpath.folderpath[$x]) {$relsrc += '../'}
      if ($dstpath.folderpath[$x]) {$reldst += ('{0}/' -f $dstpath.folderpath[$x])}
    }
  }

  $newpath = '{0}{1}{2}' -f $relsrc, $reldst, $dstpath.filename
  Write-Output $newpath
}

function get-filelist 
{
  param([string]$filespec, [string]$root)
  $hash = @{}
 
  Get-ChildItem -Path $root -include $filespec -Recurse | ForEach-Object -Process {
    $linkpath = $_.fullname
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

function get-links {
  param(
    [string]$filepath
  )
  $linkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#]*)?(?<anchor>#.+)?\))'
  $mdtext = Select-String -Path $filepath -Pattern $linkpattern
  $mdtext | %{
    if ($_ -match $linkpattern) {
      $Matches
    }
  }
}

$filelist = get-filelist '*' $repoRoot

#Get-ChildItem -Path $topicRoot -Filter *.md -Exclude TOC.md -Recurse | %{
Get-ChildItem -Path $topicRoot -Filter *.md -Recurse | %{
  $fn1 = $_.FullName
  $fn2 = ''
  '-------------------'
  $fn1
  $links = get-links $fn1
  foreach ($link in $links) {
    if (
      ($link['file'].startswith('http') -ne $true) -and 
      ($link['file'].startswith('assetId:') -ne $true) -and 
      ($link['file'] -ne '') 
    ){
      $linkedfile = ($link['file'] -split '/')[-1]
      $fn2 = $filelist[$linkedfile]
      if ($fn2) { 
        $newpath = get-RelativePath -fn1 $fn1 -fn2 $fn2 -root $repoRoot
        try { 
          $newlink = $link['link'] -replace $link['file'],$newpath
          if ($link['file'] -ne $newpath) {
            "New Link: $newlink" 
          }
        }
        catch {
          Write-Warning ("Invalid link: '{0}'" -f $link['file'])
        }
      } else {
        Write-Warning "Missing file: $linkedfile"
      }
    }
  }
}