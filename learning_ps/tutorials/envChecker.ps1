Clear-Host 
Import-Module C:\Users\au\powershell_scripts\learning_ps\tutorials\MailModule.ps1

$ServerListFilePath = "C:\Users\au\powershell_scripts\learning_ps\tutorials\envCheckerList.csv"

$ServerList = Import-Csv -Path $ServerListFilePath -Delimiter ','

$Export = [System.Collections.ArrayList]@()
foreach ($Server in $ServerList) {
    $ServerName = $Server.ServerName
    $LastStatus = $Server.LastStatus
    $DownSince = $Server.DownSince
    $LastDownAlert = $Server.LastDownAlert

    $Connection = Test-Connection $ServerName -Count 1
    $DateTime = Get-Date

    if ($Connection.Status -eq "Success") {
        if ($LastStatus -ne "Success") {
            $Server.DownSince = $null
            $Server.LastDownAlert = $null
            Write-Output "$($ServerName) is now online"
        }
    }
    else {
        if ($LastStatus -eq "Success") {
            Write-Output "$($ServerName) is now offline"
            $Server.DownSince = $DateTime
            $Server.LastDownAlert = $DateTime

        }
        else {
            $DownFor = $((Get-Date -Date $DateTime) - (Get-Date -Date $DownSince)).TotalDays
            $SinceLastDownAlert = $((Get-Date -Date $DateTime) - (Get-Date -Date $LastDownAlert)).TotalDays
            if (($DownFor -ge 1) -and ($SinceLastDownAlert -ge 1)) {
                Write-Output "It has been $SinceLastDownAlert days since last alert"
                Write-Output "$ServerName is still offline for $DownFor days"
                $Server.LastDownAlert=$DateTime
            }
        }
    }

    $Server.LastStatus = $Connection.Status
    $Server.LastCheckTime = $DateTime
    [void]$Export.add($Server)
}
$Export | Export-Csv -Path $ServerListFilePath -Delimiter ',' -NoTypeInformation

