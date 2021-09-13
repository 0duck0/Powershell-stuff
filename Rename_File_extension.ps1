# Get any file that ends with ".msg" in the current directory and change the file extension to ".txt"
Get-ChildItem *.msg | Rename-Item -NewName { $_.Name -replace '.msg','(2).txt' }