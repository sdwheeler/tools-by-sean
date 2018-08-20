[Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite") | Out-Null

<# 
  enum assetTypes {
    "enclosure",
    "image"
  }
#>

##############################################
#region General SQLite Functions
##############################################
function openDatabase {
  param($database)
  $sqlConnection = New-Object System.Data.SQLite.SQLiteConnection("Data Source = $database")
  $sqlConnection.Open()
  $sqlConnection
}
function closeDatabase {
  param($sqlConnection)
  $sqlConnection.Close()
}
function querySQLite {
  param($sqlConnection,$query)
  if ($sqlConnection.State -ne [Data.ConnectionState]::Open) {
    "query failed: Connection to DB is not open."
  } else {
    $datatSet = New-Object System.Data.DataSet
    $dataAdapter = New-Object System.Data.SQLite.SQLiteDataAdapter($query,$sqlConnection)
    $count = $dataAdapter.Fill($datatSet)
    return $datatSet.Tables[0].Rows
  }
}
function insertRow {
  param($sqlConnection,
        [string]$table,
        [string[]]$columns,
        $datavalues)

  $sqlCommand = New-Object System.Data.SQLite.SQLiteCommand
  $sqlCommand.Connection = $sqlConnection
  
  $columnNames = $columns -join ","
  $valueNames = "@" + ($columns -join ",@")
  $sqlCommand.CommandText = "INSERT INTO $table ($columnNames) VALUES ($valueNames);" 
  $columns | ForEach-Object{
    $sqlCommand.Parameters.Add((New-Object Data.SQLite.SQLiteParameter($_))) | Out-Null
  }
  $x=0
  $datavalues | ForEach-Object{
    $sqlCommand.Parameters[$x].Value = $_
    $x++
  }
  $sqlCommand.ExecuteScalar()
}
function updateRow {
  param($sqlConnection,
        [string]$table,
        [string[]]$columns,
        [string[]]$whereColumns,
        $datavalues,
        $whereValues)

  $sqlCommand = New-Object System.Data.SQLite.SQLiteCommand
  $sqlCommand.Connection = $sqlConnection
  
  $setList = @()
  $columns | ForEach-Object {
     $setList += "$_ = @$_"
  }
  $columnList = $setList -join ","

  $setList = @()
  $whereColumns | ForEach-Object {
    $setList += "$_ = @$_"   
  }
  $whereList = $setList -join " AND "

  $allValues = $datavalues + $whereValues
  $sqlCommand.CommandText = "UPDATE $table SET $columnList WHERE $whereList;" 
  $columns | ForEach-Object{
    $sqlCommand.Parameters.Add((New-Object Data.SQLite.SQLiteParameter("@$_",$_.GetType().Name,$_.ToString().Length,$_))) | Out-Null
  }
  $whereColumns | ForEach-Object{
    $sqlCommand.Parameters.Add((New-Object Data.SQLite.SQLiteParameter("@$_",$_.GetType().Name,$_.ToString().Length,$_))) | Out-Null
  }
  $x=0
  $allValues | ForEach-Object{
    $sqlCommand.Parameters[$x].Value = $_
    $x++
  }
  $sqlCommand.ExecuteScalar()
}
#endregion
##############################################
#region Utility functions
##############################################
function filterName {
  param([string]$inputName)
  $badchars = "[/\?<>\\:\*\|]"
  $inputname -replace $badchars,""
}
#endregion
##############################################
#region File Maintenance
##############################################
function scheduleFileDownload {
  param($sqlconnection,$podcast,$files,$assetType)

  $jobId = $null
  foreach ($file in $files) {
    $filename = ([system.uri]$file.enclosure).Segments[-1]
    $filePath = "{0}{1}" -f $podcast.folder,$asName
    if ($jobId -eq $null) { 
      $job = Start-BitsTransfer -Source $file.enclosure -Destination $filePath -Asynchronous -DisplayName $assetType -Suspended
      $jobId = $job.JobId
    } else {
      Add-BitsFile -BitsJob $jobId -Source $file.enclosure -Destination $filePath 
    }
    $rowParams = @{
      sqlConnection = $sqlConnection;
      table         = "downloads";
      columns       = @("rowId","JobId","podcastId","episodeId","Filename","AssetType");
      datavalues    = @($null,$jobId.toString(),$podcast.podcastId,$files.episodeId,$filename,$assetType);
    }
    insertRow @rowParams
  }
}
function renameFolder {
  param($sqlConnection,$podcastId,$newName)
  $query = "select title,folder,podcastId from podcasts where podcastId = {0}" -f $podcastId
  $podcast = querySQLite $sqlConnection $query
  $newPath = "D:\Podcasts\{0}\" -f $newName
  if ($podcast.folder -ne $newPath) {
    if (Test-Path -Path $podcast.folder) {
      Rename-Item $podcast.folder "$newName"
    } else {
      if ((Test-Path -Path $newPath) -ne $true) {
        mkdir $newPath
      }
    }
    $updateParams = @{
      sqlConnection = $sqlConnection;
      table         = "podcasts";
      columns       = @("folder");
      whereColumns  = @("podcastId");
      datavalues    = @($newPath);
      whereValues   = @($podcastId);
    }
    updateRow @updateParams
  }
}
#endregion
##############################################
#region Feed Maintenance
##############################################
function updatePodcastStatus {
  param($sqlConnection)
  $podcasts = querySQLite $sqlConnection "select title,lastItemDate,podcastId from podcasts" 
  $updates = @()
  foreach ($podcast in $podcasts) {
    $query = "select max(pubDate) as pubDate from episodes where feedId = {0}" -f $podcast.podcastId
    $episode = querySQLite $sqlConnection $query 
    if ($podcast.lastItemDate -eq $null) { 
      if ($podcast.lastItemDate -lt $episode.pubDate) { 
        $updates += New-Object -type psobject -prop @{
          lastItemDate = $episode.pubDate;
          podcastId = $podcast.podcastId;
        }
      }
    } else {
      $updates += New-Object -type psobject -prop @{
        lastItemDate = $episode.pubDate;
        podcastId = $podcast.podcastId;
      }
    }
  }
  foreach ($update in $updates) {
    $updateParams = @{
      sqlConnection = $sqlConnection;
      table         = "podcasts";
      columns       = @("lastItemDate");
      whereColumns  = @("podcastId");
      datavalues    = @($update.lastItemDate);
      whereValues   = @($update.podcastId);
    }
    updateRow @updateParams
  }
}
function checkPodcastFolder {
  param($sqlConnection)
  $podcasts = querySQLite $sqlConnection "select title,folder,podcastId from podcasts"
  foreach ($podcast in $podcasts) {
    if ((Test-Path -path $podcast.folder) -ne $true) {
      mkdir $podcast.folder
    }
  }
}
function getPodcast {
  param([string]$uri)
  $f = [xml](Invoke-WebRequest -uri $uri)
  $feeddata = $f.rss.channel
  $props = [ordered]@{
    title         = $(if ($feeddata.title.GetType().Name -eq "XmlElement") {
                        $feeddata.title.innertext
                      } else {
                        $feeddata.title
                      }
                     );
	logoUrl       = $(if ($feeddata.image) {
                        $feeddata.image | Where-Object href | Select-Object -expand href
                      } else {
                        $null
                      }
                     );
	feedUrl       = $uri;
    siteUrl       = $(if ($feeddata.link.GetType().Name -eq "Object[]") {
                        $feeddata.link | Where-Object rel -eq $null
                      } else {
                        $feeddata.link
                      }
                     );
    pubDate       = $(if ($feeddata.pubDate) {
                       if ($feeddata.pubDate.contains(",")) {
                         ([datetime]($feeddata.pubDate -split ",")[-1]).ToString("yyyy-MM-dd hh:mm:ss")
                       } else {
                         ([datetime]$feeddata.pubDate).ToString("yyyy-MM-dd hh:mm:ss")
                       }
                      } else {
                        $null
                      }
                     );
	lastBuildDate = $(if ($feeddata.lastBuildDate) {
                        ([datetime]$feeddata.lastBuildDate).ToString("yyyy-MM-dd hh:mm:ss")
                      } else {
                        $null
                      }
                     );
    lastSyncDate  = Get-Date -Format "yyyy-MM-dd hh:mm:ss";
    lastItemDate  = $null;
    folder        = "D:\Podcasts\{0}\";
    logoFile      = "logo.jpg";
    items         = $feeddata.item;
    genre         = $null;
    subscribed    = $true;
    autodownload  = $true;
  }
  $props.folder = $props.folder -f (filterName $props.title)
  return New-Object -type psobject -prop $props
}
function addFeed {
  param($sqlConnection,$feedObj)

  if ($sqlConnection.State -ne [Data.ConnectionState]::Open) {
    "addFeed failed: Connection to DB is not open."
    Exit
  }
  
  $columnNames = "podcastId,title,feedUrl,siteUrl,logoUrl,pubDate,lastBuildDate,lastSyncDate,lastItemDate,folder,logoFile,genre,subscribed,autodownload"
  $rowParams = @{
    sqlConnection = $sqlConnection;
    table         = "podcasts";
    columns       = $columnNames -split ",";
    datavalues    = $null
  }
  
  $query = 'select podcastId from podcasts where feedUrl = "{0}"' -f $feedObj.feedUrl
  $sub = querySQLite $sqlConnection $query
  if ($sub.podcastId) {
      "Subscription exists for {0}" -f $feedObj.title
  } else {
    $rowParams.datavalues = @($null,
      $feedObj.title,
      $feedObj.feedUrl,
      $feedObj.siteUrl,
      $feedObj.logoUrl,
      $feedObj.pubDate,
      $feedObj.lastBuildDate,
      $feedObj.lastSyncDate,
      $feedObj.lastItemDate,
      $feedObj.folder,
      $feedObj.logoFile,
      $feedObj.genre,
      $feedObj.subscribed,
      $feedObj.autodownload)
    insertRow @rowParams
    "Added Podcast - {0}" -f $feedObj.title
  }
}
function setSubscription {
  param($sqlConnection, $feedId, [int32]$state)
    $updateParams = @{
      sqlConnection = $sqlConnection;
      table         = "podcasts";
      columns       = @("subscribed");
      whereColumns  = @("podcastId");
      datavalues    = @($state);
      whereValues   = @($feedId);
    }
    updateRow @updateParams  
}
#endregion
##############################################
#region Episode Maintenance
##############################################
function getEpisodes {
  param([string]$feedUrl,[int]$feedId)
  $f = getPodcast $feedUrl
  foreach ($item in $f.items) {
    $props = [ordered]@{
      title        = $(if ($item.title) {
                         if ($item.title.GetType().Name -eq "XmlElement") {
                           $item.title.innertext
                         } else {
                           $item.title
                         } 
                       } else {
                         $null
                       }
                      );
      link         = $(if ($item.link) {
                         if ($item.link.GetType().Name -eq "XmlElement") {
                           $item.link.innertext
                         } else {
                           $item.link
                         }
                       } else {
                         $null
                       }
                      );
  	  logoUrl      = $(if ($item.image) {
                         $item.image | Where-Object href | Select-Object -expand href
                       } else {
                         $null
                       }
                      );
      pubDate      = $(if ($item.pubDate) {
                         if ($item.pubDate.contains(",")) {
                           ([datetime]($item.pubDate -split ",")[-1]).ToString("yyyy-MM-dd hh:mm:ss")
                         } else {
                           ([datetime]$item.pubDate).ToString("yyyy-MM-dd hh:mm:ss")
                         }
                       } else {
                         $null
                       }
                      );
      lastSyncDate = get-date -Format "yyyy-MM-dd hh:mm:ss";
      guid         = $(if ($item.guid) {
                         if ($item.guid.GetType().Name -eq "XmlElement") {
                           $item.guid.innertext
                         } else {
                           $item.guid
                         }
                       } else {
                         $null
                       }
                      );
      enclosure    = $(if ($item.enclosure) {$item.enclosure.url} else {$null});
      filesize     = $(if ($item.enclosure) {$item.enclosure.length} else {$null});
      duration     = $(if ($item.enclosure) {$item.duration} else {$null});
      download     = $true;
      feedId       = $feedId;
    }
    New-Object -type psobject -Property $props
  }
}
function addEpisode {
  param($sqlConnection,$episodeObj)
  if ($sqlConnection.State -ne [Data.ConnectionState]::Open) {
    "addEpisode failed: Connection to DB is not open."
    Exit
  }
  
  $columnNames = "episodeId,title,link,pubDate,lastSyncDate,guid,enclosure,filesize,duration,download,feedId"
  $rowParams = @{
    sqlConnection = $sqlConnection;
    table         = "episodes";
    columns       = $columnNames -split ",";
    datavalues    = $null
  }

  
  $query = 'select episodeId from episodes where feedId = "{0}" and guid = "{1}"' -f $episodeObj.feedId,$episodeObj.guid
  $ep = querySQLite $sqlConnection $query 
  if ($ep.episodeId) {
      "Episode exists - {0}" -f $episodeObj.title
  } else {
    $rowParams.datavalues = @($null,
      $episodeObj.title,
	  $episodeObj.link,
	  $episodeObj.pubDate,
	  $episodeObj.lastSyncDate,
	  $episodeObj.guid,
	  $episodeObj.enclosure,
	  $episodeObj.filesize,
	  $episodeObj.duration,
	  $episodeObj.download,
	  $episodeObj.feedId )
    insertRow @rowParams
    "Added Episode - {0}" -f $episodeObj.title
  }
}
function downloadEpisodes {
  param($sqlConnection,$feedId)
  $files = querySQLite $sqlConnection "select enclosure,episodeId from episodes where feedId=$feedId and enclosure is not NULL and filename is NULL and download=1"
  $podcast = querySQLite $sqlConnection "select folder from podcasts where podcastId=$feedId" 
  $dlParams = @{
    sqlConnection = $sqlConnection;
    podcast       = $podcast;
    files         = $files;
    assetType     = "enclosure";
  }
  scheduleFileDownload @dlParams
}
function downloadFeedImage {
  param($sqlConnection,$feedId)
  $files = querySQLite $sqlConnection "select logoUrl as enclosure,avg(logoUrl) as episodeId from podcasts where podcastId=$feedId" 
  $podcast = querySQLite $sqlConnection "select * from podcasts where podcastId=$feedId" 
  $dlParams = @{
    sqlConnection = $sqlConnection;
    podcast       = $podcast;
    files         = $files
    assetType     = "image";
  }
  scheduleFileDownload @dlParams
}
#endregion
##############################################
#region Main
##############################################
function Main {
$feeds = @(
"http://cocktailmariachii51095.podomatic.com/rss2.xml",
"http://www.weirdsville.com/pod/rss.xml",
"http://cudraclover.podomatic.com/rss2.xml",
"http://feeds.feedburner.com/mashup-podcast",
"http://modrob.podomatic.com/rss2.xml",
"http://www.exotictikiisland.com/feed/podcast/podcast.xml",
"http://www.poderato.com/loungeking/_feed/1",
"http://feeds.soundcloud.com/users/soundcloud:users:6254994/sounds.rss",
"http://feeds.feedburner.com/libsyn/uBVC",
"http://www.digitiki.com/podcast/The_Quiet_Village.xml",
"http://kansaspublicradio.org/widgets/podcasts/retro-cocktail-hour.php",
"http://cocktailnation.podbean.com/feed/"
)
$database="C:\Users\swheeler\Desktop\SQLiteRSS\feeds.db"
$sqlConnection = openDatabase $database


$feeds | ForEach-Object{
  $f = getPodcast $_ 
  addFeed $sqlConnection $f 
}

querySQLite $sqlConnection "select podcastId,feedUrl from podcasts" | ForEach-Object{
  getEpisodes $_.feedUrl $_.podcastId | ForEach-Object{
    addEpisode $sqlConnection $_ 
  }
}

renameFolder $sqlConnection 2 "Weirdsville"
renameFolder $sqlConnection 7 "El Munecon The Loung King"
1..8 |%{ setSubscription $sqlConnection $_ 0 }

checkPodcastFolder $sqlConnection
updatePodcastStatus $sqlConnection


querySQLite $sqlConnection "select podcastId from podcasts where subscribed=1" | ForEach-Object{
  downloadEpisodes $sqlConnection $_.podcastId
}

closeDatabase $sqlConnection
}
#endregion
##############################################
