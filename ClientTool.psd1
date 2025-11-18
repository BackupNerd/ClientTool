@{
    # Module manifest for module 'ClientTool'
    ModuleVersion = '1.1.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'BackupNerd'
    CompanyName = 'N-able'
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'PowerShell module wrapper for N-able Backup Manager ClientTool.exe. Provides cmdlets to manage backup selections, sessions, schedules, and more. Compatible with ClientTool version 25.10.0.25296 and later.'
    PowerShellVersion = '5.1'
    
    # Module to process
    RootModule = 'ClientTool.psm1'
    
    # Functions to export
    FunctionsToExport = @(
        # Backup/Restore
        'Start-ClientToolBackup',
        'Start-ClientToolRestore',
        
        # Status
        'Get-ClientToolStatus',
        'Get-ClientToolApplicationStatus',
        'Get-ClientToolSystemInfo',
        'Get-ClientToolInitializationError',
        
        # Selections
        'Get-ClientToolSelection',
        'Set-ClientToolSelection',
        'Clear-ClientToolSelection',
        
        # Sessions
        'Get-ClientToolSession',
        'Get-ClientToolSessionError',
        'Get-ClientToolSessionNode',
        'Export-ClientToolSessionNode',
        'Stop-ClientToolSession',
        
        # Settings
        'Get-ClientToolSetting',
        'Set-ClientToolSetting',
        
        # Schedules
        'Get-ClientToolSchedule',
        'New-ClientToolSchedule',
        'Set-ClientToolSchedule',
        'Remove-ClientToolSchedule',
        
        # MySQL
        'Get-ClientToolMySqlServer',
        'New-ClientToolMySqlServer',
        'Set-ClientToolMySqlServer',
        'Remove-ClientToolMySqlServer',
        
        # Oracle
        'Get-ClientToolOracleServer',
        'New-ClientToolOracleServer',
        'Set-ClientToolOracleServer',
        'Remove-ClientToolOracleServer',
        
        # Network Shares
        'Get-ClientToolNetworkShare',
        'New-ClientToolNetworkShare',
        'Set-ClientToolNetworkShare',
        'Remove-ClientToolNetworkShare',
        
        # Filters
        'Get-ClientToolFilter',
        'Set-ClientToolFilter',
        
        # Scripts
        'Get-ClientToolScript',
        'New-ClientToolScript',
        'Set-ClientToolScript',
        'Remove-ClientToolScript',
        
        # Archiving
        'Get-ClientToolArchivingRule',
        'New-ClientToolArchivingRule',
        'Set-ClientToolArchivingRule',
        'Remove-ClientToolArchivingRule',
        
        # Miscellaneous
        'Open-ClientToolUI',
        'Reset-ClientToolDashboardEmail',
        'Get-ClientToolAuthToken',
        'Test-ClientToolPassword',
        'Get-ClientToolPasswordRequirements',
        'Set-ClientToolPath',
        'Get-ClientToolPath',
        
        # Hidden/Advanced Commands
        'Stop-ClientToolApplication',
        'Test-ClientToolConnection',
        'Test-ClientToolVSS',
        'Test-ClientToolVSSExchange',
        'Set-ClientToolEncryptionKey',
        'Clear-ClientToolLocalSpeedVault',
        'Test-ClientToolStorage',
        'Show-ClientToolProgressBar',
        'Update-ClientToolMTLSCertificate'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Backup', 'N-able', 'Cove', 'BackupManager', 'ClientTool')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = @'
Version 1.1.0 (November 18, 2025)
- Added -Syntax parameter to all 56 command functions for inline help
- Enhanced PowerShell help with OUTPUTS and NOTES sections for 46 functions
- Added -HiddenCommand support for advanced/hidden ClientTool commands
- Improved Test-ClientTool* functions with colored output
- Optimized Test-ClientToolStorage with in-memory processing
- Compatible with N-able Backup Manager ClientTool version 25.10.0.25296
'@
        }
        
        # ClientTool compatibility
        ClientToolVersion = @{
            Minimum = '25.10.0'
            Tested = '25.10.0.25296'
            Build = 'd3c81ad250-14182'
        }
    }
}
