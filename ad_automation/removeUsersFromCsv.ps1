<#
.SYNOPSIS
 CSV'den AD kullanıcılarını disable eder ve 7 gün sonra silinecek şekilde işaretler.
.INPUTS
 CSV with headers: SamAccountName
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [string]$LogPath = "C:\PowershellScripts\Logs\DisableRemoveUsers_$(Get-Date -Format yyyyMMdd_HHmmss).log",

    [switch]$WhatIfMode
)

# Load AD module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT / Active Directory PowerShell module."
    exit 1
}
Import-Module ActiveDirectory

# --- LOG FUNCTION ---
function Log {
    param(
        [string]$Message,
        [string]$Path
    )

    $logDir = Split-Path $Path -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp`t$Message"
    Add-Content -Path $Path -Value $line
    Write-Output $line
}

# --- SCRIPT START ---
Log "Disable/Remove script started. CSV: $CsvPath. WhatIfMode: $WhatIfMode" -Path $LogPath

# Import CSV
try {
    $users = Import-Csv -Path $CsvPath -ErrorAction Stop |
        Where-Object { -not ($_.SamAccountName -like '#*') }
} catch {
    Log "ERROR reading CSV: $_" -Path $LogPath
    throw
}

# Kullanıcıları toplu listele
$usersToProcess = @()
foreach ($u in $users) {
    $sam = ($u.SamAccountName).Trim()
    if (-not $sam) { continue }

    $user = Get-ADUser -Filter { SamAccountName -eq $sam } -ErrorAction SilentlyContinue
    if ($user) {
        $usersToProcess += $user
    } else {
        Log "User $sam not found. Skipping." -Path $LogPath
    }
}

# Kullanıcıları ekranda listele ve onay iste
if ($usersToProcess.Count -eq 0) {
    Log "No users to process." -Path $LogPath
    exit 0
}

Write-Host "The following users will be disabled and scheduled for removal in 7 days:`n"
$usersToProcess | ForEach-Object { Write-Host $_.SamAccountName }

$confirmation = Read-Host "`nDo you want to proceed? Type 'Y' to confirm"
if ($confirmation -ne 'Y') {
    Log "Operation cancelled by user." -Path $LogPath
    exit 0
}

# İşleme başla
foreach ($user in $usersToProcess) {
    try {
        if ($WhatIfMode) {
            Log "(WhatIf) Would disable user: $($user.SamAccountName)" -Path $LogPath
            Log "(WhatIf) Would schedule removal in 7 days: $($user.SamAccountName)" -Path $LogPath
            continue
        }

        # Disable user
        Set-ADUser -Identity $user -Enabled $false
        Log "Disabled user: $($user.SamAccountName)" -Path $LogPath

        # Schedule removal in 7 days
        $removeDate = (Get-Date).AddDays(7)
        Set-ADUser -Identity $user -Description "Scheduled for deletion on $($removeDate.ToString('yyyy-MM-dd'))"
        Log "User $($user.SamAccountName) scheduled for removal on $($removeDate.ToString('yyyy-MM-dd'))" -Path $LogPath

        # Opsiyonel: buraya bir scheduled task veya script eklenebilir, 7 gün sonra Remove-ADUser çalıştırmak için

    } catch {
        Log "ERROR processing $($user.SamAccountName) : $_" -Path $LogPath
    }
}

Log "Disable/Remove script finished." -Path $LogPath
