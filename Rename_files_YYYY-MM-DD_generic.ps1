# search for file name using "get-childitem"
#Dir *.csv | Rename-Item -NewName { $_.name -replace "__","_" }
#
Get-ChildItem <search csv files>.csv | ForEach-Object {
	$FileName =  $_.BaseName
	$words = $FileName.substring(37,8)
    #$words = $FileName.substring(37,6)
	$Date1 = [datetime]::ParseExact($words,'MM-dd-yy',$null)
    #$Date1 = [datetime]::ParseExact($words,'M-d-yy',$null)
    $Date2 = $Date1.ToString('MM-dd-yyyy')
    $Newname = $FileName.substring(0,36) + '_' + $Date2 + '.csv'
	Rename-Item $_.name -newName $Newname
}