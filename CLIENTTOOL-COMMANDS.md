# ClientTool.exe Command Reference

This document provides detailed information about the underlying ClientTool.exe commands that the PowerShell module wraps.

**Note:** Most users should use the PowerShell cmdlets instead of calling ClientTool.exe directly. This reference is provided for advanced scenarios and troubleshooting.

---

## Global Arguments

Available for all commands:

- `-machine-readable` - Produce output in machine-readable format
- `-non-interactive` - Do not ask questions (if any)
- `-version` - Print program version and exit

---

## Backup & Restore Operations

### control.backup.start
Start backup. If no datasource specified, starts backup for all datasources.

**Optional Arguments:**
- `-datasource <NAME>` - Datasource to backup (Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint)

**PowerShell Equivalent:**
```powershell
Start-ClientToolBackup [-DataSource <string>]
```

### control.restore.start
Start restore operation.

**PowerShell Equivalent:**
```powershell
Start-ClientToolRestore
```

---

## Selection Management

### control.selection.list
List backup selections.

**Optional Arguments:**
- `-datasource <NAME>` - Filter by datasource
- `-delimiter <STRING>` - Field delimiter (default: TAB)
- `-no-header` - Exclude header row

**Output Columns:** DSRC, TYPE, PRIO, PATH

**PowerShell Equivalent:**
```powershell
Get-ClientToolSelection [-DataSource <string>]
```

### control.selection.modify
Modify backup selections.

**Required Arguments:**
- `-datasource <NAME>` - Datasource to modify

**Optional Arguments:**
- `-include <PATH>` - Path to include (can be used multiple times)
- `-exclude <PATH>` - Path to exclude (can be used multiple times)
- `-priority <NAME>` - Priority: Low, Normal, or High (default: Normal)

**Examples:**
```
ClientTool.exe control.selection.modify -datasource FileSystem -include C:\dir1 -exclude C:\dir1\dir2
ClientTool.exe control.selection.modify -datasource FileSystem -include C:\dir1\file1 -priority High
ClientTool.exe control.selection.modify -datasource MySql -include SqlServer
```

**PowerShell Equivalent:**
```powershell
Set-ClientToolSelection -DataSource <string> [-Include <string[]>] [-Exclude <string[]>] [-Priority <string>]
```

### control.selection.clear
Clear all backup selections.

**PowerShell Equivalent:**
```powershell
Clear-ClientToolSelection
```

---

## Session Management

### control.session.list
List backup and restore sessions.

**Optional Arguments:**
- `-datasource <NAME>` - Filter by datasource (includes BareMetalRestore, VirtualDisasterRecovery)
- `-delimiter <STRING>` - Field delimiter (default: TAB)
- `-no-header` - Exclude header row

**Output Columns:** DSRC, TYPE, STATE, FLAGS, START, END, SELS, SELC, PROCS, PROCC, SENTS, ERRC, REMC

**Session Flags:**
- `A` - Archived

**PowerShell Equivalent:**
```powershell
Get-ClientToolSession [-DataSource <string>]
```

### control.session.error.list
List session errors.

**PowerShell Equivalent:**
```powershell
Get-ClientToolSessionError
```

### control.session.node.list
List session nodes.

**PowerShell Equivalent:**
```powershell
Get-ClientToolSessionNode
```

### control.session.node.export
Export session nodes to file.

**PowerShell Equivalent:**
```powershell
Export-ClientToolSessionNode -Path <string>
```

### control.session.abort
Abort running backup or restore session.

**PowerShell Equivalent:**
```powershell
Stop-ClientToolSession
```

---

## Schedule Management

### control.schedule.list
List existing schedules.

**PowerShell Equivalent:**
```powershell
Get-ClientToolSchedule
```

### control.schedule.add
Create new schedule.

**Required Arguments:**
- `-name <STRING>` - Schedule name (non-empty)

**Optional Arguments:**
- `-active <BOOL>` - Active status: 0 (inactive) or 1 (active). Default: 1
- `-datasources <NAME1,NAME2,...>` - Comma-separated datasources or "All". Default: All
- `-days <DAY1,DAY2,...>` - Comma-separated days or "All". Values: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday. Default: All
- `-time <TIME>` - Schedule time in hh:mm format. Default: 00:00
- `-pre-backup-action <NUMBER>` - Pre-backup script ID
- `-post-backup-action <NUMBER>` - Post-backup script ID

