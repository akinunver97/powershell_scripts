<#
.SYNOPSIS
 CSV'den AD kullanıcılarını disable eder ve 7 gün sonra otomatik silinir.
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
Log "Disable/Auto-Remove script started. CSV: $CsvPath. WhatIfMode: $WhatIfMode" -Path $LogPath

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

if ($usersToProcess.Count -eq 0) {
    Log "No users to process." -Path $LogPath
    exit 0
}

# Kullanıcıları ekranda listele ve onay iste
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
            Log "(WhatIf) Would schedule automatic removal in 7 days: $($user.SamAccountName)" -Path $LogPath
            continue
        }

        # Disable user
        Set-ADUser -Identity $user -Enabled $false
        Log "Disabled user: $($user.SamAccountName)" -Path $LogPath

        # --- ScriptGenerated klasör kontrolü ---
        $scriptFolder = "C:\PowershellScripts\ScriptGenerated"
        if (-not (Test-Path -Path $scriptFolder)) {
            try {
                New-Item -Path $scriptFolder -ItemType Directory -Force | Out-Null
                Log "Created script folder: $scriptFolder" -Path $LogPath
            } catch {
                Log "ERROR: Failed to create script folder $scriptFolder : $_" -Path $LogPath
                continue
            }
        }

        # Remove script içeriği (her kullanıcı için)
        $removeScriptContent = @"
Import-Module ActiveDirectory
try {
    Remove-ADUser -Identity '$($user.SamAccountName)' -Confirm:`$false
} catch {
    Write-Output 'ERROR removing $($user.SamAccountName): ' + `$_
}
"@

        # Script dosyasını oluştur
        $userScriptPath = Join-Path $scriptFolder "$($user.SamAccountName)_Remove.ps1"
        $removeScriptContent | Set-Content -Path $userScriptPath -Force

        # Scheduled Task oluştur
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$userScriptPath`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddDays(7)
        $taskName = "RemoveUser_$($user.SamAccountName)_$(Get-Random)"

        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Auto remove AD user $($user.SamAccountName) in 7 days" -Force

        Log "Scheduled automatic removal of $($user.SamAccountName) in 7 days via task $taskName" -Path $LogPath

    } catch {
        Log "ERROR processing $($user.SamAccountName) : $_" -Path $LogPath
    }
}

Log "Disable/Auto-Remove script finished." -Path $LogPath
