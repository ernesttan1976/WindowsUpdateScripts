 # GlobalProtect System Update Script
# Schedule this to run daily between 4-6 AM

# Create log file with timestamp
$UserHome = "C:\Users\Ernest"
$LogFile = $UserHome + "\Logs\GlobalProtect-Update-$(Get-Date -Format 'yyyy-MM-dd').log"
$null = New-Item -Path "$UserHome\Logs" -ItemType Directory -Force

function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host "$Timestamp - $Message"
}

function Remove-IncompleteUpdates {
    Write-Log "Checking for incomplete or corrupted update files..."
    
    # Windows Update cache locations
    $UpdatePaths = @(
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:SystemRoot\Temp",
        "$env:TEMP"
    )
    
    $TotalCleaned = 0
    
    foreach ($Path in $UpdatePaths) {
        if (Test-Path $Path) {
            Write-Log "Scanning $Path for incomplete files..."
            
            # Find files that might be incomplete (common patterns)
            $IncompleteFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -match '\.tmp$|\.partial$|\.download$|\.incomplete$' -or
                $_.Length -eq 0 -or
                ($_.LastWriteTime -lt (Get-Date).AddDays(-7) -and $_.Name -match '\.cab$|\.msu$|\.exe$')
            }
            
            foreach ($File in $IncompleteFiles) {
                try {
                    Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                    Write-Log "Removed incomplete file: $($File.Name)"
                    $TotalCleaned++
                } catch {
                    Write-Log "Failed to remove $($File.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    
    Write-Log "Cleaned up $TotalCleaned incomplete or corrupted update files"
}

function Clear-UpdateCache {
    Write-Log "Clearing Windows Update cache..."
    
    try {
        # Stop Windows Update service
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Write-Log "Stopped Windows Update service"
        
        # Clear SoftwareDistribution folder
        $SoftwareDistPath = "$env:SystemRoot\SoftwareDistribution"
        if (Test-Path $SoftwareDistPath) {
            Remove-Item -Path "$SoftwareDistPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Cleared SoftwareDistribution cache"
        }
        
        # Clear Catroot2 folder
        $Catroot2Path = "$env:SystemRoot\System32\Catroot2"
        if (Test-Path $Catroot2Path) {
            Remove-Item -Path "$Catroot2Path\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Cleared Catroot2 cache"
        }
        
        # Restart Windows Update service
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Log "Restarted Windows Update service"
        
    } catch {
        Write-Log "Error clearing update cache: $($_.Exception.Message)"
    }
}

Write-Log "Starting GlobalProtect compliance update script"

try {
    # Clean up any incomplete or corrupted update files before starting
    Remove-IncompleteUpdates
    
    # Install and import PSWindowsUpdate module for Windows Updates
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installing PSWindowsUpdate module..."
        Install-Module PSWindowsUpdate -Force -AllowClobber
    }
    Import-Module PSWindowsUpdate

    # Check for and install Windows Updates
    Write-Log "Checking for Windows Updates..."
    $Updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot
    if ($Updates.Count -gt 0) {
        Write-Log "Installing $($Updates.Count) Windows Updates..."
        Install-WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false
        Write-Log "Windows Updates installed successfully"
        
        # Clean up any incomplete files that may have been created during update process
        Remove-IncompleteUpdates
    } else {
        Write-Log "No Windows Updates available"
    }

    # Update Windows Defender definitions
    Write-Log "Updating Windows Defender definitions..."
    Update-MpSignature
    Write-Log "Windows Defender definitions updated"

    # Enable Windows Defender real-time protection
    Write-Log "Ensuring Windows Defender is properly configured..."
    Set-MpPreference -DisableRealtimeMonitoring $false
    Set-MpPreference -DisableBehaviorMonitoring $false
    Set-MpPreference -DisableBlockAtFirstSeen $false

    # Enable Windows Firewall
    Write-Log "Configuring Windows Firewall..."
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

    # Check BitLocker status and enable if not active
    Write-Log "Checking BitLocker status..."
    $BitLockerStatus = Get-BitLockerVolume -MountPoint "C:"
    if ($BitLockerStatus.ProtectionStatus -eq "Off") {
        Write-Log "BitLocker is not enabled. This may require manual intervention."
        # Note: Auto-enabling BitLocker requires TPM and may need user interaction
    } else {
        Write-Log "BitLocker is properly configured"
    }

    # Clean up temporary files and any remaining incomplete update files
    Write-Log "Cleaning temporary files..."
    Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    
    # Final cleanup of any incomplete update files
    Remove-IncompleteUpdates
    
    # Update certificate store
    Write-Log "Updating certificate store..."
    certlm.msc /s

    # Force Group Policy update (if domain-joined)
    Write-Log "Updating Group Policy..."
    gpupdate /force

    Write-Log "GlobalProtect compliance update completed successfully"
    
    # Optional: Restart if updates require it (uncomment if needed)
    # if ((Get-WURebootStatus).RebootRequired) {
    #     Write-Log "System restart required. Scheduling restart in 5 minutes..."
    #     shutdown /r /t 300 /c "Restarting for GlobalProtect compliance updates"
    # }

} catch {
    Write-Log "Error occurred: $($_.Exception.Message)"
    
    # If there was an error with Windows Updates, try clearing the cache
    if ($_.Exception.Message -match "Windows Update|PSWindowsUpdate|Get-WindowsUpdate|Install-WindowsUpdate") {
        Write-Log "Windows Update error detected. Attempting to clear update cache..."
        Clear-UpdateCache
        Remove-IncompleteUpdates
    }
    
    exit 1
}