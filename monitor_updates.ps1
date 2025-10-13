# System Update Monitor Script
# Checks every hour for Windows Defender and Windows Updates
# Runs run_update.bat if updates are needed

$UserHome = "~\"
$LogFile = $UserHome + "\Logs\Update-Monitor-$(Get-Date -Format 'yyyy-MM-dd').log"
$null = New-Item -Path "$UserHome\Logs" -ItemType Directory -Force

function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host "$Timestamp - $Message"
}

function Check-DefenderUpdates {
    Write-Log "Checking Windows Defender update status..."
    try {
        $DefenderStatus = Get-MpComputerStatus -ErrorAction Stop
        $SignatureAge = $DefenderStatus.AntivirusSignatureAge
        $LastUpdate = $DefenderStatus.AntivirusSignatureLastUpdated
        
        Write-Log "Defender signatures last updated: $LastUpdate (Age: $SignatureAge days)"
        
        # If signatures are more than 1 day old, update is needed
        if ($SignatureAge -gt 1) {
            Write-Log "Defender signatures are out of date (>1 day old)"
            return $true
        } else {
            Write-Log "Defender signatures are up to date"
            return $false
        }
    } catch {
        Write-Log "Error checking Defender status: $($_.Exception.Message)"
        # If we can't check, assume update is needed for safety
        return $true
    }
}

function Check-WindowsUpdates {
    Write-Log "Checking for Windows Updates..."
    try {
        # Install PSWindowsUpdate if not available
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "Installing PSWindowsUpdate module..."
            Install-Module PSWindowsUpdate -Force -AllowClobber -ErrorAction Stop
        }
        Import-Module PSWindowsUpdate -ErrorAction Stop
        
        # Check for available updates
        $Updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop
        
        if ($Updates.Count -gt 0) {
            Write-Log "Found $($Updates.Count) available Windows Update(s)"
            Write-Log "Updates available:"
            foreach ($Update in $Updates) {
                Write-Log "  - $($Update.Title)"
            }
            return $true
        } else {
            Write-Log "No Windows Updates available"
            return $false
        }
    } catch {
        Write-Log "Error checking Windows Updates: $($_.Exception.Message)"
        # If we can't check, assume update is needed for safety
        return $true
    }
}

function Run-UpdateScript {
    Write-Log "Updates are needed. Running run_update.bat..."
    $UpdateBatPath = Join-Path $PSScriptRoot "run_update.bat"
    
    if (Test-Path $UpdateBatPath) {
        try {
            # Run the batch file and wait for it to complete
            $process = Start-Process -FilePath $UpdateBatPath -Wait -PassThru -NoNewWindow
            Write-Log "Update script completed with exit code: $($process.ExitCode)"
        } catch {
            Write-Log "Error running update script: $($_.Exception.Message)"
        }
    } else {
        Write-Log "ERROR: run_update.bat not found at: $UpdateBatPath"
    }
}

Write-Log "=========================================="
Write-Log "Starting System Update Monitor"
Write-Log "Checking interval: 1 hour"
Write-Log "=========================================="

# Main monitoring loop
$LoopCounter = 0
while ($true) {
    $LoopCounter++
    Write-Log ""
    Write-Log "--- Check Cycle #$LoopCounter ---"
    
    $DefenderNeedsUpdate = Check-DefenderUpdates
    $WindowsNeedsUpdate = Check-WindowsUpdates
    
    if ($DefenderNeedsUpdate -or $WindowsNeedsUpdate) {
        Write-Log "UPDATE REQUIRED - Initiating update process..."
        Run-UpdateScript
        Write-Log "Update process completed. Resuming monitoring..."
    } else {
        Write-Log "System is up to date. No action needed."
    }
    
    Write-Log "Next check in 1 hour..."
    Write-Log "Waiting... (Press Ctrl+C to stop monitoring)"
    
    # Sleep for 1 hour (3600 seconds)
    Start-Sleep -Seconds 3600
}

