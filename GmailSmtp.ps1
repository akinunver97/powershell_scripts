#With Login Prompt
Send-MailMessage -To 'aknnvr3@gmail.com' -From 'akin.unver97@gmail.com' -Subject 'An Email From Gmail Account' -Body 'Some Email content' -Credential (Get-Credential) -SmtpServer 'smtp.gmail.com' -Port 587 -UseSsl 


#Proper
$EmailFrom = "akin.unver97@gmail.com"
$EmailTo = "akin.unver97@gmail.com"
$Subject = "Subject Test"
$Body = "This is a notification from Test Notification.."
$SMTPServer = "smtp.gmail.com"
$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
$SMTPClient.EnableSsl = $true
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential("username", "password");
$SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)