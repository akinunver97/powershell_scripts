$ServicesFilePath = "$HOME\powershell_scripts\tutorials\csv_files\Services.csv"
$LogPath = "$HOME\powershell_scripts\tutorials\Logs"
$LogFile = "Services.log"
$ServicesList = Import-Csv -Path $ServicesFilePath -Delimiter ','

#Check if directory exists, if not create one
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory | Out-Null
}

#Log Rotation
$MaxLogSize = 1MB
$FullLogPath = Join-Path $LogPath $LogFile

if (Test-Path $FullLogPath) {
    $LogSize = (Get-Item $FullLogPath).Length
    if ($LogSize -ge $MaxLogSize) {
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $ArchiveName = "Services_$Timestamp.log"
        Rename-Item -Path $FullLogPath -NewName $ArchiveName
    }
}

foreach ($Service in $ServicesList) {
    $CurrentServiceStatus = (Get-Service -Name $Service.Name).Status

    if ($Service.Status -ne $CurrentServiceStatus) {
        $Log = "Service : $($Service.Name) is currently $CurrentServiceStatus, should be $($Service.Status)"
        Write-Output $Log
        Out-File -FilePath "$LogPath\$LogFile" -Append -InputObject "$(Get-Date -Format "yyyy-MM-dd hh:mm:ss") $Log"
        

        $Log = "Setting $($Service.Name) to $($Service.Status)"
        Write-Output $Log
        Out-File -FilePath "$LogPath\$LogFile" -Append -InputObject "$(Get-Date -Format "yyyy-MM-dd hh:mm:ss") $Log"
        Set-Service -Name $Service.Name -Status $Service.Status

        $AfterServiceStatus = (Get-Service -Name $Service.Name).Status

        if ($Service.Status -eq $AfterServiceStatus) {
            $Log = "Action was successful Service $($Service.Name) is now $AfterServiceStatus"
            Write-Output $Log
            Out-File -FilePath "$LogPath\$LogFile" -Append -InputObject "$(Get-Date -Format "yyyy-MM-dd hh:mm:ss") $Log"
        }
        else {
            $Log = "Action failed Service $($Service.Name) is still $AfterServiceStatus, should be $($Service.Status)"
            Write-Output $Log
            Out-File -FilePath "$LogPath\$LogFile" -Append -InputObject "$(Get-Date -Format "yyyy-MM-dd hh:mm:ss") $Log"
        }

    }
    else {
        $Log = "Service : $($Service.Name) is already $($Service.Status)"
        Write-Output $Log
        Out-File -FilePath "$LogPath\$LogFile" -Append -InputObject "$(Get-Date -Format "yyyy-MM-dd hh:mm:ss") $Log"
        
    }
}