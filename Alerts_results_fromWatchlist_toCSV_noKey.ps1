$apitoken = '<insert CBR API Key Here'
$watchlist = '<insert watchlist ID here, example:watchlist_1325>'
$params = @{
Uri         = 'https://<redacted>:8443/api/v2/alert?&rows=50000&q=hostname%3Andeuscsclvtst01'
Headers     = @{ "x-auth-token"= $apitoken }
Method      = 'GET'
ContentType = 'application/json'
}
Invoke-RestMethod @params |
#ConvertFrom-Json |
select -expand results |
Select start, hostname, process_name, username, sensor_id, cmdline |
Export-Csv -Path H:\carbon_black_alert_trend_data\$watchlist.csv -Encoding ascii -NoTypeInformation
Invoke-Item H:\carbon_black_alert_trend_data\watchlist_1325.csv