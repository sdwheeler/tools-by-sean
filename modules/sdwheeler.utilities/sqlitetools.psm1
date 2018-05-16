#-------------------------------------------------------
#region General SQLite Functions
function open-SQLite {
  param($database)
  $sqlConnection = New-Object System.Data.SQLite.SQLiteConnection("Data Source = $database")
  $sqlConnection.Open()
  $sqlConnection
}
#-------------------------------------------------------
function close-SQLite {
  param($sqlConnection)
  $sqlConnection.Close()
}
#-------------------------------------------------------
function invoke-SQLiteQuery {
  param($sqlConnection,$query)
  if ($sqlConnection.State -ne [Data.ConnectionState]::Open) {
    'query failed: Connection to DB is not open.'
  } else {
    $datatSet = New-Object System.Data.DataSet
    $dataAdapter = New-Object System.Data.SQLite.SQLiteDataAdapter($query,$sqlConnection)
    $count = $dataAdapter.Fill($datatSet)
    return $datatSet.Tables[0].Rows
  }
}
#-------------------------------------------------------
function get-areacode {
  param(
    [Parameter(Mandatory = $True)][string]$npa,
    [string]$nxx
  )

  switch ($npa.Length) {
    3 {}
    6 {
      $nxx = $npa.substring(3,3)
      $npa = $npa.substring(0,3)
    }
    7 {
      $nxx = $npa.substring(4,3)
      $npa = $npa.substring(0,3)
    }
    default {
      "Invalid NPA - $npa"
      exit
    }

  }
  $database="$env:USERPROFILE\Downloads\AreaCode\AreaCode.db"
  $sqlConnection = open-SQLite $database

  $query = 'select {0} from AreaCode where {1}'

  if ($nxx) {
    $columns = 'State, RateCenter, NPA, NXX, Company, Use'
    $where = "NPA = $npa and NXX = $nxx"
    $query = $query -f $columns,$where
  } else {
    $columns = 'State, NPA, RateCenter'
    $where = "NPA = $npa"
    $query = ($query -f $columns,$where) + ' group by State, RateCenter'
  }
  invoke-SQLiteQuery $sqlConnection $query
  close-SQLite $sqlConnection
}
Set-Alias -Name areacode -Value get-areacode
#-------------------------------------------------------
function get-code {
  param(
    [Parameter(Mandatory=$true)]
    [string]$code,
    [Parameter(Mandatory=$true)]
    [ValidateSet('bug','http','ftp','smtp','rdp', ignorecase=$true)]
    [string]$type,
    [switch]$show
  )
  switch ($type) {
    'bug' {
      $table = 'bugcheck'
      if ($code.contains('0x')) {
        $intCode = [int]$code
        $code = '0x{0:X8}' -f $intCode
      } else {
        $intCode = [int]('0x{0}' -f $code)
        $code = '0x{0:X8}' -f $intCode
      }
    }
    'ftp' { $table = 'ftpcodes' }
    'http' { $table = 'HTTPCodes' }
    'rdp' { $table = 'rdpcodes' }
    'smtp' { $table = 'smtpcodes' }
  }
  $query = "select * from $table where Code = '$code';"

  $database="$env:USERPROFILE\Documents\WindowsPowerShell\codes.db"
  $sqlConnection = open-SQLite $database

  $result = invoke-SQLiteQuery $sqlConnection $query
  close-SQLite $sqlConnection

  if ($type -eq 'bug') {
    if ($show) {
      Start-Process $result.URL
    } else {
      $result | Select-Object Code,Name
    }
  } else {
    $result
  }
}
#endregion
#-------------------------------------------------------
