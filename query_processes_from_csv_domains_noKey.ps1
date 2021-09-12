# Just get your API key from your Carbon Black Profile and paste it in the $apitoken variable
# Gets all Carbon Black unresolved alerts that were generated in the past 24 hours
# Then dumps output to CSV file at the root of your H: drive
# with the filename of "alerts" and current date/time stamp in the name 
# then opens the file in Excel
#
$apitoken = 'insert CB API Key'
[string]$filepath = 'H:\process.csv';
[string]$directory = [System.IO.Path]::GetDirectoryName($filepath);
[string]$strippedfilename = [System.IO.Path]::GetFileNameWithoutExtension($filepath);
[string]$extension = [System.IO.Path]::GetExtension($filepath);
[string]$newfilename = $strippedfilename + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + $extension;
[string]$newfilepath = [System.IO.Path]::Combine($directory, $newfilename);

$csv = Import-Csv -Path 'insert CSV file output from process_search_noAPIkey.ps1 script'

foreach($item in $csv) {
    $uri = ('https://<redacted>:8443/api/v2/process/'+$item.id+'/'+$item.segment_id+'/event')
    ForEach-Object {
        $requests = Invoke-RestMethod -Uri $uri -Headers @{ "x-auth-token"= $apitoken } -Method 'GET' -ContentType 'application/json'
        #$processes = $requests.process | select hostname, interface_ip, start, username, process_name, cmdline, netconn_complete
        $processes = $requests.process
        $netconns = $processes | select -ExpandProperty netconn_complete
        $domains =  , @()
        $domains += $netconns.domain
        $remote_ips = , @()
        $remote_ips += $netconns.remote_ip
        }
        
        $processes | ForEach-Object {
             foreach ($domain in $domains) {
                [PSCustomObject]@{
                        hostname                  = $_.hostname
                        interface_ip              = $_.interface_ip
                        start                     = $_.start
                        cmdline                   = $_.cmdline
                        username                  = $_.username
                        process_name              = $_.process_name
                        domain                    = $domain
                   }
             }
        }
   }
 
#.\query_process_from_csvdomains.ps1 | Export-Csv -Path $newfilepath -append -Encoding ascii -NoTypeInformation             
