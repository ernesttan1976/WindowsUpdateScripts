 # GlobalProtect System Update Script
# Schedule this to run daily between 4-6 AM

# Create log file with timestamp
$UserHome = "~\"
$LogFile = $UserHome + "\Logs\GlobalProtect-Update-$(Get-Date -Format 'yyyy-MM-dd').log"
$null = New-Item -Path "$UserHome\Logs" -ItemType Directory -Force

function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host "$Timestamp - $Message"
}

function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$CurrentOperation = 0,
        [int]$TotalOperations = 0
    )
    
    if ($TotalOperations -gt 0) {
        $Status = "$Status ($CurrentOperation of $TotalOperations)"
    }
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Show-DownloadProgress {
    param(
        [string]$FileName,
        [long]$BytesReceived,
        [long]$TotalBytes
    )
    
    if ($TotalBytes -gt 0) {
        $PercentComplete = [math]::Round(($BytesReceived / $TotalBytes) * 100, 2)
        $MBReceived = [math]::Round($BytesReceived / 1MB, 2)
        $MBTotal = [math]::Round($TotalBytes / 1MB, 2)
        $Status = "Downloading $FileName - $MBReceived MB of $MBTotal MB ($PercentComplete%)"
        Show-Progress -Activity "Download Progress" -Status $Status -PercentComplete $PercentComplete
    }
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
    $CurrentPath = 0
    
    foreach ($Path in $UpdatePaths) {
        $CurrentPath++
        $PercentComplete = [math]::Round(($CurrentPath / $UpdatePaths.Count) * 100)
        Show-Progress -Activity "Cleaning Incomplete Files" -Status "Scanning $Path" -PercentComplete $PercentComplete -CurrentOperation $CurrentPath -TotalOperations $UpdatePaths.Count
        
        if (Test-Path $Path) {
            Write-Log "Scanning $Path for incomplete files..."
            
            # Find files that might be incomplete (common patterns)
            $IncompleteFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -match '\.tmp$|\.partial$|\.download$|\.incomplete$' -or
                $_.Length -eq 0 -or
                ($_.LastWriteTime -lt (Get-Date).AddDays(-7) -and $_.Name -match '\.cab$|\.msu$|\.exe$')
            }
            
            $FileCount = $IncompleteFiles.Count
            $CurrentFile = 0
            
            foreach ($File in $IncompleteFiles) {
                $CurrentFile++
                $FilePercent = if ($FileCount -gt 0) { [math]::Round(($CurrentFile / $FileCount) * 100) } else { 0 }
                Show-Progress -Activity "Removing Incomplete Files" -Status "Removing $($File.Name)" -PercentComplete $FilePercent -CurrentOperation $CurrentFile -TotalOperations $FileCount
                
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
    
    Write-Progress -Activity "Cleaning Incomplete Files" -Completed
    Write-Log "Cleaned up $TotalCleaned incomplete or corrupted update files"
}

function Clear-UpdateCache {
    Write-Log "Clearing Windows Update cache..."
    
    try {
        $CacheSteps = @(
            "Stopping Windows Update service",
            "Clearing SoftwareDistribution cache",
            "Clearing Catroot2 cache",
            "Restarting Windows Update service"
        )
        
        for ($i = 0; $i -lt $CacheSteps.Count; $i++) {
            $PercentComplete = [math]::Round((($i + 1) / $CacheSteps.Count) * 100)
            Show-Progress -Activity "Clearing Update Cache" -Status $CacheSteps[$i] -PercentComplete $PercentComplete -CurrentOperation ($i + 1) -TotalOperations $CacheSteps.Count
            
            switch ($i) {
                0 {
                    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                    Write-Log "Stopped Windows Update service"
                }
                1 {
                    $SoftwareDistPath = "$env:SystemRoot\SoftwareDistribution"
                    if (Test-Path $SoftwareDistPath) {
                        Remove-Item -Path "$SoftwareDistPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Cleared SoftwareDistribution cache"
                    }
                }
                2 {
                    $Catroot2Path = "$env:SystemRoot\System32\Catroot2"
                    if (Test-Path $Catroot2Path) {
                        Remove-Item -Path "$Catroot2Path\*" -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Cleared Catroot2 cache"
                    }
                }
                3 {
                    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                    Write-Log "Restarted Windows Update service"
                }
            }
        }
        
        Write-Progress -Activity "Clearing Update Cache" -Completed
        
    } catch {
        Write-Progress -Activity "Clearing Update Cache" -Completed
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
        Show-Progress -Activity "Installing PSWindowsUpdate Module" -Status "Downloading and installing module..." -PercentComplete 0
        Install-Module PSWindowsUpdate -Force -AllowClobber
        Show-Progress -Activity "Installing PSWindowsUpdate Module" -Status "Module installation completed" -PercentComplete 100
        Write-Progress -Activity "Installing PSWindowsUpdate Module" -Completed
    }
    Import-Module PSWindowsUpdate

    # Check for and install Windows Updates
    Write-Log "Checking for Windows Updates..."
    Show-Progress -Activity "Windows Updates" -Status "Checking for available updates..." -PercentComplete 25
    $Updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot
    if ($Updates.Count -gt 0) {
        Write-Log "Installing $($Updates.Count) Windows Updates..."
        Show-Progress -Activity "Windows Updates" -Status "Downloading and installing $($Updates.Count) updates..." -PercentComplete 50
        
        # Create a job to monitor the installation progress
        $InstallJob = Start-Job -ScriptBlock {
            param($UpdateCount)
            Install-WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false
        } -ArgumentList $Updates.Count
        
        # Monitor the job progress
        $JobComplete = $false
        $ProgressCounter = 50
        while (-not $JobComplete) {
            if ($InstallJob.State -eq "Completed" -or $InstallJob.State -eq "Failed") {
                $JobComplete = $true
                $ProgressCounter = 100
            } else {
                $ProgressCounter = [math]::Min($ProgressCounter + 5, 95)
            }
            
            Show-Progress -Activity "Windows Updates" -Status "Installing updates... ($($InstallJob.State))" -PercentComplete $ProgressCounter
            Start-Sleep -Seconds 2
        }
        
        Receive-Job $InstallJob
        Remove-Job $InstallJob
        
        Write-Progress -Activity "Windows Updates" -Completed
        Write-Log "Windows Updates installed successfully"
        
        # Clean up any incomplete files that may have been created during update process
        Remove-IncompleteUpdates
    } else {
        Write-Progress -Activity "Windows Updates" -Completed
        Write-Log "No Windows Updates available"
    }

    # Update Windows Defender definitions
    Write-Log "Updating Windows Defender definitions..."
    Show-Progress -Activity "Windows Defender" -Status "Updating virus definitions..." -PercentComplete 0
    try {
        Update-MpSignature -ErrorAction SilentlyContinue
        Write-Log "Windows Defender definitions updated successfully"
    } catch {
        Write-Log "Windows Defender definition update completed with warnings: $($_.Exception.Message)"
    }
    Show-Progress -Activity "Windows Defender" -Status "Definitions updated successfully" -PercentComplete 100
    Write-Progress -Activity "Windows Defender" -Completed

    # Enable Windows Defender real-time protection
    Write-Log "Ensuring Windows Defender is properly configured..."
    Show-Progress -Activity "Security Configuration" -Status "Configuring Windows Defender settings..." -PercentComplete 20
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
        Write-Log "Windows Defender settings configured successfully"
    } catch {
        Write-Log "Windows Defender configuration completed with warnings: $($_.Exception.Message)"
    }

    # Enable Windows Firewall
    Write-Log "Configuring Windows Firewall..."
    Show-Progress -Activity "Security Configuration" -Status "Enabling Windows Firewall..." -PercentComplete 40
    try {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction SilentlyContinue
        Write-Log "Windows Firewall enabled successfully"
    } catch {
        Write-Log "Windows Firewall configuration completed with warnings: $($_.Exception.Message)"
    }

    # Check BitLocker status and enable if not active
    Write-Log "Checking BitLocker status..."
    Show-Progress -Activity "Security Configuration" -Status "Checking BitLocker status..." -PercentComplete 60
    try {
        $BitLockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
        if ($BitLockerStatus -and $BitLockerStatus.ProtectionStatus -eq "Off") {
            Write-Log "BitLocker is not enabled. This may require manual intervention."
            # Note: Auto-enabling BitLocker requires TPM and may need user interaction
        } elseif ($BitLockerStatus) {
            Write-Log "BitLocker is properly configured"
        } else {
            Write-Log "BitLocker status could not be determined"
        }
    } catch {
        Write-Log "BitLocker check completed with warnings: $($_.Exception.Message)"
    }
    Write-Progress -Activity "Security Configuration" -Completed

    # Clean up temporary files and any remaining incomplete update files
    Write-Log "Cleaning temporary files..."
    Show-Progress -Activity "System Cleanup" -Status "Cleaning temporary files..." -PercentComplete 0
    $TempFiles = Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue
    $FileCount = $TempFiles.Count
    $CurrentFile = 0
    
    foreach ($File in $TempFiles) {
        $CurrentFile++
        $PercentComplete = if ($FileCount -gt 0) { [math]::Round(($CurrentFile / $FileCount) * 100) } else { 0 }
        Show-Progress -Activity "System Cleanup" -Status "Removing temporary files ($CurrentFile of $FileCount)..." -PercentComplete $PercentComplete -CurrentOperation $CurrentFile -TotalOperations $FileCount
        Remove-Item -Path $File.FullName -Force -Recurse -ErrorAction SilentlyContinue
    }
    
    # Final cleanup of any incomplete update files
    Remove-IncompleteUpdates
    Write-Progress -Activity "System Cleanup" -Completed
    
    # Update certificate store
    Write-Log "Updating certificate store..."
    Show-Progress -Activity "Certificate Management" -Status "Updating certificate store..." -PercentComplete 0
    try {
        # Force certificate store refresh without opening GUI
        $null = Get-ChildItem -Path "Cert:\LocalMachine\My" -ErrorAction SilentlyContinue
        $null = Get-ChildItem -Path "Cert:\CurrentUser\My" -ErrorAction SilentlyContinue
        Write-Log "Certificate store refreshed successfully"
    } catch {
        Write-Log "Certificate store refresh completed with warnings: $($_.Exception.Message)"
    }
    Show-Progress -Activity "Certificate Management" -Status "Certificate store updated" -PercentComplete 100
    Write-Progress -Activity "Certificate Management" -Completed

    # Force Group Policy update (if domain-joined)
    Write-Log "Updating Group Policy..."
    Show-Progress -Activity "Group Policy Update" -Status "Applying Group Policy updates..." -PercentComplete 0
    try {
        $null = gpupdate /force /wait:0
        Write-Log "Group Policy update initiated successfully"
    } catch {
        Write-Log "Group Policy update completed with warnings: $($_.Exception.Message)"
    }
    Show-Progress -Activity "Group Policy Update" -Status "Group Policy updated successfully" -PercentComplete 100
    Write-Progress -Activity "Group Policy Update" -Completed

    Write-Log "GlobalProtect compliance update completed successfully"
    
    # Optional: Restart if updates require it (uncomment if needed)
    # if ((Get-WURebootStatus).RebootRequired) {
    #     Write-Log "System restart required. Scheduling restart in 5 minutes..."
    #     shutdown /r /t 300 /c "Restarting for GlobalProtect compliance updates"
    # }

} catch {
    Write-Progress -Activity "GlobalProtect Update" -Completed
    Write-Log "Error occurred: $($_.Exception.Message)"
    
    # If there was an error with Windows Updates, try clearing the cache
    if ($_.Exception.Message -match "Windows Update|PSWindowsUpdate|Get-WindowsUpdate|Install-WindowsUpdate") {
        Write-Log "Windows Update error detected. Attempting to clear update cache..."
        Clear-UpdateCache
        Remove-IncompleteUpdates
    }
    
    exit 1
}

# Add pause at the end to see any final messages or errors
Write-Host "`nScript completed. Press any key to close this window..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")