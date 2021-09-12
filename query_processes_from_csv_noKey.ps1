# Just get your API key from your Carbon Black Profile and paste it in the $apitoken variable
# Gets all Carbon Black unresolved alerts that were generated in the past 24 hours
# Then dumps output to CSV file at the root of your H: drive
# with the filename of "alerts" and current date/time stamp in the name 
# then opens the file in Excel
#
$apitoken = '<insert CB API Key Here'
[string]$filepath = 'H:\process.csv';
[string]$directory = [System.IO.Path]::GetDirectoryName($filepath);
[string]$strippedfilename = [System.IO.Path]::GetFileNameWithoutExtension($filepath);
[string]$extension = [System.IO.Path]::GetExtension($filepath);
[string]$newfilename = $strippedfilename + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + $extension;
[string]$newfilepath = [System.IO.Path]::Combine($directory, $newfilename);

$csv = Import-Csv -Path 'H:\<insert Path to file containing process IDs and SubprocessIDs.csv'

foreach($item in $csv) {
$uri = ('https://<redacted>:8443/api/v2/process/'+$item.id+'/'+$item.segment_id+'/event')
Invoke-RestMethod -Uri $uri -Headers @{ "x-auth-token"= $apitoken } -Method 'GET' -ContentType 'application/json' | 
select -ExpandProperty process |
select hostname, interface_ip, start, cmdline, username, process_name, netconn_complete |
select -ExpandProperty netconn_complete |
select domain, remote_ip |
Export-Csv -Path $newfilepath -Encoding ascii -NoTypeInformation
}