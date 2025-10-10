$Xmen = @('Wolverine', 'Cyclops', 'Storm', 'Professor X', 'Gambit', 'Dr. Jean Grey')
$counter = 0

Write-Host "This is for do while loop" -ForegroundColor Red
Do {
    Write-Host $Xmen[$counter] "is a mutant!"
    $counter++
} While ($counter -lt $Xmen.Length)