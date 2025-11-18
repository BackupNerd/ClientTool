# Installation Guide

## Install from GitHub

### Method 1: Direct Install (Recommended)

```powershell
# Install for current user
Install-Module -Name ClientTool -Repository PSGallery -Scope CurrentUser

# Or install from GitHub directly
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
New-Item -ItemType Directory -Path $modulePath -Force
Invoke-WebRequest -Uri "https://github.com/BackupNerd/ClientTool/archive/refs/heads/main.zip" -OutFile "$env:TEMP\ClientTool.zip"
Expand-Archive -Path "$env:TEMP\ClientTool.zip" -DestinationPath "$env:TEMP\ClientTool" -Force
Copy-Item -Path "$env:TEMP\ClientTool\ClientTool-main\*" -Destination $modulePath -Recurse -Force
Remove-Item -Path "$env:TEMP\ClientTool.zip", "$env:TEMP\ClientTool" -Recurse -Force
```

### Method 2: Git Clone (For Development)

```powershell
# Clone the repository
git clone https://github.com/BackupNerd/ClientTool.git

# Copy to PowerShell modules directory
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
Copy-Item -Path ".\ClientTool\*" -Destination $modulePath -Recurse -Force
```

### Method 3: Manual Download

1. Download the latest release from: https://github.com/BackupNerd/ClientTool/releases
2. Extract the ZIP file
3. Copy the `ClientTool` folder to one of these locations:
   - **Current User:** `$env:USERPROFILE\Documents\PowerShell\Modules\`
   - **All Users:** `C:\Program Files\PowerShell\Modules\`
   - **Windows PowerShell:** `$env:USERPROFILE\Documents\WindowsPowerShell\Modules\`

## Verify Installation

```powershell
# Import the module
Import-Module ClientTool

# Check module info
Get-Module ClientTool

# List available commands
Get-Command -Module ClientTool

# Get help for a command
Get-Help Get-ClientToolStatus -Full
```

## Prerequisites

- **PowerShell 5.1** or higher (PowerShell 7+ recommended)
- **Backup Manager ClientTool.exe** installed at: `C:\Program Files\Backup Manager\ClientTool.exe`
- **Administrator privileges** may be required for some operations

## Quick Start

```powershell
# Import the module
Import-Module ClientTool

# Get backup status
Get-ClientToolStatus

# List all backup sessions
Get-ClientToolBackupSession

# Get archiving rules
Get-ClientToolArchivingRule

# Create a new archiving rule
New-ClientToolArchivingRule -Name "Weekly-Friday-Backup" -DayOfWeek Friday -Weeks All -Time "23:00"
```

## Updating

### From GitHub

```powershell
# Re-run the installation command
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
Remove-Item -Path $modulePath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $modulePath -Force
Invoke-WebRequest -Uri "https://github.com/BackupNerd/ClientTool/archive/refs/heads/main.zip" -OutFile "$env:TEMP\ClientTool.zip"
Expand-Archive -Path "$env:TEMP\ClientTool.zip" -DestinationPath "$env:TEMP\ClientTool" -Force
Copy-Item -Path "$env:TEMP\ClientTool\ClientTool-main\*" -Destination $modulePath -Recurse -Force
Remove-Item -Path "$env:TEMP\ClientTool.zip", "$env:TEMP\ClientTool" -Recurse -Force
```

## Uninstallation

```powershell
# Remove the module
Remove-Module ClientTool -Force -ErrorAction SilentlyContinue

# Delete module files
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
Remove-Item -Path $modulePath -Recurse -Force
```

## Troubleshooting

### Module not found after installation

```powershell
# Check PowerShell module paths
$env:PSModulePath -split ';'

# Verify module is in one of these paths
Get-ChildItem "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
```

### Import-Module fails

```powershell
# Check execution policy
Get-ExecutionPolicy

# Set execution policy if needed (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ClientTool.exe not found

```powershell
# Verify ClientTool.exe exists
Test-Path "C:\Program Files\Backup Manager\ClientTool.exe"

# If using custom path, specify it in commands
Get-ClientToolStatus -Path "C:\Custom\Path\config.ini"
```

## Support

For issues, feature requests, or contributions:
- **GitHub Issues:** https://github.com/BackupNerd/ClientTool/issues
- **Documentation:** See [README.md](README.md) and [QUICKSTART.md](QUICKSTART.md)