**Example:**
```
ClientTool.exe control.schedule.add -name "Daily Backup" -time 02:00 -days Monday,Tuesday,Wednesday,Thursday,Friday -datasources FileSystem,NetworkShares
```

**PowerShell Equivalent:**
```powershell
New-ClientToolSchedule # (requires parameter implementation)
```

### control.schedule.modify
Modify existing schedule.

**Arguments:** Same as control.schedule.add

**PowerShell Equivalent:**
```powershell
Set-ClientToolSchedule # (requires parameter implementation)
```

### control.schedule.remove
Remove existing schedule.

**PowerShell Equivalent:**
```powershell
Remove-ClientToolSchedule # (requires parameter implementation)
```

---

## Settings Management

### control.setting.list
List application settings.

**PowerShell Equivalent:**
```powershell
Get-ClientToolSetting
```

### control.setting.modify
Modify application settings.

**Required Arguments:**
- `-name <STRING>` - Setting name (can be used multiple times)
- `-value <STRING>` - Setting value (one for each name)

**Example:**
```
ClientTool.exe control.setting.modify -name Language -value en -name MailSendPeriodicity -value 0
```

**PowerShell Equivalent:**
```powershell
Set-ClientToolSetting # (requires parameter implementation)
```

---

## Filter Management

### control.filter.list
List FileSystem datasource filters.

**PowerShell Equivalent:**
```powershell
Get-ClientToolFilter
```

### control.filter.modify
Modify filters for FileSystem datasource.

**Optional Arguments:**
- `-add <MASK>` - Filter mask to add (can be used multiple times)
- `-remove <MASK>` - Filter mask to remove (can be used multiple times)

**Example:**
```
ClientTool.exe control.filter.modify -add "*.txt" -add "*.docx" -remove "*.mp3"
```

**PowerShell Equivalent:**
```powershell
Set-ClientToolFilter # (requires parameter implementation)
```

---

## Network Share Management

### control.networkshare.list
List network share entries.

**PowerShell Equivalent:**
```powershell
Get-ClientToolNetworkShare
```

### control.networkshare.add
Create new network share entry.

**Required Arguments:**
- `-path <STRING>` - Network share path (non-empty)
- `-user <STRING>` - Username for connection
- `-domain <STRING>` - Domain for connection

**Optional Arguments:**
- `-password <STRING>` - Password for connection

**Example:**
```
ClientTool.exe control.networkshare.add -path "\\server\share" -user "username" -domain "DOMAIN" -password "password"
```

**PowerShell Equivalent:**
```powershell
New-ClientToolNetworkShare # (requires parameter implementation)
```

### control.networkshare.modify
Modify existing network share entry.

**Arguments:** Same as control.networkshare.add

**PowerShell Equivalent:**
```powershell
Set-ClientToolNetworkShare # (requires parameter implementation)
```

### control.networkshare.remove
Remove network share entry.

**PowerShell Equivalent:**
```powershell
Remove-ClientToolNetworkShare # (requires parameter implementation)
```

---

## MySQL Database Management

### control.mysqldb.list
List MySQL server entries.

**PowerShell Equivalent:**
```powershell
Get-ClientToolMySqlServer
```

### control.mysqldb.add
Create new MySQL server entry.

**PowerShell Equivalent:**
```powershell
New-ClientToolMySqlServer # (requires parameter implementation)
```

### control.mysqldb.modify
Modify existing MySQL server entry.

**PowerShell Equivalent:**
```powershell
Set-ClientToolMySqlServer # (requires parameter implementation)
```

### control.mysqldb.remove
Remove MySQL server entry.

**PowerShell Equivalent:**
```powershell
Remove-ClientToolMySqlServer # (requires parameter implementation)
```

---

## Oracle Database Management

### control.oracledb.list
List Oracle server entries.

**PowerShell Equivalent:**
```powershell
Get-ClientToolOracleServer
```

### control.oracledb.add
Create new Oracle server entry.

**PowerShell Equivalent:**
```powershell
New-ClientToolOracleServer # (requires parameter implementation)
```

### control.oracledb.modify
Modify existing Oracle server entry.

