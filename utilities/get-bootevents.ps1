param($computer="$env:computername")
$ErrorActionPreference = "SilentlyContinue"
$query = "*[System[Provider[@Name='eventlog'] and (EventID=6008 or EventID=6005 or EventID=6006)]]"
$events = get-winevent -log system -computer $computer -FilterXPath $query
$query = "*[System[Provider[@Name='Application Popup'] and (EventID=26)]]"
$events += get-winevent -log system -computer $computer  -FilterXPath $query
$query = "*[System[Provider[@Name='USER32'] and (EventID=1076 or EventID=1073)]]"
$events += get-winevent -log system -computer $computer  -FilterXPath $query
$query = "*[System[Provider[@Name='Microsoft-Windows-Kernel-General'] and (EventID=12 or EventID=13)]]"
$events += get-winevent -log system -computer $computer  -FilterXPath $query
$query = "*[System[Provider[@Name='Microsoft-Windows-Kernel-Boot'] and (EventID=20)]]"
$events += get-winevent -log system -computer $computer  -FilterXPath $query
$query = "*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and (EventID=109)]]"
$events += get-winevent -log system -computer $computer  -FilterXPath $query
$query = "*[System[Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting'] and (EventID=1001)]]"
$events += get-winevent -log system -computer $computer  -FilterXPath $query

$events |
    sort TimeCreated -desc |
    select @{n='TimeCreated'; e={'{0:MM/dd/yyyy HH:mm:ss}' -f $_.TimeCreated}},Id,UserId,Message
