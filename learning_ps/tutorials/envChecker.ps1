Clear-Host 
Import-Module C:\Users\au\powershell_scripts\learning_ps\tutorials\MailModule.ps1
#Proper
$EmailFrom = "akin.unver97@gmail.com"
$EmailTo = "akin.unver97@gmail.com"


$SMTPServer = "smtp.gmail.com"
$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
$SMTPClient.EnableSsl = $true
#Use your mail account without @gmail.com for "account" section
#Use your 16 number gmail app password for "password" section. To enable that check out gmail documentation
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential("account", "password");



$ServerListFilePath = "C:\Users\au\powershell_scripts\learning_ps\tutorials\envCheckerList.csv"

$ServerList = Import-Csv -Path $ServerListFilePath -Delimiter ','

$Export = [System.Collections.ArrayList]@()
foreach ($Server in $ServerList) {
    $ServerName = $Server.ServerName
    $LastStatus = $Server.LastStatus
    $DownSince = $Server.DownSince
    $LastDownAlert = $Server.LastDownAlert
    $Alert = $false

    $Connection = Test-Connection $ServerName -Count 1
    $DateTime = Get-Date

    if ($Connection.Status -eq "Success") {
        if ($LastStatus -ne "Success") {
            $Server.DownSince = $null
            $Server.LastDownAlert = $null
            Write-Output "$($ServerName) is now online"
            $Alert = $true
            $Subject = "$ServerName is now online!"
            $Body = "$ServerName is now online! at $DateTime"
        }
    }
    else {
        if ($LastStatus -eq "Success") {
            Write-Output "$($ServerName) is now offline"
            $Server.DownSince = $DateTime
            $Server.LastDownAlert = $DateTime
            $Alert = $true
            $Subject = "$ServerName is now offline!"
            $Body = "$ServerName is now offline at $DateTime"
        }
        else {
            $DownFor = $((Get-Date -Date $DateTime) - (Get-Date -Date $DownSince)).TotalDays
            $SinceLastDownAlert = $((Get-Date -Date $DateTime) - (Get-Date -Date $LastDownAlert)).TotalDays
            if (($DownFor -ge 1) -and ($SinceLastDownAlert -ge 1)) {
                Write-Output "It has been $SinceLastDownAlert days since last alert"
                Write-Output "$ServerName is still offline for $DownFor days"
                $Server.LastDownAlert = $DateTime
                $Alert = $true
                $Subject = "$ServerName is still offline for $DownFor days!"
                $Body = "$ServerName has been offline for $DownFor days!"
                $Body += " $ServerName is now offline since $DownSince"
            }
        }
    }
    if ($Alert) {
        $SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
    }
    $Server.LastStatus = $Connection.Status
    $Server.LastCheckTime = $DateTime
    [void]$Export.add($Server)
}
$Export | Export-Csv -Path $ServerListFilePath -Delimiter ',' -NoTypeInformation

