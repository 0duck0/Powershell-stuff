$Path = ".\"
$Text = "<add search query here>"
$PathArray = @()
$Results = ".\results.csv"

Get-ChildItem $Path -Filter "*.csv" -Recurse |
Where-Object { $_.Attributes -ne "Dictionary"} |
ForEach-Object {
If (Get-Content $_.FullName | Select-String -Pattern $Text) {
$PathArray += $_.FullName
}
}
Write-Host "Contents of ArrayPath:"
$PathArray | ForEach-Object {$_}
#$PathArray | % {$_} | Out-File $Results