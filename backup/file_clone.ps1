# Incremental File/Folder Clone Script using Robocopy
# Author: Akin Unver

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationPath,
    
    [switch]$Mirror,
    [switch]$DetailedOutput,
    [switch]$WhatIf,
    [string[]]$ExcludeFiles = @(),
    [string[]]$ExcludeDirs = @()
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Invoke-RobocopyOperation {
    param([string]$Source, [string]$Destination, [string]$FileName = $null)
    
    # Build robocopy arguments
    $args = @($Source, $Destination)
    if ($FileName) { $args += $FileName }
    
    $args += "/E", "/COPY:DAT", "/R:3", "/W:1"
    
    # Incremental logic
    if ((Test-Path $Destination) -and (Get-ChildItem $Destination -Recurse -File -ErrorAction SilentlyContinue)) {
        $args += "/XO"
    }
    
    if ($Mirror) { $args += "/MIR" }
    if ($WhatIf) { $args += "/L" }
    if (-not $DetailedOutput) { $args += "/NP" }
    
    # Add exclusions
    foreach ($exclude in $ExcludeFiles) { $args += "/XF", $exclude }
    foreach ($exclude in $ExcludeDirs) { $args += "/XD", $exclude }
    
    Write-Log "Executing: robocopy $($args -join ' ')"
    
    $null = & robocopy @args
    $exitCode = $LASTEXITCODE
    
    # Check results
    if ($exitCode -eq 0) {
        Write-Log "No changes needed - files are synchronized" "SUCCESS"
    } elseif ($exitCode -lt 8) {
        Write-Log "Operation completed successfully" "SUCCESS"
    } else {
        Write-Log "Operation failed with exit code: $exitCode" "ERROR"
        return $false
    }
    return $true
}

# Main execution
try {
    Write-Log "Starting clone operation: $SourcePath -> $DestinationPath"
    
    # Validate source
    if (-not (Test-Path $SourcePath)) {
        Write-Log "Source path does not exist: $SourcePath" "ERROR"
        exit 1
    }
    
    # Create destination if needed
    if (-not (Test-Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        Write-Log "Created destination directory: $DestinationPath" "SUCCESS"
    }
    
    # Execute operation
    $sourceItem = Get-Item $SourcePath
    if ($sourceItem.PSIsContainer) {
        $success = Invoke-RobocopyOperation -Source $SourcePath -Destination $DestinationPath
    } else {
        $sourceDir = Split-Path $SourcePath -Parent
        $fileName = Split-Path $SourcePath -Leaf
        $success = Invoke-RobocopyOperation -Source $sourceDir -Destination $DestinationPath -FileName $fileName
    }
    
    if (-not $success) { exit 1 }
    Write-Log "Clone operation completed successfully" "SUCCESS"
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    exit 1
}