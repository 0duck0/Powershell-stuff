#### Combine CSV Files with Windows 10 PowerShell   ####
#### Navigate to folder where CSV files are located ####
Get-ChildItem -Filter *.csv | Select-Object -ExpandProperty FullName | Import-Csv | Export-Csv .\<name of export file.txt -NoTypeInformation -Append