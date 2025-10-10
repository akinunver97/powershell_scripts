function Test-SpaceX {
    [CmdletBinding()] #turns into adv. func
    param(
        [Parameter(Mandatory)]
        [Int32]$PingCount
    )
    Test-Connection -Ping -Count $PingCount spacex.com
    Write-Error -Message "It's a trap!" -ErrorAction Stop
}

try {Test-SpaceX -ErrorAction Stop} catch { Write-Output "Launch problem!" }