**PowerShell Equivalent:**
```powershell
Set-ClientToolOracleServer # (requires parameter implementation)
```

### control.oracledb.remove
Remove Oracle server entry.

**PowerShell Equivalent:**
```powershell
Remove-ClientToolOracleServer # (requires parameter implementation)
```

---

## Script Management

### control.script.list
List custom scripts.

**PowerShell Equivalent:**
```powershell
Get-ClientToolScript
```

### control.script.add
Create new script.

**PowerShell Equivalent:**
```powershell
New-ClientToolScript # (requires parameter implementation)
```

### control.script.modify
Modify existing script.

**PowerShell Equivalent:**
```powershell
Set-ClientToolScript # (requires parameter implementation)
```

### control.script.remove
Remove script.

**PowerShell Equivalent:**
```powershell
Remove-ClientToolScript # (requires parameter implementation)
```

---

## Archiving Management

### control.archiving.list
List archiving rules.

**PowerShell Equivalent:**
```powershell
Get-ClientToolArchivingRule
```

### control.archiving.add
Create new archiving rule.

**PowerShell Equivalent:**
```powershell
New-ClientToolArchivingRule # (requires parameter implementation)
```

### control.archiving.modify
Modify existing archiving rule.

**PowerShell Equivalent:**
```powershell
Set-ClientToolArchivingRule # (requires parameter implementation)
```

### control.archiving.remove
Remove archiving rule.

**PowerShell Equivalent:**
```powershell
Remove-ClientToolArchivingRule # (requires parameter implementation)
```

---

## Status & Information

### control.status.get
Print current program status (Idle/Running).

**PowerShell Equivalent:**
```powershell
Get-ClientToolStatus
```

### control.application-status.get
Print detailed application status.

**PowerShell Equivalent:**
```powershell
Get-ClientToolApplicationStatus
```

### system-info.get
Get system information (RAM/CPU) in JSON format.

**PowerShell Equivalent:**
```powershell
Get-ClientToolSystemInfo
```

### control.initialization-error.get
Get application initialization errors in JSON format.

**PowerShell Equivalent:**
```powershell
Get-ClientToolInitializationError
```

---

## Miscellaneous

### bm-ui.open
Open Backup Manager UI in default browser.

**PowerShell Equivalent:**
```powershell
Open-ClientToolUI
```

### control.dashboard.unsubscribe
Reset dashboard email subscription.

**PowerShell Equivalent:**
```powershell
Reset-ClientToolDashboardEmail
```

### in-agent-authentication-token.get
Get InAgent authentication token for BackupFP API.

**PowerShell Equivalent:**
```powershell
Get-ClientToolAuthToken
```

### password.requirements.get
Get password requirements.

**PowerShell Equivalent:**
```powershell
Get-ClientToolPasswordRequirements
```

### password.requirements.check
Check if password meets requirements.

