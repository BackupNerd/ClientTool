# ClientTool PowerShell Module - Quick Start Guide

## Getting Started in 3 Steps

### Step 1: Install the Module

```powershell
cd "C:\Script Root\0-Script Master\Modules\ClientTool"
.\Install-Module.ps1
```

### Step 2: Import the Module

```powershell
Import-Module ClientTool
```

### Step 3: Start Using It!

```powershell
# Check backup status
Get-ClientToolStatus

# View backup selections
Get-ClientToolSelection

# View recent sessions
Get-ClientToolSession
```

## Most Common Commands

### Monitoring
```powershell
Get-ClientToolStatus                    # Check if backup is running
Get-ClientToolSession                   # View session history
Get-ClientToolSession -DataSource FileSystem  # Filter by datasource
Get-ClientToolApplicationStatus         # Detailed app status
```

### Managing Selections
```powershell
Get-ClientToolSelection                 # List all selections
Get-ClientToolSelection -DataSource FileSystem  # List specific datasource

# Add a folder to backup
Set-ClientToolSelection -DataSource FileSystem -Include "C:\Data"

# Add with exclusions
Set-ClientToolSelection -DataSource FileSystem `
    -Include "C:\Users" `
    -Exclude "C:\Users\Public\Temp"

# Set priority
Set-ClientToolSelection -DataSource FileSystem `
    -Include "C:\CriticalData" `
    -Priority High
```

### Starting Backups
```powershell
Start-ClientToolBackup                  # Backup all datasources
Start-ClientToolBackup -DataSource FileSystem  # Backup specific datasource
Start-ClientToolBackup -WhatIf          # Preview what would happen
```

### Getting Information
```powershell
Get-ClientToolSystemInfo                # System RAM/CPU info
Get-ClientToolSetting                   # Application settings
Get-ClientToolSchedule                  # Configured schedules
Get-ClientToolSessionError              # View session errors
```

## Tips

### Use Get-Help
Every command has detailed help:
```powershell
Get-Help Get-ClientToolSelection -Full
Get-Help Start-ClientToolBackup -Examples
```

### Use -WhatIf
Preview changes before making them:
```powershell
Start-ClientToolBackup -DataSource FileSystem -WhatIf
Clear-ClientToolSelection -WhatIf
```

### Pipeline Support
Filter and export results:
```powershell
# Export sessions to CSV
Get-ClientToolSession | Export-Csv sessions.csv

# Count selections
(Get-ClientToolSelection).Count

# Filter by datasource
Get-ClientToolSession | Where-Object { $_.DSRC -eq 'FileSystem' }
```

### View All Commands
```powershell
Get-Command -Module ClientTool
Get-Command -Module ClientTool -Name *Session*
Get-Command -Module ClientTool -Name Get-*
```

## Folder Structure

```
ClientTool/
├── ClientTool.psm1        # Main module file
├── ClientTool.psd1        # Module manifest
├── README.md              # Full documentation
├── QUICKSTART.md          # This file
├── Examples.ps1           # Example script
└── Install-Module.ps1     # Installation script
```

## Getting Help

- **Full Documentation**: See README.md
- **Examples**: Run Examples.ps1
- **Command Help**: `Get-Help <CommandName> -Full`
- **List Commands**: `Get-Command -Module ClientTool`

## Need More?

Check out `Examples.ps1` for working code samples:
```powershell
cd "C:\Script Root\0-Script Master\Modules\ClientTool"
.\Examples.ps1
```

---

**Module Version**: 1.0.0  
**Author**: BackupNerd  
**Date**: November 14, 2025
