# Just get your API key from your Carbon Black Profile and paste it in the $apitoken variable
# Gets all Carbon Black unresolved alerts that were generated in the past 24 hours
# Then dumps output to CSV file at the root of your H: drive
# with the filename of "alerts" and current date/time stamp in the name 
# then opens the file in Excel
#
# Query CBR against workstations for network connections made to remote IP addresses (not RFC1918 or internal IP range)

$apitoken = '<insert CB API Key Here'
[string]$filepath = 'H:\process.csv';
[string]$directory = [System.IO.Path]::GetDirectoryName($filepath);
[string]$strippedfilename = [System.IO.Path]::GetFileNameWithoutExtension($filepath);
[string]$extension = [System.IO.Path]::GetExtension($filepath);
[string]$newfilename = $strippedfilename + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + $extension;
[string]$newfilepath = [System.IO.Path]::Combine($directory, $newfilename);

$params = @{
Uri         = 'https://<redacted>:8443/api/v1/process?&cb.min_last_update=2021-09-09T16%3A15%3A00Z&cb.max_last_update=2021-09-09T16%3A45%3A00Z&start=0&q=(ipport%3A80%20OR%20ipport%3A443)%20AND%20(group%3A%22VDI%22%20OR%20group%3A%22Workstations%22)%20AND%20(ipaddr%3A%5B1.0.0.0%20TO%209.255.255.255%5D%20OR%20ipaddr%3A%5B11.0.0.0%20TO%20100.63.255.255%5D%20OR%20ipaddr%3A%5B100.128.0.0%20TO%20126.255.255.255%5D%20OR%20ipaddr%3A%5B128.0.0.0%20TO%20169.253.255.255%5D%20OR%20ipaddr%3A%5B169.255.0.0%20TO%20172.15.255.255%5D%20OR%20ipaddr%3A%5B172.32.0.0%20TO%20191.255.255.255%5D%20OR%20ipaddr%3A%5B192.0.1.0%20TO%20192.0.1.255%5D%20OR%20ipaddr%3A%5B192.0.3.0%20TO%20192.88.98.255%5D%20OR%20ipaddr%3A%5B192.88.100.0%20TO%20192.167.255.255%5D%20OR%20ipaddr%3A%5B192.169.0.0%20TO%20198.17.255.255%5D%20OR%20ipaddr%3A%5B198.20.0.0%20TO%20198.51.99.255%5D%20OR%20ipaddr%3A%5B198.51.101.0%20TO%20203.0.112.255%5D%20OR%20ipaddr%3A%5B203.0.114.0%20TO%20223.255.255.255%5D)'
Headers     = @{ "x-auth-token"= $apitoken }
Method      = 'GET'
ContentType = 'application/json'
}
Invoke-RestMethod @params |
#ConvertFrom-Json |
select -expand results |
Select start, hostname, process_name, username, netconn_count, interface_ip, comms_ip, id, segment_id, cmdline, alliance_score_apirecordedfuturecomrecentlylinkedtointrusionmethod, alliance_link_apirecordedfuturecomrecentlylinkedtointrusionmethod, alliance_data_apirecordedfuturecomrecentlylinkedtointrusionmethod |
Export-Csv -Path $newfilepath -Encoding ascii -NoTypeInformation