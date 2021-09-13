Get-ChildItem *.csv | ForEach-Object {
	$CSV = Import-CSV -Path $_.FullName -Delimiter ","
	$FileName =  $_.Name
	$CSV | Select Impact,Classification,Message,Count | Export-CSV $_.FullName -NTI -Delimiter ","
}