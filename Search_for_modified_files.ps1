#The below script will search the users folders for modified files since a certain date.



# FileDateReview.ps1

#
# Making the Excel File
#

$excel = New-Object -ComObject excel.application $excel.visible = $False $workbook = $excel.Workbooks.Add() $diskSpacewksht= $workbook.Worksheets.Item(1)

$diskSpacewksht.Name = "Data Set"
$diskSpacewksht.Cells.Item(1,1) = 'Name'
$diskSpacewksht.Cells.Item(1,2) = 'ID'
$diskSpacewksht.Cells.Item(1,3) = 'MachineName'
$diskSpacewksht.Cells.Item(1,4) = 'UserName'
$diskSpacewksht.Cells.Item(1,5) = 'LastWriteTime'
$diskSpacewksht.Cells.Item(1,6) = 'Message'

$fetch = (Get-ChildItem -Path C:\Users -File -Recurse | ? {$_.LastWriteTime -gt "May 1, 2019 00:00:01 AM"}) | select -Property  * $Name = 2 $ID = 2 $MachineName = 2 $UName = 2 $lastWrite = 2 $Mess = 2

1..($fetch.Length - 1) | % {

    $message = $fetch[$_].Name
    $message += " was last modified at "
    $message += $fetch[1].LastWriteTime

    $diskSpacewksht.Cells.Item($Name,1) = $fetch[$_].FullName
    $diskSpacewksht.Cells.Item($ID,2) = $fetch[$_].Length
    $diskSpacewksht.Cells.Item($MachineName,3) = $env:COMPUTERNAME
    $diskSpacewksht.Cells.Item($UName,4) = (dir $fetch[$_].FullName).GetAccessControl().Owner
    $diskSpacewksht.Cells.Item($lastWrite,5) = $fetch[$_].LastWriteTime
    $diskSpacewksht.Cells.Item($Mess,6) = $message

    $Name++
    $ID++
    $MachineName++
    $UName++
    $lastWrite++
    $Mess++

}

$excel.DisplayAlerts = 'False' 
$workbook.SaveAs("D:\LOGS\file-alterations-for-super-timeline.xlsx")
$workbook.Close
$excel.DisplayAlerts = 'False'
$excel.Quit()
