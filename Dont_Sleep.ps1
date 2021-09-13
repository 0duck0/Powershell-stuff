# mouse jiggle script
$TimeStart = Get-Date
$TimeEnd = $timeStart.addminutes(480)
Write-Host "Start Time: $TimeStart"
write-host "End Time:   $TimeEnd"
Do { 
 $TimeNow = Get-Date
 if ($TimeNow -ge $TimeEnd) {
  Write-host "It's time to finish."
 } else {
  [System.Windows.Forms.SendKeys]::SendWait({INS})
 }
 Start-Sleep -Seconds 10
}
Until ($TimeNow -ge $TimeEnd)
