<#
.SYNOPSIS
 CSV'den AD kullanıcı oluşturur, başlangıç parolası Password1! olur, ve "Change password at next logon" etkinleştirilir.
.INPUTS
 CSV with headers: SamAccountName,GivenName,Surname,DisplayName,UserPrincipalName,OU
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [string]$DefaultPassword = "Password1!",

    [string]$DefaultOU = "OU=Users,DC=au,DC=lab",

    [string]$LogPath = "C:\PowershellScripts\Logs\CreateUsers_$(Get-Date -Format yyyyMMdd_HHmmss).log",

    [switch]$WhatIfMode
)

# Load AD module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not found. Install RSAT / Active Directory PowerShell module."
    exit 1
}
Import-Module ActiveDirectory

# Secure password object
$securePass = ConvertTo-SecureString -AsPlainText $DefaultPassword -Force

# Logging helper
function Log {
    param(
        [string]$Message,
        [string]$Path
    )

    # Log klasörü kontrolü
    $logDir = Split-Path $Path -Parent
    if (-not (Test-Path -Path $logDir)) {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        } catch {
            Write-Error "ERROR: Failed to create log directory $logDir : $_"
            exit 1
        }
    }

    # Log satırı yaz
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp`t$Message"
    Add-Content -Path $Path -Value $line
    Write-Output $line
}

# --- SCRIPT START ---
Log "Script started. CSV: $CsvPath. DefaultPassword set. WhatIfMode: $WhatIfMode" -Path $LogPath

# Import CSV
try {
    $users = Import-Csv -Path $CsvPath -ErrorAction Stop |
        Where-Object { -not ($_.SamAccountName -like '#*') }
} catch {
    Log "ERROR reading CSV: $_" -Path $LogPath
    throw
}

foreach ($u in $users) {
    try {
        $sam = ($u.SamAccountName).Trim()
        if (-not $sam) {
            Log "Skipping row with empty SamAccountName: $($u | Out-String)" -Path $LogPath
            continue
        }

        $given = $u.GivenName
        $sn = $u.Surname
        $display = if ($u.DisplayName) { $u.DisplayName } else { "$given $sn" }
        $upn = if ($u.UserPrincipalName) { $u.UserPrincipalName } else { "$sam@$( (Get-ADDomain).DNSRoot )" }
        $ou = if ($u.OU) { $u.OU } else { $DefaultOU }

        # Check if user exists
        $exists = Get-ADUser -Filter { SamAccountName -eq $sam } -ErrorAction SilentlyContinue
        if ($exists) {
            Log "User $sam already exists. Skipping." -Path $LogPath
            continue
        }

        Log "Creating user: $sam in $ou" -Path $LogPath

        if ($WhatIfMode) {
            Log "(WhatIf) Would run: New-ADUser -Name '$display' -SamAccountName '$sam' -UserPrincipalName '$upn' -Path '$ou'" -Path $LogPath
            continue
        }

        # Create user
        New-ADUser `
            -Name $display `
            -SamAccountName $sam `
            -UserPrincipalName $upn `
            -GivenName $given `
            -Surname $sn `
            -DisplayName $display `
            -Path $ou `
            -AccountPassword $securePass `
            -Enabled $true `
            -PasswordNeverExpires $false `
            -ChangePasswordAtLogon $true

        Log "Created $sam and required password change at next logon." -Path $LogPath

    } catch {
        Log "ERROR creating $sam : $_" -Path $LogPath
    }
}

Log "Script finished." -Path $LogPath
