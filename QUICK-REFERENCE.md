# ClientTool PowerShell Module - Quick Reference

## 📊 MONITORING & STATUS

```powershell
Get-ClientToolStatus                  # Check if backup is running (Idle/Running)
Get-ClientToolApplicationStatus       # Detailed application status
Get-ClientToolSystemInfo              # RAM/CPU information (JSON)
Get-ClientToolSession                 # View backup/restore history
Get-ClientToolSessionError -DataSource FileSystem  # View session errors (datasource required)
Get-ClientToolInitializationError     # Check for startup errors
```

## 🗂️ SELECTION MANAGEMENT

```powershell
Get-ClientToolSelection               # List what's being backed up
Get-ClientToolSelection -DataSource FileSystem  # Filter by datasource

Set-ClientToolSelection -DataSource FileSystem -Include "C:\Data"
Set-ClientToolSelection -DataSource FileSystem -Include "C:\Data" -Exclude "C:\Data\Temp"
Set-ClientToolSelection -DataSource FileSystem -Include "C:\Important" -Priority High

Clear-ClientToolSelection             # Remove all selections (requires confirmation)
```

## ▶️ BACKUP OPERATIONS

```powershell
Start-ClientToolBackup                # Start backup for all datasources
Start-ClientToolBackup -DataSource FileSystem  # Start specific datasource
Start-ClientToolBackup -WhatIf        # Preview without executing

Start-ClientToolRestore               # Start restore operation
Stop-ClientToolSession                # Abort running backup/restore
```

## ⚙️ CONFIGURATION

```powershell
Get-ClientToolSetting                 # List application settings
Set-ClientToolSetting                 # Modify settings

Get-ClientToolSchedule                # View backup schedules
New-ClientToolSchedule                # Create new schedule
Set-ClientToolSchedule                # Modify existing schedule
Remove-ClientToolSchedule             # Delete schedule

Get-ClientToolFilter                  # View file filters
Set-ClientToolFilter                  # Modify filters
```

## 🗄️ DATABASE MANAGEMENT

### MySQL
```powershell
Get-ClientToolMySqlServer             # List MySQL servers
New-ClientToolMySqlServer             # Add MySQL server
Set-ClientToolMySqlServer             # Modify MySQL server
Remove-ClientToolMySqlServer          # Delete MySQL server
```

### Oracle
```powershell
Get-ClientToolOracleServer            # List Oracle servers
New-ClientToolOracleServer            # Add Oracle server
Set-ClientToolOracleServer            # Modify Oracle server
Remove-ClientToolOracleServer         # Delete Oracle server
```

## 🌐 NETWORK & SHARES

```powershell
Get-ClientToolNetworkShare            # List network share configs
New-ClientToolNetworkShare            # Add network share
Set-ClientToolNetworkShare            # Modify network share
Remove-ClientToolNetworkShare         # Delete network share
```

## 📋 SCRIPTS & ARCHIVING

### Scripts
```powershell
Get-ClientToolScript                  # List custom scripts
New-ClientToolScript                  # Add script
Set-ClientToolScript                  # Modify script
Remove-ClientToolScript               # Delete script
```

### Archiving Rules
```powershell
Get-ClientToolArchivingRule           # List archiving rules
New-ClientToolArchivingRule           # Add archiving rule
Set-ClientToolArchivingRule           # Modify archiving rule
Remove-ClientToolArchivingRule        # Delete archiving rule
```

## 🔧 UTILITY FUNCTIONS

```powershell
Open-ClientToolUI                     # Open Backup Manager UI in browser
Reset-ClientToolDashboardEmail        # Reset dashboard email subscription
Get-ClientToolAuthToken               # Get authentication token
Test-ClientToolPassword               # Validate password against requirements
Get-ClientToolPasswordRequirements    # View password requirements
Get-ClientToolPath                    # Show current ClientTool.exe path
Set-ClientToolPath -Path "D:\Path"    # Change ClientTool.exe path
```

## 🔐 HIDDEN/ADVANCED FUNCTIONS

**⚠️ Warning:** These are advanced functions that access hidden ClientTool commands. Use with caution!

### Connection & Testing
```powershell
Test-ClientToolConnection             # Test connection to management node
Test-ClientToolConnection -Account "user" -Password "pass"  # Test with auth

Test-ClientToolVSS                    # Check VSS availability
Test-ClientToolVSS -ShowPaths         # Show VSS snapshot components

Test-ClientToolVSSExchange            # Check VSS for Exchange Server
Test-ClientToolStorage                # Test storage and home nodes
```

### Encryption & Security
```powershell
Set-ClientToolEncryptionKey -EncryptionKey "key"  # Set encryption key
Set-ClientToolEncryptionKey -EncryptionKey "key" -ForceKey  # Force set key

Update-ClientToolMTLSCertificate      # Renew mTLS certificate
```

