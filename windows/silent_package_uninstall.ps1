
# Silent Package Uninstall Script for Windows
# Description: Uninstalls NetWorker clients silently using winget
# Author: PowerShell Scripts Collection
# Date: $(Get-Date -Format "yyyy-MM-dd")

param(
    [string]$PackagePattern = "NetWorker*",
    [string[]]$ExcludePackages = @("NetWorker Management Console"),
    [switch]$WhatIf,
    [switch]$Verbose
)

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Show DEBUG messages only when Verbose is enabled
    if ($Level -eq "DEBUG" -and -not $Verbose) {
        return
    }
    
    Write-Host $logMessage
    if ($Verbose) {
        Add-Content -Path "uninstall_log.txt" -Value $logMessage
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get winget version and check compatibility
function Test-WingetVersion {
    try {
        $wingetVersion = winget --version 2>&1
        Write-Log "Winget version detected: $wingetVersion"
        
        # Extract version number (remove 'v' prefix if present)
        if ($wingetVersion -match 'v?(\d+\.\d+\.\d+)') {
            $version = [version]$matches[1]
            # Version 1.4.0 introduced --accept-package-agreements
            return $version -ge [version]"1.4.0"
        }
        return $false
    }
    catch {
        Write-Log "Could not determine winget version: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Main script execution
try {
    Write-Log "Starting silent package uninstall script"
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Log "Warning: Script is not running as administrator. Some uninstalls may fail." "WARNING"
    }
    
    # Check winget version compatibility
    $supportsNewParameters = Test-WingetVersion

    # Get installed packages using winget
    Write-Log "Retrieving installed packages..."
    $installedPackages = winget list --accept-source-agreements | Out-String
    
    if ([string]::IsNullOrEmpty($installedPackages)) {
        Write-Log "Failed to retrieve package list or no packages found" "ERROR"
        exit 1
    }

    # Parse winget output and find matching packages
    $lines = $installedPackages -split "`n"
    $packagesToUninstall = @()
    
    Write-Log "Parsing winget output..." "DEBUG"
    
    foreach ($line in $lines) {
        # Skip header lines and empty lines
        if ($line -match "^Name\s+Id\s+Version" -or [string]::IsNullOrWhiteSpace($line) -or $line -match "^-+") {
            continue
        }
        
        # More robust parsing - winget output can vary
        $trimmedLine = $line.Trim()
        if ($trimmedLine.Length -gt 0) {
            # Split by multiple spaces and filter out empty entries
            $parts = $trimmedLine -split '\s{2,}' | Where-Object { $_ -ne '' }
            
            if ($parts.Count -ge 3) {
                $packageName = $parts[0].Trim()
                $packageId = $parts[1].Trim()
                $packageVersion = $parts[2].Trim()
                
                Write-Log "DEBUG: Parsed - Name: '$packageName', ID: '$packageId', Version: '$packageVersion'" "DEBUG"
                
                # Check if package matches pattern and is not excluded
                if ($packageName -like $PackagePattern -and $packageName -notin $ExcludePackages) {
                    $packagesToUninstall += [PSCustomObject]@{
                        Name = $packageName
                        Id = $packageId
                        Version = $packageVersion
                        OriginalLine = $trimmedLine
                    }
                }
            }
            # Alternative parsing for different winget output formats
            elseif ($parts.Count -eq 2) {
                $packageName = $parts[0].Trim()
                $packageId = $parts[1].Trim()
                
                Write-Log "DEBUG: Parsed (2 parts) - Name: '$packageName', ID: '$packageId'" "DEBUG"
                
                if ($packageName -like $PackagePattern -and $packageName -notin $ExcludePackages) {
                    $packagesToUninstall += [PSCustomObject]@{
                        Name = $packageName
                        Id = $packageId
                        Version = "Unknown"
                        OriginalLine = $trimmedLine
                    }
                }
            }
        }
    }

    if ($packagesToUninstall.Count -eq 0) {
        Write-Log "No packages matching pattern '$PackagePattern' found for uninstallation"
        exit 0
    }

    Write-Log "Found $($packagesToUninstall.Count) package(s) to uninstall:"
    foreach ($package in $packagesToUninstall) {
        Write-Log "  - $($package.Name) (ID: $($package.Id))"
    }

    # Uninstall packages
    foreach ($package in $packagesToUninstall) {
        if ($WhatIf) {
            Write-Log "WHATIF: Would uninstall $($package.Name)" "INFO"
            continue
        }
        
        Write-Log "Uninstalling $($package.Name)..."
        
        try {
            $uninstallSuccess = $false
            
            # Method 1: Try with package ID (if it looks valid)
            if ($package.Id -and $package.Id -ne "Unknown" -and $package.Id.Length -gt 3) {
                Write-Log "Method 1: Trying uninstall with ID '$($package.Id)'..."
                
                if ($supportsNewParameters) {
                    $result = winget uninstall --id "$($package.Id)" --silent --accept-source-agreements --disable-interactivity 2>&1
                } else {
                    $result = winget uninstall --id "$($package.Id)" --silent --accept-source-agreements 2>&1
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $uninstallSuccess = $true
                    Write-Log "Successfully uninstalled $($package.Name) using ID" "SUCCESS"
                }
            }
            
            # Method 2: Try with package name if ID method failed
            if (-not $uninstallSuccess) {
                Write-Log "Method 2: Trying uninstall with name '$($package.Name)'..."
                $result = winget uninstall "$($package.Name)" --silent 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $uninstallSuccess = $true
                    Write-Log "Successfully uninstalled $($package.Name) using name" "SUCCESS"
                }
            }
            
            # Method 3: Try exact match with quotes
            if (-not $uninstallSuccess) {
                Write-Log "Method 3: Trying exact match with quotes..."
                $result = winget uninstall --name "$($package.Name)" --exact --silent 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $uninstallSuccess = $true
                    Write-Log "Successfully uninstalled $($package.Name) using exact match" "SUCCESS"
                }
            }
            
            # Method 4: Try searching and uninstalling first match
            if (-not $uninstallSuccess) {
                Write-Log "Method 4: Searching for package and using first result..."
                $searchResult = winget search "$($package.Name)" 2>&1
                
                if ($LASTEXITCODE -eq 0 -and $searchResult) {
                    # Parse search results to find exact match
                    $searchLines = $searchResult -split "`n"
                    foreach ($searchLine in $searchLines) {
                        if ($searchLine -match $package.Name -and $searchLine -notmatch "^Name\s+Id" -and $searchLine.Trim().Length -gt 0) {
                            $searchParts = $searchLine.Trim() -split '\s{2,}' | Where-Object { $_ -ne '' }
                            if ($searchParts.Count -ge 2) {
                                $searchId = $searchParts[1].Trim()
                                Write-Log "Found search ID: '$searchId', attempting uninstall..."
                                $result = winget uninstall --id "$searchId" --silent 2>&1
                                
                                if ($LASTEXITCODE -eq 0) {
                                    $uninstallSuccess = $true
                                    Write-Log "Successfully uninstalled $($package.Name) using search ID '$searchId'" "SUCCESS"
                                    break
                                }
                            }
                        }
                    }
                }
            }
            
            # Method 5: Last resort - interactive uninstall
            if (-not $uninstallSuccess) {
                Write-Log "Method 5: Last resort - interactive uninstall..." "WARNING"
                $result = winget uninstall "$($package.Name)" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $uninstallSuccess = $true
                    Write-Log "Successfully uninstalled $($package.Name) using interactive method" "SUCCESS"
                }
            }
            
            if (-not $uninstallSuccess) {
                Write-Log "All uninstall methods failed for $($package.Name). Exit code: $LASTEXITCODE" "ERROR"
                Write-Log "Final error details: $result" "ERROR"
                Write-Log "Original parsed line: $($package.OriginalLine)" "DEBUG"
            }
        }
        catch {
            Write-Log "Exception occurred while uninstalling $($package.Name): $($_.Exception.Message)" "ERROR"
        }
        
        # Add a small delay between uninstalls
        Start-Sleep -Seconds 2
    }

    Write-Log "Silent package uninstall script completed"
}
catch {
    Write-Log "Fatal error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}