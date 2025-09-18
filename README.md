# GlobalProtect Compliance Update Script

This repository contains an automated PowerShell script for maintaining GlobalProtect compliance by updating Windows systems, security configurations, and system components.

## Setup Instructions

1. **Clone the repository to ~/Scripts**
   ```bash
   git clone <repository-url> ~/Scripts
   ```

2. **Open PowerShell with Administrator permissions**
   - Right-click on PowerShell and select "Run as Administrator"
   - Navigate to the scripts directory: `cd ~/Scripts`

3. **Run the update script**
   ```bash
   .\run_update.bat
   ```

## What the Script Does

The script automatically performs the following operations:

- **Windows Updates**: Checks for and installs available Windows Updates
- **Security Updates**: Updates Windows Defender virus definitions
- **Security Configuration**: 
  - Enables Windows Defender real-time protection
  - Configures Windows Firewall
  - Checks BitLocker status
- **System Cleanup**: Removes temporary files and incomplete update files
- **Certificate Management**: Refreshes certificate stores
- **Group Policy**: Forces Group Policy updates (if domain-joined)

## Features

- **Fully Automated**: No user interaction required
- **Comprehensive Logging**: All operations are logged with timestamps
- **Progress Tracking**: Visual progress indicators for long-running operations
- **Error Handling**: Graceful handling of errors with detailed logging
- **Scheduled Execution**: Designed to run daily between 4-6 AM

## Log Files

Log files are automatically created in `~/Logs/` with the format:
`GlobalProtect-Update-YYYY-MM-DD.log`

## Requirements

- Windows PowerShell 5.1 or later
- Administrator privileges
- Internet connection (for updates and module installation)

## Notes

- The script will automatically install the required PSWindowsUpdate module if not present
- All operations are performed silently without user prompts
- The script is designed for enterprise environments with GlobalProtect compliance requirements
