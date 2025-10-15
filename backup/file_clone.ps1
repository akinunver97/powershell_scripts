# Incremental File/Folder Clone Script using Robocopy
# Description: Detects if source is file or folder and performs incremental clone
# Author: PowerShell Scripts Collection
# Date: $(Get-Date -Format "yyyy-MM-dd")
#
# ROBOCOPY EXIT CODES (Bit Flags):
# 0  = No changes detected
# 1  = Files copied successfully  
# 2  = Extra files/directories detected in destination
# 3  = Files copied + extra files detected (1+2)
# 4  = Mismatched files/directories detected
# 8  = Some files could not be copied (permission/access issues)
# 16 = Serious error - no files copied
#
# PARAMETERS EXPLAINED:
# -SourcePath      : Source file or folder path (mandatory)
# -DestinationPath : Destination folder path (mandatory) 
# -Mirror          : Enable mirror mode - deletes files in dest that don't exist in source
# -DetailedOutput  : Show detailed robocopy output with timestamps and full paths
# -WhatIf          : Preview mode - shows what would be copied without actually copying
# -ExcludeFiles    : Array of file patterns to exclude (e.g., "*.tmp","*.log")
# -ExcludeDirs     : Array of directory patterns to exclude (e.g., "temp","cache")
#
# Usage Examples:
#   .\file_clone.ps1 -SourcePath "C:\MyFile.txt" -DestinationPath "D:\Backup"
#   .\file_clone.ps1 -SourcePath "C:\MyFolder" -DestinationPath "D:\Backup"
#   .\file_clone.ps1 -SourcePath "C:\MyFolder" -DestinationPath "D:\Backup" -Mirror
#   .\file_clone.ps1 -SourcePath "C:\MyFolder" -DestinationPath "D:\Backup" -DetailedOutput
#   .\file_clone.ps1 -SourcePath "C:\MyFolder" -DestinationPath "D:\Backup" -WhatIf
#   .\file_clone.ps1 -SourcePath "C:\MyFolder" -DestinationPath "D:\Backup" -ExcludeFiles "*.tmp","*.bak"

param(
    [Parameter(Mandatory=$true, HelpMessage="Source file or folder path")]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true, HelpMessage="Destination folder path")]
    [string]$DestinationPath,
    
    [Parameter(HelpMessage="Enable mirror mode (deletes files in destination that don't exist in source)")]
    [switch]$Mirror,
    
    [Parameter(HelpMessage="Enable detailed output")]
    [switch]$DetailedOutput,
    
    [Parameter(HelpMessage="Show what would be copied without actually copying")]
    [switch]$WhatIf,
    
    [Parameter(HelpMessage="Exclude files matching these patterns (comma-separated)")]
    [string[]]$ExcludeFiles = @(),
    
    [Parameter(HelpMessage="Exclude directories matching these patterns (comma-separated)")]
    [string[]]$ExcludeDirs = @()
)

# Function to log messages with timestamp
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

