#Load ps1 scripts in current dir
Get-ChildItem $psscriptroot\PSConfig-*.ps1 | ForEach-Object { . $_.FullName }