**PowerShell Equivalent:**
```powershell
```powershell
Test-ClientToolPassword -Password <string>
```

---

## Hidden/Advanced Commands

**⚠️ Warning:** These commands are hidden and meant for advanced scenarios. They require the `-h` flag with the help command:
```
ClientTool.exe help -h -command <command.name>
```

### control.shutdown
Closes the Backup Manager application.

**PowerShell Equivalent:**
```powershell
Stop-ClientToolApplication
```

### connection.check
Check connection to management node.

**Optional Arguments:**
- `-account <STRING>` - Account name for authentication
- `-password <STRING>` - Password for authentication  
- `-use-proxy <BOOL>` - Enable proxy (0 or 1)
- `-proxy-address <STRING>` - Proxy server address
- `-proxy-port <NUMBER>` - Proxy server port
- `-proxy-type <PROTOCOL>` - Proxy protocol type
- `-proxy-username <STRING>` - Proxy username
- `-proxy-password <STRING>` - Proxy password
- `-use-proxy-authorization <BOOL>` - Enable proxy auth (0 or 1)

**PowerShell Equivalent:**
```powershell
Test-ClientToolConnection [-Account <string>] [-Password <string>] [-ProxyAddress <string>] ...
```

### vss.check
Checks if VSS (Volume Shadow Copy Service) is available for use.

**Optional Arguments:**
- `-resolve` - Resolve Exchange write issues
- `-showpaths` - Show components included in snapshot

**PowerShell Equivalent:**
```powershell
Test-ClientToolVSS [-Resolve] [-ShowPaths]
```

### vss.exchange.check
Checks if VSS is available for Exchange Server.

**Optional Arguments:**
- `-resolve` - Resolve Exchange write issues
- `-showpaths` - Show components included in snapshot

**PowerShell Equivalent:**
```powershell
Test-ClientToolVSSExchange [-Resolve] [-ShowPaths]
```

### encryption-key.set
Sets data encryption key for the current device.

**Required Arguments:**
- `-encryption-key <STRING>` - Encryption key to use

**Optional Arguments:**
- `-force-key` - Use key even if contract is already in use

**Example:**
```
ClientTool.exe encryption-key.set -encryption-key "MySecureKey123"
```

**PowerShell Equivalent:**
```powershell
Set-ClientToolEncryptionKey -EncryptionKey <string> [-ForceKey]
```

### lsv.clean
Clean Local Speed Vault of duplicate cabinets.

**PowerShell Equivalent:**
```powershell
Clear-ClientToolLocalSpeedVault
```

### storage.test
Tests home and storage nodes connectivity and functionality.

**PowerShell Equivalent:**
```powershell
Test-ClientToolStorage
```

### show.progress-bar
Show progress bar for in-progress session.

**PowerShell Equivalent:**
```powershell
Show-ClientToolProgressBar
```

### mtls.certificate.renew
Renew mTLS (mutual TLS) certificate.

**PowerShell Equivalent:**
```powershell
Update-ClientToolMTLSCertificate
```

### Other Hidden Commands

The following hidden commands are also available but may not have PowerShell wrappers:

- `branded-appdata.migrate` - Migrate app data if branding changed
- `enable.write.cache` - Enable write cache for a drive
- `file.move.pending` - Create pending move on restart
- `install.device.is-configured` - Check if device is configured
- `install.encryption-key.is-configured` - Check if encryption key configured
- `install.encryption-key.request` - Request encryption key
- `install.encryption-key.set` - Set encryption key during install
- `install.wizard.disable` - Disable interactive configuration wizard
- `installation.redeem` - Create device with installation token
- `notify.vd.update` - Create Virtual Drive update notification
- `notify.vmware-vddk.require-reboot` - Create reboot required notification
- `previous-product-config-ini.migrate` - Migrate config.ini
- `rc.dashboards.unsubscribe` - Unsubscribe from Recovery Console dashboards
- `scramble` - Scramble string data
- `shutdown` - Close Backup Manager (alternative to control.shutdown)
- `status.get` - Get status (alternative to control.status.get)
- `takeover` - Move account to different partner
- `versions.compare` - Compare version numbers

---

## Discovering Hidden Commands

To view all commands including hidden ones:
```
ClientTool.exe help -h
```

To get help on a specific hidden command:
```
ClientTool.exe help -h -command <command.name>
```

---
```

### help
Print help information.

**Usage:**
```
ClientTool.exe help
ClientTool.exe help -command <command.name>
```

---

## Getting Detailed Help

To get detailed help for any command:

```powershell
# From PowerShell
& "C:\Program Files\Backup Manager\ClientTool.exe" help -command control.selection.modify

# From CMD
"C:\Program Files\Backup Manager\ClientTool.exe" help -command control.selection.modify
```

---

## Notes

1. **Parameter Implementation**: Some PowerShell cmdlets are framework stubs awaiting parameter implementation. Use the ClientTool.exe help command to determine the exact arguments needed.

2. **Multiple Commands**: ClientTool.exe supports running multiple commands at once:
   ```
   ClientTool.exe control.status.get control.selection.list
   ```

3. **Machine-Readable Output**: Use `-machine-readable` for scripting:
   ```
   ClientTool.exe -machine-readable control.session.list
   ```

4. **Non-Interactive Mode**: Use `-non-interactive` for automation:
   ```
   ClientTool.exe -non-interactive control.backup.start
   ```

---

**Last Updated:** November 14, 2025  
**ClientTool Version:** 25.10.0.25296  
**For PowerShell Module Documentation:** See README.md, QUICKSTART.md, or QUICK-REFERENCE.md
