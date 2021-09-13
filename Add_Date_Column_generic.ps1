# Generic script for adding a column to a CSV file to add the date on each now, where the filename contains the date
Get-ChildItem <search_string>.csv | ForEach-Object {
	$CSV = Import-CSV -Path $_.FullName -Delimiter ","
	$FileName =  $_.Name
	$Date = $FileName.substring(40,10) #starting character and next 10 characters contain the date in the filename
	$Date = [datetime]::ParseExact($Date,'MM-dd-yyyy',$null)
	$Date = $Date.ToString('MM/dd/yyyy')
	$CSV | Select-Object *,@{N='Date';E={$Date}} | Export-CSV $_.FullName -NTI -Delimiter ","
}