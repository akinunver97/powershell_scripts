$Xmen = @('Wolverine', 'Cyclops', 'Storm', 'Professor X', 'Gambit', 'Dr. Jean Grey')
$counter = 0

Write-Host "This is for while loop" -ForegroundColor Red
while($counter -lt $Xmen.Length) {
    Write-Host $Xmen[$counter] -NoNewline
    Write-Host " "$Xmen[$counter].Length
    $counter++
}