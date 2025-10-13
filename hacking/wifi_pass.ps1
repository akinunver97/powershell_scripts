
$wifiName = (netsh wlan show interfaces | findstr SSID | findstr /V "BSSID" | findstr /V "State").Trim()

if ($wifiName -match "SSID\s+:\s+(.*)$") {

    $wifiName = $matches[1]

} else {

    Write-Output "Could not find connected Wi-Fi SSID."

    exit

}

$text = netsh wlan show profile name="$wifiName" key=clear | findstr "Key"

if ($text -match "Key Content\s+:\s+(.*)$") {

    $password = $matches[1]

    Write-Output "The Wi-Fi password is: $password"

} else {

    Write-Output "Password not found."

}