### Maintenance
```powershell
Clear-ClientToolLocalSpeedVault       # Clean LSV duplicate cabinets
Show-ClientToolProgressBar            # Display session progress
Stop-ClientToolApplication            # Shutdown Backup Manager
```

## 💡 TIPS & TRICKS

### Use -WhatIf for Safety
Preview changes before making them:
```powershell
Start-ClientToolBackup -DataSource FileSystem -WhatIf
Clear-ClientToolSelection -WhatIf
```

### Use -Verbose for Debugging
See the actual ClientTool.exe commands:
```powershell
Get-ClientToolSelection -Verbose
# Shows: Executing: C:\Program Files\Backup Manager\ClientTool.exe -machine-readable control.selection.list
```

### Pipeline Filtering
Filter and analyze results:
```powershell
# Get only completed sessions
Get-ClientToolSession | Where-Object { $_.STATE -eq 'Completed' }

# Count by datasource
Get-ClientToolSelection | Group-Object DSRC | Select-Object Name, Count

# Sessions from last 24 hours
Get-ClientToolSession | Where-Object { [datetime]$_.START -gt (Get-Date).AddHours(-24) }
```

### Export to Files
Save data for reporting:
```powershell
# Export sessions to CSV
Get-ClientToolSession | Export-Csv -Path sessions.csv -NoTypeInformation

# Export selections to JSON
Get-ClientToolSelection | ConvertTo-Json | Out-File selections.json

# Export settings to text
Get-ClientToolSetting | Out-File settings.txt
```

### Combine Multiple Operations
```powershell
# Get status and session count
$status = Get-ClientToolStatus
$sessionCount = (Get-ClientToolSession).Count
Write-Host "Status: $status | Sessions: $sessionCount"

# Check for failed backups
$failed = Get-ClientToolSession | Where-Object { $_.STATE -match 'Failed|Aborted' }
if ($failed) {
    Write-Warning "Found $($failed.Count) failed sessions"
    $failed | Format-Table DSRC, STATE, START, END
}
```

### Create Custom Reports
```powershell
# Backup health report
$report = [PSCustomObject]@{
    Status = Get-ClientToolStatus
    Selections = (Get-ClientToolSelection).Count
    TodaySessions = (Get-ClientToolSession | Where-Object { 
        [datetime]$_.START -gt (Get-Date).Date 
    }).Count
    ActiveSchedules = (Get-ClientToolSchedule | Where-Object { 
        $_.ACTV -eq 'yes' 
    }).Count
}
$report | Format-List
```

## 📖 DATASOURCE VALUES

When using `-DataSource` parameter, valid values are:

**For Selections & Backup:**
- `Exchange`
- `FileSystem`
- `MySql`
- `NetworkShares`
- `Oracle`
- `SystemState`
- `VMware`
- `VssHyperV`
- `VssMsSql`
- `VssSharePoint`

**For Sessions (includes restore datasources):**
- All of the above, plus:
- `BareMetalRestore`
- `VirtualDisasterRecovery`

## 🆘 GETTING HELP

```powershell
# Get help on any command
Get-Help Get-ClientToolSelection -Full
Get-Help Start-ClientToolBackup -Examples
Get-Help Set-ClientToolSelection -Parameter DataSource

# List all commands
Get-Command -Module ClientTool

# List commands by category
Get-Command -Module ClientTool -Name Get-*      # All Get commands
Get-Command -Module ClientTool -Name *Session*  # Session-related
Get-Command -Module ClientTool -Name *MySql*    # MySQL commands
```

## 🔗 COMMON WORKFLOWS

### Daily Monitoring
```powershell
# Import module
Import-Module ClientTool

# Check status
Get-ClientToolStatus

# Review recent sessions
Get-ClientToolSession | Select-Object -First 10 | Format-Table

# Check for errors
$errors = Get-ClientToolSessionError
if ($errors) { $errors | Format-Table }
```

### Adding New Backup Selections
```powershell
# Add folder to FileSystem backup
Set-ClientToolSelection -DataSource FileSystem -Include "C:\NewFolder"

# Add with exclusions
Set-ClientToolSelection -DataSource FileSystem `
    -Include "C:\Data" `
    -Exclude @("C:\Data\Temp", "C:\Data\Cache")

# Verify it was added
Get-ClientToolSelection -DataSource FileSystem
```

### Manual Backup Execution
```powershell
# Preview what would happen
Start-ClientToolBackup -DataSource FileSystem -WhatIf

# Start the backup
Start-ClientToolBackup -DataSource FileSystem

# Monitor status
Get-ClientToolStatus

# Check session when complete
Get-ClientToolSession | Select-Object -First 1
```

---

**Quick Reference Version:** 1.0.0  
**Last Updated:** November 14, 2025  
**For Full Documentation:** See README.md
