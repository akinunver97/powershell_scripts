$HaloPeeps = @('Master Chief', 'Cortana', 'Captain Keys', 'Flood','Another')
Write-Host "This is for for loop" -ForegroundColor Green
for($counter = 0; $counter -lt $HaloPeeps.Length;$counter++){
Write-Host $HaloPeeps[$counter]
}

Write-Host "-----------------------------------------------------" -ForegroundColor Red

Write-Host "This is for foreach loop" -ForegroundColor Green
foreach ($peep in $HaloPeeps) {
    <# $HaloPeeps is Halo$HaloPeeps current item #>
    Write-Host $peep
}