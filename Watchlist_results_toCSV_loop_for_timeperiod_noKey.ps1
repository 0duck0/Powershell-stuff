$apitoken = 'insert CBR API Key Here'
$watchlist = 'add watchlist ID here, example:watchlist_3381'
$params = @{
Uri         = 'https://<redacted>:8443/api/v1/process?&rows=2000&q=watchlist_3381%3A*'
Headers     = @{ "x-auth-token"= $apitoken }
Method      = 'GET'
ContentType = 'application/json'
}
$TimeStart = Get-Date
$TimeEnd = $timeStart.addminutes(480)
Write-Host "Start Time: $TimeStart"
write-host "End Time:   $TimeEnd"
Do { 
 $TimeNow = Get-Date
 if ($TimeNow -ge $TimeEnd) {
  } else {
  Invoke-RestMethod @params |
#ConvertFrom-Json |
select -expand results |
Select start, hostname, process_name, username, sensor_id, cmdline |
Export-Csv -Path 'H:\<path to export file>\watchlist_3381.csv' -Encoding ascii -NoTypeInformation
import-csv "H:\<path to import file>\watchlist_3381.csv" | % {$_.start = ([datetime]($_.start)).ToString('yyyy.MM.dd HH:mm:ss'); $_} | Export-Csv 'H:\<path to export file>\watchlist_3381_date.csv' -NoTypeInformation
#Invoke-Item H:\<path to open file>\watchlist_3381_date.csv
 }
 Start-Sleep -Seconds 1800
}
Until ($TimeNow -ge $TimeEnd)
