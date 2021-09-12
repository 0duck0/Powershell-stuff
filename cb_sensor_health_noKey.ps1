$apitoken = '<add CBR API Key Here>'
$params = @{
Uri         = 'https://<redacted>:8443/api/v2/sensor'
Headers     = @{ "x-auth-token"= $apitoken }
Method      = 'GET'
ContentType = 'application/json'
}
Invoke-RestMethod @params |
#ConvertFrom-Json |
select -expand results |
Select id, computer_name, sensor_health_message, sensor_health_status |
Export-Csv -Path "H:\<insert path to save CSV file>\sensor_health $(get-date -f yyyy-MM-dd).csv" -Encoding ascii -NoTypeInformation
