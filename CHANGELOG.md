# Changelog

All notable changes to the ClientTool PowerShell module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-18

### Added
- **Default Config Path Support**: Added default config path (`C:\Program Files\Backup Manager\config.ini`) to 6 functions:
  - `Get-ClientToolStatus`
  - `Get-ClientToolApplicationStatus`
  - `Get-ClientToolInitializationError`
  - `Open-ClientToolUI`
  - `Get-ClientToolAuthToken`
  - `Update-ClientToolMTLSCertificate`
- **Parameter Validation**: Added comprehensive parameter validation to archiving functions
  - `New-ClientToolArchivingRule`: Validates mutually exclusive parameters (-DaysOfMonth vs -DayOfWeek/-Weeks)
  - `Set-ClientToolArchivingRule`: Same validation with warnings for partial updates
  - Validates -DayOfWeek requires -Weeks parameter
- **Auto-Display Feature**: `New-ClientToolArchivingRule` now automatically displays created rules
  - Captures ID from success message
  - Retrieves and displays rule in table format
  - Shows success message in green
  - WhatIf compatible
- **Improved Help Context**: Enhanced user experience for mandatory parameters
  - `New-ClientToolArchivingRule`: Made -Name optional with helpful error messages
  - `New-ClientToolSchedule`: Made -Name optional with helpful error messages
  - `New-ClientToolScript`: Added parameter sets to allow -Syntax without prompts
- **Table Output Format**: Changed output from Format-List to Format-Table -AutoSize for better readability

### Fixed
- **Argument Construction Bug**: Fixed critical bug in argument passing to ClientTool.exe
  - Changed from embedded quotes in single string to proper List<string> array
  - Affects all functions with path parameters
  - Resolves issues with paths containing spaces

### Changed
- Updated `Get-ClientToolAuthToken` from Mandatory to optional parameter with default value
- Improved error messages and user feedback throughout archiving functions
- Enhanced comment-based help documentation

### Technical Details
- Module line count: 5194 lines
- Functions: 70+ commands
- ClientTool.exe version: v25.10.0.25296

## [1.0.0] - 2025-11-14

### Added
- Initial release of ClientTool PowerShell module
- Complete wrapper for N-able Cove Data Protection ClientTool.exe
- 70+ PowerShell functions covering all ClientTool operations
- Comprehensive comment-based help for all functions
- SupportsShouldProcess (WhatIf/Confirm support) for all modification commands
- Examples and documentation files:
  - README.md
  - QUICKSTART.md
  - QUICK-REFERENCE.md
  - CLIENTTOOL-COMMANDS.md
  - Examples.ps1
  - Install-Module.ps1

### Features by Category

#### General Functions
- `Get-ClientToolVersion`
- `Get-ClientToolStatus`
- `Get-ClientToolApplicationStatus`
- `Get-ClientToolInitializationError`
- `Open-ClientToolUI`
- `Get-ClientToolStatistics`
- `Get-ClientToolRecoveryTestingStatistics`

#### Backup Session Management
- `Get-ClientToolBackupSession`
- `Get-ClientToolSessionReport`
- `Get-ClientToolErrors`
- `Get-ClientToolFileError`
- `Get-ClientToolFileList`
- `Get-ClientToolDeletedFileList`

#### Archiving Operations
- `Get-ClientToolArchivingRule`
- `New-ClientToolArchivingRule`
- `Set-ClientToolArchivingRule`
- `Remove-ClientToolArchivingRule`

#### Scheduler Management
- `Get-ClientToolSchedule`
- `New-ClientToolSchedule`
- `Set-ClientToolSchedule`
- `Remove-ClientToolSchedule`

#### LSV (Local Speed Vault) Operations
- `Get-ClientToolLsvUsage`
- `Get-ClientToolLsvReplicationStatus`
- `Remove-ClientToolLsvReplication`

#### Server Management (MySQL, Oracle, Network Shares)
- `Get-ClientToolMySqlServer`
- `New-ClientToolMySqlServer`
- `Set-ClientToolMySqlServer`
- `Remove-ClientToolMySqlServer`
- `Get-ClientToolOracleServer`
- `New-ClientToolOracleServer`
- `Set-ClientToolOracleServer`
- `Remove-ClientToolOracleServer`
- `Get-ClientToolNetworkShare`
- `New-ClientToolNetworkShare`
- `Remove-ClientToolNetworkShare`

#### Script Management
- `Get-ClientToolScript`
- `New-ClientToolScript`
- `Remove-ClientToolScript`

#### Datasource Management
- `Get-ClientToolDatasource`
- `Add-ClientToolDatasource`
- `Remove-ClientToolDatasource`
- And many more datasource-specific functions

#### Filter Management
- `Get-ClientToolFilter`
- `Add-ClientToolFilter`
- `Remove-ClientToolFilter`

#### Plugin Management
- `Get-ClientToolPlugin`
- `Enable-ClientToolPlugin`
- `Disable-ClientToolPlugin`

#### Restore Operations
- `Start-ClientToolRestore`
- `Get-ClientToolRestoreList`
- `Get-ClientToolRecoveryTesting`

#### Security & Authentication
- `Get-ClientToolAuthToken`
- `Update-ClientToolMTLSCertificate`

#### Administrative Functions
- `Send-ClientToolInstallReport`
- `Send-ClientToolBackupStatus`
- `Get-ClientToolSessionLog`

## [Unreleased]

### Planned Features
- Auto-display feature for other New-* functions (schedules, servers, etc.)
- Extended parameter validation for schedule functions
- Integration tests
- Pester test suite
- CI/CD pipeline with GitHub Actions
- PowerShell Gallery publication

---

## Version History Summary

- **1.1.0** (2025-11-18): Default config paths, parameter validation, auto-display, bug fixes
- **1.0.0** (2025-11-14): Initial release with 70+ functions

## Contributing

See [PUBLISHING-GUIDE.md](PUBLISHING-GUIDE.md) for information on how to contribute to this project.

## Support

For issues, feature requests, or contributions, please visit:
https://github.com/BackupNerd/ClientTool/issues
