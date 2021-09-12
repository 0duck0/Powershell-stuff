# Just get your API key from your Carbon Black Profile and paste it in the $apitoken variable
# Gets all Carbon Black unresolved alerts that were generated in the past 24 hours
# Then dumps output to CSV file at the root of your H: drive
# with the filename of "alerts" and current date/time stamp in the name 
# then opens the file in Excel
#
$apitoken = 'insert CBR API Key Here'
[string]$filepath = 'H:\alerts.csv';
[string]$directory = [System.IO.Path]::GetDirectoryName($filepath);
[string]$strippedfilename = [System.IO.Path]::GetFileNameWithoutExtension($filepath);
[string]$extension = [System.IO.Path]::GetExtension($filepath);
[string]$newfilename = $strippedfilename + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + $extension;
[string]$newfilepath = [System.IO.Path]::Combine($directory, $newfilename);

$params = @{
Uri         = 'https://<redacted>:8443/api/v2/alert?q=hostname%3Andeuscsclvtst01&rows=50000&created_time%3A-11030m&status%3AUnresolved'
Headers     = @{ "x-auth-token"= $apitoken }
Method      = 'GET'
ContentType = 'application/json'
}
Invoke-RestMethod @params |
#ConvertFrom-Json |
select -expand results |
Select created_time, hostname, process_name, username, report_score, watchlist_id, watchlist_name, interface_ip, md5, sensor_id, process_path |
Export-Csv -Path $newfilepath -Encoding ascii -NoTypeInformation
Invoke-Item $newfilepath