# Function to validate paths
function Test-Paths {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    # Check if source exists
    if (-not (Test-Path -Path $Source)) {
        Write-Log "Source path does not exist: $Source" "ERROR"
        return $false
    }
    
    # Create destination directory if it doesn't exist
    if (-not (Test-Path -Path $Destination)) {
        try {
            New-Item -Path $Destination -ItemType Directory -Force | Out-Null
            Write-Log "Created destination directory: $Destination" "SUCCESS"
        }
        catch {
            Write-Log "Failed to create destination directory: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    
    return $true
}

# Function to build robocopy arguments
function Build-RobocopyArgs {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$FilePattern = "*.*",
        [bool]$IsFile = $false
    )
    
    $robocopyParams = @()
    
    # Basic arguments for incremental copy
    $robocopyParams += "/E"        # Copy subdirectories, including empty ones
    $robocopyParams += "/DCOPY:DAT" # Copy directory attributes, data, and timestamps
    $robocopyParams += "/COPY:DAT"  # Copy file data, attributes, and timestamps
    $robocopyParams += "/R:3"       # Retry 3 times on failed copies
    $robocopyParams += "/W:1"       # Wait 1 second between retries
    
    # Only exclude older files if destination already exists and has files
    if ((Test-Path $Destination) -and (Get-ChildItem $Destination -Recurse -File -ErrorAction SilentlyContinue)) {
        $robocopyParams += "/XO"    # Exclude older files (incremental)
        Write-Log "Incremental mode: excluding older files" "INFO"
    } else {
        Write-Log "Initial copy: copying all files" "INFO"
    }
    
    # Mirror mode (deletes files in destination that don't exist in source)
    if ($Mirror) {
        $robocopyParams += "/MIR"
        Write-Log "Mirror mode enabled - files in destination will be synchronized" "WARNING"
    }
    
    # Progress and logging options
    if ($DetailedOutput) {
        $robocopyParams += "/V"     # Verbose output
        $robocopyParams += "/TS"    # Include source file time stamps
        $robocopyParams += "/FP"    # Include full pathname of files
    } else {
        $robocopyParams += "/NP"    # No progress percentage
    }
    
    # WhatIf mode
    if ($WhatIf) {
        $robocopyParams += "/L"     # List only - don't copy, delete or timestamp any files
        Write-Log "WhatIf mode enabled - no files will be copied" "INFO"
    }
    
    # Exclude files
    if ($ExcludeFiles.Count -gt 0) {
        foreach ($exclude in $ExcludeFiles) {
            $robocopyParams += "/XF"
            $robocopyParams += $exclude
        }
        Write-Log "Excluding files: $($ExcludeFiles -join ', ')" "INFO"
    }
    
    # Exclude directories
    if ($ExcludeDirs.Count -gt 0) {
        foreach ($exclude in $ExcludeDirs) {
            $robocopyParams += "/XD"
            $robocopyParams += $exclude
        }
        Write-Log "Excluding directories: $($ExcludeDirs -join ', ')" "INFO"
    }
    
    return $robocopyParams
}

# Function to copy a single file using robocopy
function Copy-SingleFile {
    param(
        [string]$SourceFile,
        [string]$DestinationFolder
    )
    
    $sourceDir = Split-Path -Path $SourceFile -Parent
    $fileName = Split-Path -Path $SourceFile -Leaf
    
    Write-Log "Cloning file: $fileName from $sourceDir to $DestinationFolder"
    
    # Build robocopy arguments for single file
    $robocopyArgs = @($sourceDir, $DestinationFolder, $fileName)
    $robocopyArgs += Build-RobocopyArgs -Source $sourceDir -Destination $DestinationFolder -IsFile $true
    
    # Execute robocopy
    Write-Log "Executing: robocopy $($robocopyArgs -join ' ')" "INFO"
    
    $result = & robocopy @robocopyArgs
    $exitCode = $LASTEXITCODE
    
    # Interpret robocopy exit codes (bit flags)
    $success = $true
    $messages = @()
    
    if ($exitCode -band 1) { $messages += "One or more files were copied successfully" }
    if ($exitCode -band 2) { $messages += "Some extra files or directories were detected" }
    if ($exitCode -band 4) { $messages += "Some mismatched files or directories were detected" }
    if ($exitCode -band 8) { $messages += "Some files or directories could not be copied"; $success = $false }
    if ($exitCode -band 16) { $messages += "Serious error occurred - Robocopy did not copy any files"; $success = $false }
    
    if ($exitCode -eq 0) {
        Write-Log "No changes detected - all files are already synchronized" "INFO"
    } elseif ($success) {
        Write-Log "Operation completed successfully: $($messages -join '; ')" "SUCCESS"
    } else {
        Write-Log "Operation completed with errors: $($messages -join '; ')" "ERROR"
        return $false
    }
    
    return $true
}

# Function to copy a folder using robocopy
function Copy-FolderContent {
    param(
        [string]$SourceFolder,
        [string]$DestinationFolder
    )
    
    Write-Log "Cloning folder: $SourceFolder to $DestinationFolder"
    
    # Build robocopy arguments for folder
    $robocopyArgs = @($SourceFolder, $DestinationFolder)
    $robocopyArgs += Build-RobocopyArgs -Source $SourceFolder -Destination $DestinationFolder
    
    # Execute robocopy
    Write-Log "Executing: robocopy $($robocopyArgs -join ' ')" "INFO"
    
    $result = & robocopy @robocopyArgs
    $exitCode = $LASTEXITCODE
    
    # Interpret robocopy exit codes (bit flags)
    $success = $true
    $messages = @()
    
    if ($exitCode -band 1) { $messages += "One or more files were copied successfully" }
    if ($exitCode -band 2) { $messages += "Some extra files or directories were detected" }
    if ($exitCode -band 4) { $messages += "Some mismatched files or directories were detected" }
    if ($exitCode -band 8) { $messages += "Some files or directories could not be copied"; $success = $false }
    if ($exitCode -band 16) { $messages += "Serious error occurred - Robocopy did not copy any files"; $success = $false }
    
    if ($exitCode -eq 0) {
        Write-Log "No changes detected - all files are already synchronized" "INFO"
    } elseif ($success) {
        Write-Log "Operation completed successfully: $($messages -join '; ')" "SUCCESS"
    } else {
        Write-Log "Operation completed with errors: $($messages -join '; ')" "ERROR"
        return $false
    }
    
    return $true
}

# Main execution
try {
    Write-Log "Starting incremental clone operation"
    Write-Log "Source: $SourcePath"
    Write-Log "Destination: $DestinationPath"
    
    # Validate source and destination paths
    if (-not (Test-Paths -Source $SourcePath -Destination $DestinationPath)) {
        exit 1
    }
    
    # Determine if source is a file or folder
    $sourceItem = Get-Item -Path $SourcePath
    
    if ($sourceItem.PSIsContainer) {
        # Source is a folder
        Write-Log "Source is a folder - performing folder synchronization" "INFO"
        $success = Copy-FolderContent -SourceFolder $SourcePath -DestinationFolder $DestinationPath
    } else {
        # Source is a file
        Write-Log "Source is a file - performing file copy" "INFO"
        $success = Copy-SingleFile -SourceFile $SourcePath -DestinationFolder $DestinationPath
    }
    
    if ($success) {
        Write-Log "Clone operation completed successfully" "SUCCESS"
        
        # Show summary statistics if not in WhatIf mode
        if (-not $WhatIf) {
            $destSize = if ($sourceItem.PSIsContainer) {
                (Get-ChildItem -Path $DestinationPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
            } else {
                (Get-Item -Path (Join-Path $DestinationPath $sourceItem.Name) -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            }
            
            if ($destSize) {
                $sizeGB = [math]::Round($destSize / 1GB, 2)
                Write-Log "Total synchronized size: $sizeGB GB" "INFO"
            }
        }
    } else {
        Write-Log "Clone operation failed" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Fatal error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}