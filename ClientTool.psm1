#Requires -Version 5.1

<#
.SYNOPSIS
    PowerShell module wrapper for N-able Backup Manager ClientTool.exe
.DESCRIPTION
    This module provides PowerShell cmdlets that wrap the ClientTool.exe command-line interface
    for N-able Backup Manager (formerly Cove Data Protection).
    Features:
    - 56 command functions with -Syntax parameter for inline help
    - Enhanced PowerShell comment-based help with OUTPUTS and NOTES sections
    - Support for hidden/advanced ClientTool commands
    - Colored output for diagnostic functions
    - Pipeline-friendly object output
.NOTES
    Author: BackupNerd
    Date: November 18, 2025
    Version: 1.1.0
    Compatible with: N-able Backup Manager ClientTool version 25.10.0.25296
#>

#region Module Variables

$script:ClientToolPath = "C:\Program Files\Backup Manager\ClientTool.exe"
$script:DefaultDelimiter = "`t"

#endregion

#region Helper Functions

function Invoke-ClientTool {
    <#
    .SYNOPSIS
        Internal helper function to invoke ClientTool.exe with proper error handling
    .DESCRIPTION
        Executes ClientTool.exe commands with standardized error handling and output processing.
        Handles global arguments, command construction, and exit code validation.
    .PARAMETER Command
        The ClientTool command to execute (e.g., 'control.backup.start')
    .PARAMETER Arguments
        Array of command-specific arguments to pass to ClientTool
    .PARAMETER MachineReadable
        Enable machine-readable output format (adds -machine-readable flag)
    .PARAMETER NonInteractive
        Disable interactive prompts (adds -non-interactive flag)
    .PARAMETER ShowSyntax
        Display command syntax help instead of executing
    .PARAMETER HiddenCommand
        Indicates this is a hidden/advanced command (uses different help syntax)
    .OUTPUTS
        String[]
        Returns the command output as an array of strings, or $null if command fails
    .NOTES
        Internal Module Function
        
        This is a core helper function used by all public cmdlets to execute ClientTool.exe.
        Handles exit code validation and provides consistent error reporting across the module.
    
    .EXAMPLE
        Invoke-ClientTool -Command 'control.status.get' -MachineReadable
        Executes a command with machine-readable output
    
    .EXAMPLE
        Invoke-ClientTool -Command 'control.backup.start' -Arguments @('-datasource', 'FileSystem')
        Executes a command with additional arguments
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Command,
        [Parameter()] [string[]]$Arguments,
        [Parameter()] [switch]$MachineReadable,
        [Parameter()] [switch]$NonInteractive,
        [Parameter()] [switch]$ShowSyntax,
        [Parameter()] [switch]$HiddenCommand
    )
    
    if (-not (Test-Path $script:ClientToolPath)) {
        throw "ClientTool.exe not found at: $script:ClientToolPath"
    }
    
    # If ShowSyntax is requested, display help and return
    if ($ShowSyntax) {
        if ($HiddenCommand) {
            & $script:ClientToolPath 'help' '-command' $Command '-h'
        } else {
            & $script:ClientToolPath 'help' '-command' $Command
        }
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    # Add global arguments
    if ($MachineReadable) { $argList.Add('-machine-readable') }
    if ($NonInteractive) { $argList.Add('-non-interactive') }
    
    # Add command
    $argList.Add($Command)
    
    # Add command arguments
    if ($Arguments) {
        $argList.AddRange($Arguments)
    }
    
    Write-Verbose "Executing: $script:ClientToolPath $($argList -join ' ')"
    
    try {
        $output = & $script:ClientToolPath @argList 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = $output | Out-String
            Write-Error "ClientTool command failed (Exit Code: $LASTEXITCODE): $errorMessage"
            return $null
        }
        
        return $output
    }
    catch {
        throw "Failed to execute ClientTool: $_"
    }
}

function ConvertFrom-ClientToolTable {
    <#
    .SYNOPSIS
        Converts tab-delimited ClientTool output to PowerShell objects
    .DESCRIPTION
        Parses ClientTool's machine-readable table output into PSCustomObjects.
        Automatically handles header parsing, skips version/copyright lines, and creates
        objects with properties matching the column headers.
    .PARAMETER InputText
        Array of strings containing the tab-delimited output from ClientTool
    .PARAMETER Delimiter
        Field delimiter used in the input (default: TAB character)
    .OUTPUTS
        PSCustomObject
        Returns objects with properties corresponding to the table columns
    .NOTES
        Internal Module Function
        
        This helper function is used throughout the module to convert ClientTool's
        tab-delimited output into PowerShell-friendly objects for pipeline processing.
    
    .EXAMPLE
        $output | ConvertFrom-ClientToolTable
        Converts tab-delimited output to PowerShell objects
    
    .EXAMPLE
        $output | ConvertFrom-ClientToolTable -Delimiter ','
        Converts comma-delimited output to objects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [string[]]$InputText,
        [Parameter()] [string]$Delimiter = "`t"
    )
    
    begin {
        $headers = $null
        $lineNumber = 0
    }
    
    process {
        foreach ($line in $InputText) {
            $lineNumber++
            
            # Skip version/copyright lines
            if ($line -match 'Client Tool, version|Copyright|All rights reserved') {
                continue
            }
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            # First non-empty line is headers
            if (-not $headers) {
                $headers = $line -split [regex]::Escape($Delimiter)
                continue
            }
            
            # Parse data rows
            $values = $line -split [regex]::Escape($Delimiter)
            
            if ($values.Count -eq $headers.Count) {
                $obj = [PSCustomObject]@{}
                for ($i = 0; $i -lt $headers.Count; $i++) {
                    $obj | Add-Member -NotePropertyName $headers[$i].Trim() -NotePropertyValue $values[$i].Trim()
                }
                Write-Output $obj
            }
        }
    }
}

function Invoke-RemoveWithPrompt {
    <#
    .SYNOPSIS
        Helper function to consolidate Remove-* function logic
    .DESCRIPTION
        Provides common logic for all Remove-* functions in the module.
        Handles interactive listing, ID validation, user prompts, and ShouldProcess confirmation.
        When no identifier is provided, displays available items and prompts for selection.
    .PARAMETER Command
        The ClientTool command to execute (e.g., 'control.schedule.delete')
    .PARAMETER ItemType
        Display name of the item type being removed (e.g., 'Schedule', 'Script')
    .PARAMETER IdentifierParam
        Parameter name for the identifier (default: 'id')
    .PARAMETER IdentifierValue
        Value of the identifier to remove (if not provided, prompts user)
    .PARAMETER GetItemsFunction
        ScriptBlock that retrieves the list of available items
    .PARAMETER IdentifierColumn
        Column name containing the identifier in the item list (default: 'ID')
    .PARAMETER Syntax
        Display command syntax help instead of executing
    .OUTPUTS
        Boolean
        Returns $true when operation completes (whether executed or cancelled)
    .NOTES
        Internal Module Function
        
        This helper consolidates the Remove-* pattern used across multiple cmdlets,
        ensuring consistent behavior for interactive deletion operations.
    
    .EXAMPLE
        Invoke-RemoveWithPrompt -Command 'control.schedule.remove' -ItemType 'Schedule' -IdentifierValue 5 -GetItemsFunction { Get-ClientToolSchedule }
        Removes a schedule with confirmation prompt
    
    .EXAMPLE
        Invoke-RemoveWithPrompt -Command 'control.script.remove' -ItemType 'Script' -GetItemsFunction { Get-ClientToolScript }
        Lists available scripts and prompts for selection
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)] [string]$Command,
        [Parameter(Mandatory)] [string]$ItemType,
        [Parameter()] [string]$IdentifierParam = 'id',
        [Parameter()] $IdentifierValue,
        [Parameter()] [scriptblock]$GetItemsFunction,
        [Parameter()] [string]$IdentifierColumn = 'ID',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command $Command -ShowSyntax
        return $true
    }
    
    # If no identifier provided, list available items
    if ($null -eq $IdentifierValue -or [string]::IsNullOrWhiteSpace($IdentifierValue)) {
        Write-Host "Available ${ItemType}s:" -ForegroundColor Cyan
        Write-Host ""
        
        $items = & $GetItemsFunction
        
        if (-not $items) {
            Write-Host "No ${ItemType}s exist." -ForegroundColor Yellow
            return $true
        }
        
        $items | Format-Table -AutoSize
        
        # Prompt for identifier
        $IdentifierValue = Read-Host "Enter the $IdentifierColumn to remove (or press Enter to cancel)"
        if ([string]::IsNullOrWhiteSpace($IdentifierValue)) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return $true
        }
        
        # Validate the entered identifier exists
        if ($items.$IdentifierColumn -notcontains $IdentifierValue) {
            Write-Host "$ItemType $IdentifierColumn $IdentifierValue not found." -ForegroundColor Red
            return $true
        }
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add("-$IdentifierParam")
    $argList.Add($IdentifierValue.ToString())
    
    if ($PSCmdlet.ShouldProcess("$ItemType $IdentifierColumn $IdentifierValue", "Remove")) {
        Invoke-ClientTool -Command $Command -Arguments $argList
    }
    
    return $true
}

#endregion

#region Backup Control Functions

function Start-ClientToolBackup {
    <#
    .SYNOPSIS
        Starts a backup job using ClientTool
    .DESCRIPTION
        Initiates a backup for the specified datasource or all datasources if none specified.
        Backup will only start if the datasource has selections configured.
        Supports both interactive and non-interactive execution modes.
    .PARAMETER DataSource
        The datasource to backup. If omitted, starts backup for all configured datasources.
        Valid values: Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, 
        VMware, VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER NonInteractive
        Do not ask questions during execution
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.backup.start
        
        Start backup. If no datasource is specified, start backup for all datasources. 
        Backup would only be started if datasource in question has selections (and thus 
        needs to be backed up).
    .EXAMPLE
        Start-ClientToolBackup
        Starts backup for all configured datasources
    .EXAMPLE
        Start-ClientToolBackup -DataSource FileSystem
        Starts backup for FileSystem datasource only
    .EXAMPLE
        Start-ClientToolBackup -DataSource FileSystem,NetworkShares -NonInteractive
        Starts backup for multiple datasources without prompts
    .EXAMPLE
        Start-ClientToolBackup -Syntax
        Shows the command-line help for control.backup.start
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()] [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 
                     'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint')] [string]$DataSource,
        [Parameter()] [switch]$NonInteractive,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.backup.start' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($DataSource) {
        $argList.Add('-datasource')
        $argList.Add($DataSource)
    }
    
    $target = if ($DataSource) { $DataSource } else { "all datasources" }
    
    if ($PSCmdlet.ShouldProcess($target, "Start backup")) {
        Invoke-ClientTool -Command 'control.backup.start' -Arguments $argList -NonInteractive:$NonInteractive
    }
}

function Start-ClientToolRestore {
    <#
    .SYNOPSIS
        Starts a restore operation using ClientTool
    .DESCRIPTION
        Initiates a restore for specific or all nodes from a datasource backup.
        Restores from most recent session by default unless specific time is provided.
        Supports various restore options including alternate location, file policies, and ACL restoration.
    .PARAMETER DataSource
        The datasource to restore from (required).
        Valid values: BareMetalRestore, Exchange, FileSystem, MySql, NetworkShares, 
        Oracle, SystemState, VMware, VirtualDisasterRecovery, VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Selection
        Specific paths/nodes to restore. If omitted, restores all nodes from the datasource.
    .PARAMETER Time
        Backup session time in format "yyyy-MM-dd HH:mm:ss". Uses most recent if not specified.
    .PARAMETER RestoreTo
        Destination path for restored files. Uses original location if not specified.
    .PARAMETER ExistingFilesRestorePolicy
        How to handle existing files. Valid values: Skip (default), Overwrite, OverwriteOlder
    .PARAMETER OverwriteExisting
        Overwrite existing files (equivalent to -ExistingFilesRestorePolicy Overwrite)
    .PARAMETER OverwriteNewer
        Overwrite files even if existing files are newer
    .PARAMETER RestoreAcl
        Restore access control lists (permissions)
    .PARAMETER RestoreDeleted
        Include deleted items in restore
    .PARAMETER SkipFolders
        Restore files only, skip folders
    .PARAMETER UseLocalTime
        Interpret time parameter as local time instead of UTC
    .PARAMETER NonInteractive
        Suppress interactive prompts
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.restore.start
        
        Start restore operation. Use Get-ClientToolSession to view available backup 
        sessions and their timestamps for the -Time parameter.
    .EXAMPLE
        Start-ClientToolRestore -DataSource FileSystem
        Restore all FileSystem data from most recent backup
    .EXAMPLE
        Start-ClientToolRestore -DataSource FileSystem -Selection "C:\data" -RestoreTo "D:\restored"
        Restore C:\data to D:\restored location
    .EXAMPLE
        Start-ClientToolRestore -DataSource VssMsSql -Selection "SqlServer" -Time "2025-11-18 10:00:00"
        Restore SQL Server from specific backup session
    .EXAMPLE
        Start-ClientToolRestore -DataSource FileSystem -RestoreDeleted -OverwriteExisting
        Restore including deleted files and overwrite existing ones
    .EXAMPLE
        Start-ClientToolRestore -Syntax
        Shows the command-line help for control.restore.start
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [ValidateSet('BareMetalRestore', 'Exchange', 'FileSystem', 'MySql', 'NetworkShares', 
                     'Oracle', 'SystemState', 'VMware', 'VirtualDisasterRecovery', 
                     'VssHyperV', 'VssMsSql', 'VssSharePoint')] [string]$DataSource,
        [Parameter()] [string[]]$Selection,
        [Parameter()] [string]$Time,
        [Parameter()] [string]$RestoreTo,
        [Parameter()] [ValidateSet('Skip', 'Overwrite', 'OverwriteOlder')] [string]$ExistingFilesRestorePolicy,
        [Parameter()] [switch]$OverwriteExisting,
        [Parameter()] [switch]$OverwriteNewer,
        [Parameter()] [switch]$RestoreAcl,
        [Parameter()] [switch]$RestoreDeleted,
        [Parameter()] [switch]$SkipFolders,
        [Parameter()] [switch]$UseLocalTime,
        [Parameter()] [switch]$NonInteractive,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.restore.start' -ShowSyntax
        return
    }
    
    $restoreTarget = if ($Selection) { ($Selection -join ', ') } else { "all nodes from $DataSource" }
    
    if ($PSCmdlet.ShouldProcess($restoreTarget, "Start restore from $DataSource")) {
        $arguments = @("-datasource $DataSource")
        
        if ($Selection) {
            foreach ($item in $Selection) {
                $arguments += "-selection `"$item`""
            }
        }
        
        if ($Time) { $arguments += "-time `"$Time`"" }
        if ($RestoreTo) { $arguments += "-restore-to `"$RestoreTo`"" }
        
        # Handle existing files policy - explicit parameter takes precedence over switch
        if ($ExistingFilesRestorePolicy) {
            $arguments += "-existing-files-restore-policy $ExistingFilesRestorePolicy"
        }
        elseif ($OverwriteExisting) {
            $arguments += "-existing-files-restore-policy Overwrite"
        }
        
        if ($OverwriteNewer) { $arguments += "-overwrite-newer" }
        if ($RestoreAcl) { $arguments += "-restore-acl" }
        if ($RestoreDeleted) { $arguments += "-restore-deleted" }
        if ($SkipFolders) { $arguments += "-skip-folders" }
        if ($UseLocalTime) { $arguments += "-use-local-time" }
        
        Invoke-ClientTool -Command 'control.restore.start' -Arguments $arguments -NonInteractive:$NonInteractive
    }
}

#endregion

#region Status and Information Functions

function Get-ClientToolStatus {
    <#
    .SYNOPSIS
        Gets the current Backup Manager status
    .DESCRIPTION
        Retrieves the current program status from Backup Manager.
        Can optionally specify a custom config.ini file path.
    .PARAMETER Path
        Full path to config.ini file. Optional - defaults to 'C:\Program Files\Backup Manager\config.ini' if not specified.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        String[]
        Returns status information as text output
    .NOTES
        ClientTool Command: control.status.get
        
        Print current program status.
    .EXAMPLE
        Get-ClientToolStatus
        Gets current Backup Manager status using default config
    .EXAMPLE
        Get-ClientToolStatus -Path "C:\Program Files\Backup Manager\config.ini"
        Get status using a specific config file
    .EXAMPLE
        Get-ClientToolStatus -Syntax
        Shows the command-line help for control.status.get
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Path = 'C:\Program Files\Backup Manager\config.ini',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.status.get' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($Path) {
        $argList.Add('-path')
        $argList.Add($Path)
    }
    
    Invoke-ClientTool -Command 'control.status.get' -Arguments $argList
}

function Get-ClientToolApplicationStatus {
    <#
    .SYNOPSIS
        Gets the current application status
    .DESCRIPTION
        Retrieves detailed application status information from Backup Manager.
        Provides more comprehensive status details than Get-ClientToolStatus.
    .PARAMETER Path
        Full path to config.ini file. Optional - defaults to 'C:\Program Files\Backup Manager\config.ini' if not specified.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        String[]
        Returns detailed application status information
    .NOTES
        ClientTool Command: control.application-status.get
        
        Print current application status.
    .EXAMPLE
        Get-ClientToolApplicationStatus
        Gets application status using default config
    .EXAMPLE
        Get-ClientToolApplicationStatus -Path "C:\Program Files\Backup Manager\config.ini"
        Get application status using a specific config file
    .EXAMPLE
        Get-ClientToolApplicationStatus -Syntax
        Shows the command-line help for control.application-status.get
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Path = 'C:\Program Files\Backup Manager\config.ini',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.application-status.get' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($Path) {
        $argList.Add('-path')
        $argList.Add($Path)
    }
    
    Invoke-ClientTool -Command 'control.application-status.get' -Arguments $argList
}

function Get-ClientToolSystemInfo {
    <#
    .SYNOPSIS
        Gets system information (RAM/CPU) in JSON format
    .DESCRIPTION
        Retrieves system information including RAM and CPU details.
        Returns data in JSON format which can be parsed into PowerShell objects.
    .PARAMETER AsJson
        Return the raw JSON output instead of converting to objects
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns parsed JSON object with system information (RAM, CPU details) unless -AsJson is specified
    .NOTES
        ClientTool Command: system-info.get
        
        Gets SystemInfo (RAM/CPU) in JSON format.
    .EXAMPLE
        Get-ClientToolSystemInfo
        Gets system information as PowerShell objects
    .EXAMPLE
        Get-ClientToolSystemInfo -AsJson
        Gets system information as raw JSON string
    .EXAMPLE
        $sysInfo = Get-ClientToolSystemInfo; $sysInfo.RAM
        Gets system info and accesses RAM property
    .EXAMPLE
        Get-ClientToolSystemInfo -Syntax
        Shows the command-line help for system-info.get
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [switch]$AsJson,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'system-info.get' -ShowSyntax
        return
    }
    
    $output = Invoke-ClientTool -Command 'system-info.get' -MachineReadable
    
    if ($output -and -not $AsJson) {
        try {
            $output | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to parse JSON output: $_"
            return $output
        }
    }
    else {
        return $output
    }
}

function Get-ClientToolInitializationError {
    <#
    .SYNOPSIS
        Gets application initialization errors in JSON format
    .DESCRIPTION
        Retrieves any initialization errors that occurred during application startup.
        Returns error details in JSON format for troubleshooting startup issues.
    .PARAMETER AsJson
        Return the raw JSON output instead of converting to objects
    .PARAMETER Path
        Full path to config.ini file. Optional - defaults to 'C:\Program Files\Backup Manager\config.ini' if not specified.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns parsed JSON object with initialization error details unless -AsJson is specified
    .NOTES
        ClientTool Command: control.initialization-error.get
        
        Gets application initialization error in json format.
    .EXAMPLE
        Get-ClientToolInitializationError
        Gets initialization errors as PowerShell objects
    .EXAMPLE
        Get-ClientToolInitializationError -Path "C:\Program Files\Backup Manager\config.ini"
        Get initialization errors using a specific config file
    .EXAMPLE
        Get-ClientToolInitializationError -AsJson
        Gets initialization errors as raw JSON
    .EXAMPLE
        Get-ClientToolInitializationError -Syntax
        Shows the command-line help for control.initialization-error.get
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [switch]$AsJson,
        [Parameter()] [string]$Path = 'C:\Program Files\Backup Manager\config.ini',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.initialization-error.get' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($Path) {
        $argList.Add('-path')
        $argList.Add($Path)
    }
    
    $output = Invoke-ClientTool -Command 'control.initialization-error.get' -Arguments $argList -MachineReadable
    
    if ($output -and -not $AsJson) {
        try {
            $output | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to parse JSON output: $_"
            return $output
        }
    }
    else {
        return $output
    }
}

#endregion

#region Selection Functions

function Get-ClientToolSelection {
    <#
    .SYNOPSIS
        Lists backup selections
    .DESCRIPTION
        Retrieves the current backup selections for specified or all datasources.
        Returns a table showing which paths are included or excluded from backup,
        along with their priority levels.
    .PARAMETER DataSource
        The datasource to list selections for. If omitted, shows selections for all datasources.
        Valid values: Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware,
        VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)
    .PARAMETER NoHeader
        Exclude the header row from output
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - DSRC : Datasource name
        - TYPE : Selection type (inclusive or exclusive)
        - PRIO : Priority level (Low, Normal, High)
        - PATH : Selected path
    .NOTES
        ClientTool Command: control.selection.list
        Inclusive selections specify files/folders to backup.
        Exclusive selections specify files/folders to exclude from backup.
        Exclusions must be subpaths of inclusions.
    .EXAMPLE
        Get-ClientToolSelection
        Lists all backup selections across all datasources
    .EXAMPLE
        Get-ClientToolSelection -DataSource FileSystem
        Lists only FileSystem selections
    .EXAMPLE
        Get-ClientToolSelection | Where-Object { $_.TYPE -eq 'inclusive' }
        Lists only inclusive selections (what will be backed up)
    .EXAMPLE
        Get-ClientToolSelection | Where-Object { $_.PRIO -eq 'High' }
        Lists only high-priority selections
    .EXAMPLE
        Get-ClientToolSelection -Syntax
        Shows the command-line help for control.selection.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 
                     'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint')] [string]$DataSource,
        [Parameter()] [string]$Delimiter = "`t",
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.selection.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($DataSource) {
        $argList.Add('-datasource')
        $argList.Add($DataSource)
    }
    
    if ($Delimiter -ne "`t") {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.selection.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable -Delimiter $Delimiter
    }
}

function Set-ClientToolSelection {
    <#
    .SYNOPSIS
        Modifies backup selections
    .DESCRIPTION
        Adds or modifies backup selections for a datasource. Can include or exclude paths.
        Inclusive selections specify files/folders to backup, while exclusive selections
        specify files/folders to skip. Exclusions must be subpaths of inclusions.
    .PARAMETER DataSource
        The datasource to modify selections for (required). Valid values: Exchange, FileSystem, 
        MySql, NetworkShares, Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Include
        Path(s) to include in backup. Can be specified multiple times.
    .PARAMETER Exclude
        Path(s) to exclude from backup. Can be specified multiple times.
        Must be subpaths of included paths.
    .PARAMETER Priority
        Backup priority for included paths. Valid values: Low, Normal, High. Default: Normal
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.selection.modify
        
        Modify backup selections. Inclusive selections point to files (folders, databases etc.) 
        to be backed up. Exclusive selections denote files which should not be. Paths to be 
        excluded could only be subpaths of those to be included.
        
        Note that if you include the whole database to selection, you won't be able to include 
        any child table to selection because all child tables are implicitly covered by database 
        selection.
    .EXAMPLE
        Set-ClientToolSelection -DataSource FileSystem -Include 'C:\Data'
        Adds C:\Data to backup selections with Normal priority
    .EXAMPLE
        Set-ClientToolSelection -DataSource FileSystem -Include 'C:\Data' -Exclude 'C:\Data\Temp' -Priority High
        Includes C:\Data with high priority and excludes the Temp subfolder
    .EXAMPLE
        Set-ClientToolSelection -DataSource MySql -Include 'SqlServer'
        Adds SQL Server to MySQL datasource selections
    .EXAMPLE
        Set-ClientToolSelection -DataSource FileSystem -Include 'C:\Users','D:\Documents' -Priority High
        Adds multiple paths with high priority
    .EXAMPLE
        Set-ClientToolSelection -Syntax
        Shows the command-line help for control.selection.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]        [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 
                     'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint')]
        [string]$DataSource,
        [Parameter()] [string[]]$Include,
        [Parameter()] [string[]]$Exclude,
        [Parameter()] [ValidateSet('Low', 'Normal', 'High')] [string]$Priority = 'Normal',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.selection.modify' -ShowSyntax
        return
    }
    
    if (-not $Include -and -not $Exclude) {
        throw "You must specify at least one -Include or -Exclude path"
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    $argList.Add('-datasource')
    $argList.Add($DataSource)
    
    foreach ($path in $Include) {
        $argList.Add('-include')
        $argList.Add($path)
    }
    
    foreach ($path in $Exclude) {
        $argList.Add('-exclude')
        $argList.Add($path)
    }
    
    if ($Include -and $Priority) {
        $argList.Add('-priority')
        $argList.Add($Priority)
    }
    
    if ($PSCmdlet.ShouldProcess("$DataSource selections", "Modify")) {
        Invoke-ClientTool -Command 'control.selection.modify' -Arguments $argList
    }
}

function Clear-ClientToolSelection {
    <#
    .SYNOPSIS
        Clears backup selections
    .DESCRIPTION
        Removes all backup selections. Currently selected files on disk are not affected.
        If no datasource is specified, selections for all datasources are cleared.
        This is a destructive operation that requires confirmation by default.
    .PARAMETER DataSource
        Datasource(s) to clear selections for. If omitted, clears selections for all datasources.
        Valid values: Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware,
        VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.selection.clear
        
        Clear backup selections. Currently selected files data on disk not affected in any way. 
        If no datasource is specified, selections for all datasources are cleared.
    .EXAMPLE
        Clear-ClientToolSelection -Confirm:$false
        Clears all backup selections for all datasources without prompting
    .EXAMPLE
        Clear-ClientToolSelection -DataSource FileSystem
        Clears only FileSystem selections (prompts for confirmation)
    .EXAMPLE
        Clear-ClientToolSelection -DataSource FileSystem,MySql -Confirm:$false
        Clears selections for multiple datasources without prompting
    .EXAMPLE
        Clear-ClientToolSelection -Syntax
        Shows the command-line help for control.selection.clear
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]        [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 
                     'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint')]
        [string[]]$DataSource,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.selection.clear' -ShowSyntax
        return
    }
    
    $target = if ($DataSource) { $DataSource -join ', ' } else { "all datasources" }
    
    if ($PSCmdlet.ShouldProcess($target, "Clear backup selections")) {
        $argList = [System.Collections.Generic.List[string]]::new()
        
        if ($DataSource) {
            foreach ($ds in $DataSource) {
                $argList.Add('-datasource')
                $argList.Add($ds)
            }
        }
        
        if ($argList.Count -gt 0) {
            Invoke-ClientTool -Command 'control.selection.clear' -Arguments $argList
        } else {
            Invoke-ClientTool -Command 'control.selection.clear'
        }
    }
}

#endregion

#region Session Functions

function Get-ClientToolSession {
    <#
    .SYNOPSIS
        Lists backup and restore sessions
    .DESCRIPTION
        Retrieves session history for specified or all datasources.
        Returns details including session type, state, flags, times, sizes, and error counts.
        The START time column can be used with restore operations to restore from specific sessions.
    .PARAMETER DataSource
        The datasource to filter sessions by. If omitted, shows all datasources.
        Valid values: BareMetalRestore, Exchange, FileSystem, MySql, NetworkShares, Oracle, 
        SystemState, VMware, VirtualDisasterRecovery, VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)
    .PARAMETER NoHeader
        Exclude the header row from output
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - DSRC   : Datasource name
        - TYPE   : Session type (backup/restore)
        - STATE  : Session status
        - FLAGS  : Session flags (A=archived)
        - START  : Start time (use for restore operations)
        - END    : End time
        - SELS   : Selected size
        - SELC   : Selected files count
        - PROCS  : Processed size
        - PROCC  : Processed files count
        - SENTS  : Sent size
        - ERRC   : Errors count
        - REMC   : Removed files count
    .NOTES
        ClientTool Command: control.session.list
        
        List backup and restore sessions. Session start time (START column) can be used 
        with Start-ClientToolRestore to restore files from that specific session.
        
        Session FLAGS column symbols:
            A = archived
    .EXAMPLE
        Get-ClientToolSession
        Lists all sessions for all datasources
    .EXAMPLE
        Get-ClientToolSession -DataSource FileSystem
        Lists FileSystem sessions only
    .EXAMPLE
        Get-ClientToolSession | Where-Object { $_.STATE -eq 'Completed' -and $_.ERRC -eq 0 }
        Lists only successful sessions with no errors
    .EXAMPLE
        Get-ClientToolSession -DataSource FileSystem | Select-Object -First 1 -ExpandProperty START
        Gets the most recent FileSystem backup session start time
    .EXAMPLE
        Get-ClientToolSession -Syntax
        Shows the command-line help for control.session.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [ValidateSet('BareMetalRestore', 'Exchange', 'FileSystem', 'MySql', 'NetworkShares', 
                     'Oracle', 'SystemState', 'VMware', 'VirtualDisasterRecovery', 'VssHyperV', 
                     'VssMsSql', 'VssSharePoint')] [string]$DataSource,
        [Parameter()] [string]$Delimiter = "`t",
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.session.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($DataSource) {
        $argList.Add('-datasource')
        $argList.Add($DataSource)
    }
    
    if ($Delimiter -ne "`t") {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.session.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable -Delimiter $Delimiter
    }
}

function Get-ClientToolSessionError {
    <#
    .SYNOPSIS
        Lists session errors
    .DESCRIPTION
        Retrieves error details from backup/restore sessions for a specific datasource.
        Returns errors from the most recent session by default, or from a specific session time.
    .PARAMETER DataSource
        The datasource to show errors for (required). Valid values: BareMetalRestore, Exchange, 
        FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware, VirtualDisasterRecovery, 
        VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Time
        Start time of backup session in format "yyyy-MM-dd HH:mm:ss". 
        Defaults to most recent session if not specified.
    .PARAMETER Limit
        Maximum number of errors to return. Default is 100.
    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)
    .PARAMETER NoHeader
        Exclude the header row from output
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - DATETIME : Error timestamp
        - PATH     : Node path where error occurred
        - CONTENT  : Error description
    .NOTES
        ClientTool Command: control.session.error.list
        
        List session errors. Displays session errors for specific datasource.
        Produces a table with TAB-separated (by default) columns in this order:
            DATETIME  Error time
            PATH      Node path
            CONTENT   Error description
    .EXAMPLE
        Get-ClientToolSessionError -DataSource FileSystem
        Gets errors from the most recent FileSystem backup session
    .EXAMPLE
        Get-ClientToolSessionError -DataSource FileSystem -Limit 50
        Gets the first 50 errors from the most recent FileSystem session
    .EXAMPLE
        Get-ClientToolSessionError -DataSource FileSystem -Time "2025-11-14 00:05:00"
        Gets errors from a specific FileSystem backup session
    .EXAMPLE
        Get-ClientToolSessionError -DataSource NetworkShares | Where-Object { $_.CONTENT -like '*timeout*' }
        Gets all timeout-related errors from NetworkShares
    .EXAMPLE
        Get-ClientToolSessionError -Syntax
        Shows the command-line help for control.session.error.list
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]        [ValidateSet('BareMetalRestore', 'Exchange', 'FileSystem', 'MySql', 'NetworkShares', 
                     'Oracle', 'SystemState', 'VMware', 'VirtualDisasterRecovery', 'VssHyperV', 
                     'VssMsSql', 'VssSharePoint')]
        [string]$DataSource,
        [Parameter()] [datetime]$Time,
        [Parameter()] [int]$Limit = 100,
        [Parameter()] [string]$Delimiter = "`t",
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.session.error.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    # Required datasource parameter
    $argList.Add('-datasource')
    $argList.Add($DataSource)
    
    # Optional time parameter
    if ($Time) {
        $argList.Add('-time')
        $argList.Add($Time.ToString('yyyy-MM-dd HH:mm:ss'))
    }
    
    # Optional limit parameter
    if ($Limit -ne 100) {
        $argList.Add('-limit')
        $argList.Add($Limit.ToString())
    }
    
    # Optional delimiter parameter
    if ($Delimiter -ne "`t") {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    # Optional no-header parameter
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.session.error.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable -Delimiter $Delimiter
    }
}

function Get-ClientToolSessionNode {
    <#
    .SYNOPSIS
        Lists session nodes
    .DESCRIPTION
        Retrieves node information from backup/restore sessions for a specific datasource.
        Shows changed or removed nodes with timing, size, and path details.
        Returns nodes from the most recent session by default.
    .PARAMETER DataSource
        The datasource to list nodes for (required).
        Valid values: BareMetalRestore, Exchange, FileSystem, MySql, NetworkShares, 
        Oracle, SystemState, VMware, VirtualDisasterRecovery, VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Delimiter
        Delimiter to use for output (default: TAB)
    .PARAMETER Limit
        Maximum number of nodes to display
    .PARAMETER NoHeader
        Suppress the header row in output
    .PARAMETER Offset
        Number of nodes to skip before displaying
    .PARAMETER Readable
        Display sizes in human-readable format (KB, MB, GB)
    .PARAMETER Removed
        Show only removed nodes
    .PARAMETER Time
        Start time of backup session in format "yyyy-MM-dd HH:mm:ss". 
        Defaults to most recent session if not specified.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - START : Backup start time
        - END   : Backup end time
        - SIZE  : Node size
        - SENTS : Sent size
        - PATH  : Node path
        
        For removed nodes, only PATH column is displayed since others are not applicable.
    .NOTES
        ClientTool Command: control.session.node.list
        
        List session nodes. Displays changed or removed session nodes for specific datasource.
    .EXAMPLE
        Get-ClientToolSessionNode -DataSource FileSystem
        Lists all nodes from the most recent FileSystem session
    .EXAMPLE
        Get-ClientToolSessionNode -DataSource FileSystem -Removed
        Show only removed nodes from most recent session
    .EXAMPLE
        Get-ClientToolSessionNode -DataSource FileSystem -Readable -Limit 100
        Show first 100 nodes with human-readable sizes
    .EXAMPLE
        Get-ClientToolSessionNode -DataSource FileSystem -Time "2025-11-18 10:00:00"
        Lists nodes from a specific backup session
    .EXAMPLE
        Get-ClientToolSessionNode -Syntax
        Shows the command-line help for control.session.node.list
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]        [ValidateSet('BareMetalRestore', 'Exchange', 'FileSystem', 'MySql', 'NetworkShares', 
                     'Oracle', 'SystemState', 'VMware', 'VirtualDisasterRecovery', 
                     'VssHyperV', 'VssMsSql', 'VssSharePoint')]
        [string]$DataSource,
        [Parameter()] [string]$Delimiter,
        [Parameter()] [int]$Limit,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [int]$Offset,
        [Parameter()] [switch]$Readable,
        [Parameter()] [switch]$Removed,
        [Parameter()] [string]$Time,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.session.node.list' -ShowSyntax
        return
    }
    
    $arguments = @("-datasource $DataSource")
    if ($Delimiter) { $arguments += "-delimiter `"$Delimiter`"" }
    if ($Limit) { $arguments += "-limit $Limit" }
    if ($NoHeader) { $arguments += "-no-header" }
    if ($Offset) { $arguments += "-offset $Offset" }
    if ($Readable) { $arguments += "-readable" }
    if ($Removed) { $arguments += "-removed" }
    if ($Time) { $arguments += "-time `"$Time`"" }
    
    $output = Invoke-ClientTool -Command 'control.session.node.list' -Arguments $arguments -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function Export-ClientToolSessionNode {
    <#
    .SYNOPSIS
        Exports session nodes to a file
    .DESCRIPTION
        Exports session node information from backup/restore sessions to a file.
        Exports nodes from the most recent session by default, or from a specific session time.
        Always uses .xml extension and auto-generates filename if only a directory is provided.
        Supports XML and CSV format exports.
    .PARAMETER DataSource
        The datasource to export nodes for (required). Valid values: BareMetalRestore, Exchange, 
        FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware, VirtualDisasterRecovery, 
        VssHyperV, VssMsSql, VssSharePoint
    .PARAMETER Path
        The file path or directory to export to. If a directory is provided, a filename will be 
        auto-generated based on the datasource abbreviation. The .xml extension is always enforced.
    .PARAMETER Format
        Output format. Valid values: xml, csv. Default is xml.
    .PARAMETER Time
        Start time of backup session in format "yyyy-MM-dd HH:mm:ss". 
        Defaults to most recent session if not specified.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output and displays the export file path
    .NOTES
        ClientTool Command: control.session.node.export
        
        Export session nodes to file. The .xml extension is always enforced regardless of 
        the provided filename. If only a directory is provided, filename is auto-generated 
        using datasource abbreviation (e.g., FS-SessionNodes.xml).
    .EXAMPLE
        Export-ClientToolSessionNode -DataSource FileSystem -Path C:\Temp
        Exports to C:\Temp\FS-SessionNodes.xml
    .EXAMPLE
        Export-ClientToolSessionNode -DataSource NetworkShares -Path C:\Temp\
        Exports to C:\Temp\NS-SessionNodes.xml
    .EXAMPLE
        Export-ClientToolSessionNode -DataSource FileSystem -Path C:\Temp\nodes.csv -Format xml
        Exports to C:\Temp\nodes.xml (extension is enforced to .xml)
    .EXAMPLE
        Export-ClientToolSessionNode -DataSource FileSystem -Path C:\Temp\custom.xml -Time "2025-11-14 00:05:00"
        Exports session nodes from a specific backup session
    .EXAMPLE
        Export-ClientToolSessionNode -Syntax
        Shows the command-line help for control.session.node.export
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]        [ValidateSet('BareMetalRestore', 'Exchange', 'FileSystem', 'MySql', 'NetworkShares', 
                     'Oracle', 'SystemState', 'VMware', 'VirtualDisasterRecovery', 'VssHyperV', 
                     'VssMsSql', 'VssSharePoint')]
        [string]$DataSource,
        [Parameter(Mandatory)] [string]$Path,
        [Parameter()]        [ValidateSet('xml', 'csv')]
        [string]$Format = 'xml',
        [Parameter()] [datetime]$Time,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.session.node.export' -ShowSyntax
        return
    }
    
    # Datasource abbreviation mapping
    $dsAbbrev = @{
        'BareMetalRestore' = 'BMR'
        'Exchange' = 'EX'
        'FileSystem' = 'FS'
        'MySql' = 'MySQL'
        'NetworkShares' = 'NS'
        'Oracle' = 'ORA'
        'SystemState' = 'SS'
        'VMware' = 'VM'
        'VirtualDisasterRecovery' = 'VDR'
        'VssHyperV' = 'HyperV'
        'VssMsSql' = 'SQL'
        'VssSharePoint' = 'SP'
    }
    
    # Process the path
    $outputPath = $Path
    
    # Check if path is a directory or needs a filename
    if (Test-Path -Path $Path -PathType Container) {
        # It's a directory, generate filename
        $filename = "$($dsAbbrev[$DataSource])-SessionNodes.xml"
        $outputPath = Join-Path -Path $Path -ChildPath $filename
        Write-Verbose "Directory provided. Auto-generated filename: $filename"
    }
    elseif ($Path -match '[\\/]$') {
        # Path ends with slash/backslash, treat as directory
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
        $filename = "$($dsAbbrev[$DataSource])-SessionNodes.xml"
        $outputPath = Join-Path -Path $Path -ChildPath $filename
        Write-Verbose "Directory path detected. Auto-generated filename: $filename"
    }
    else {
        # It's a file path - enforce .xml extension
        $directory = Split-Path -Path $Path -Parent
        $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        
        if ([string]::IsNullOrWhiteSpace($fileNameWithoutExt)) {
            # No filename provided, just a path separator
            if ([string]::IsNullOrWhiteSpace($directory)) {
                $directory = Get-Location
            }
            $filename = "$($dsAbbrev[$DataSource])-SessionNodes.xml"
            $outputPath = Join-Path -Path $directory -ChildPath $filename
            Write-Verbose "No filename detected. Auto-generated: $filename"
        }
        else {
            # Filename exists, replace extension with .xml
            if ($directory) {
                $outputPath = Join-Path -Path $directory -ChildPath "$fileNameWithoutExt.xml"
            }
            else {
                $outputPath = "$fileNameWithoutExt.xml"
            }
            
            $originalExt = [System.IO.Path]::GetExtension($Path)
            if ($originalExt -and $originalExt -ne '.xml') {
                Write-Verbose "Extension changed from $originalExt to .xml"
            }
        }
    }
    
    # Ensure directory exists
    $parentDir = Split-Path -Path $outputPath -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        Write-Verbose "Created directory: $parentDir"
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    # Required datasource parameter
    $argList.Add('-datasource')
    $argList.Add($DataSource)
    
    # Output file parameter
    $argList.Add('-output-file')
    $argList.Add($outputPath)
    
    # Optional format parameter
    if ($Format) {
        $argList.Add('-format')
        $argList.Add($Format)
    }
    
    # Optional time parameter
    if ($Time) {
        $argList.Add('-time')
        $argList.Add($Time.ToString('yyyy-MM-dd HH:mm:ss'))
    }
    
    if ($PSCmdlet.ShouldProcess("$DataSource session nodes to $outputPath", "Export")) {
        Invoke-ClientTool -Command 'control.session.node.export' -Arguments $argList -MachineReadable
        
        if ($?) {
            Write-Host "Session nodes exported to: $outputPath" -ForegroundColor Green
        }
    }
}

function Stop-ClientToolSession {
    <#
    .SYNOPSIS
        Aborts a backup or restore session
    .DESCRIPTION
        Terminates all currently running backup or restore sessions.
        There is no way to abort a specific session - all sessions currently in progress will be aborted.
        This is a high-impact operation that requires confirmation by default.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.session.abort
        
        Abort backup or restore session. All sessions currently in progress will be aborted.
    .EXAMPLE
        Stop-ClientToolSession
        Aborts all running sessions (prompts for confirmation)
    .EXAMPLE
        Stop-ClientToolSession -Confirm:$false
        Aborts all running sessions without prompting
    .EXAMPLE
        Stop-ClientToolSession -WhatIf
        Shows what would happen without actually aborting sessions
    .EXAMPLE
        Stop-ClientToolSession -Syntax
        Shows the command-line help for control.session.abort
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.session.abort' -ShowSyntax
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Current session", "Abort")) {
        Invoke-ClientTool -Command 'control.session.abort'
    }
}

#endregion

#region Settings Functions

function Get-ClientToolSetting {
    <#
    .SYNOPSIS
        Lists application settings
    .DESCRIPTION
        Retrieves current application settings configuration.
        Returns a table of setting names and values. Setting names can be used with 
        Set-ClientToolSetting to modify specific settings.
    .PARAMETER Delimiter
        Delimiter to use for output (default: TAB)
    .PARAMETER NoHeader
        Suppress the header row in output
    .PARAMETER Plugin
        Filter by plugin name. Valid values: sims
    .PARAMETER SettingName
        Filter by specific setting name. Supported values include:
        sims.server, sims.database, sims.db.attach.path, sims.path.to.shared,
        sims.path.to.dms, sims.backup.master, discover.database,
        discover.db.attach.path, fms.server, fms.database, fms.db.attach.path
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - NAME  : Setting name
        - VALUE : Setting value
    .NOTES
        ClientTool Command: control.setting.list
        
        List application settings. The NAME column can be used with Set-ClientToolSetting 
        to modify specific settings.
    .EXAMPLE
        Get-ClientToolSetting
        Lists all application settings
    .EXAMPLE
        Get-ClientToolSetting -Plugin sims
        List only SIMS-related settings
    .EXAMPLE
        Get-ClientToolSetting -SettingName "sims.server"
        Get a specific setting value
    .EXAMPLE
        Get-ClientToolSetting | Where-Object { $_.NAME -like '*database*' }
        Find all database-related settings
    .EXAMPLE
        Get-ClientToolSetting -Delimiter "," -NoHeader
        Export settings in CSV format without headers
    .EXAMPLE
        Get-ClientToolSetting -Syntax
        Shows the command-line help for control.setting.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()]        [ValidateSet('sims')]
        [string]$Plugin,
        [Parameter()]        [ValidateSet(
            'sims.server', 'sims.database', 'sims.db.attach.path',
            'sims.path.to.shared', 'sims.path.to.dms', 'sims.backup.master',
            'discover.database', 'discover.db.attach.path',
            'fms.server', 'fms.database', 'fms.db.attach.path'
        )]
        [string]$SettingName,
        
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.setting.list' -ShowSyntax
        return
    }
    
    $arguments = @()
    if ($Delimiter) { $arguments += "-delimiter `"$Delimiter`"" }
    if ($NoHeader) { $arguments += "-no-header" }
    if ($Plugin) { $arguments += "-plugin `"$Plugin`"" }
    if ($SettingName) { $arguments += "-setting.name `"$SettingName`"" }
    
    $output = Invoke-ClientTool -Command 'control.setting.list' -Arguments $arguments -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function Set-ClientToolSetting {
    <#
    .SYNOPSIS
        Modifies application settings
    .DESCRIPTION
        Changes application settings configuration.
        Use Get-ClientToolSetting to view available settings and their current values.
        Can modify multiple settings in a single operation by providing arrays of names and values.
    .PARAMETER Name
        Setting name(s) to modify. Can specify multiple names.
    .PARAMETER Value
        Setting value(s). One value for each setting name should be provided.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.setting.modify
        
        Modify application settings. Provided values are coupled with settings in same order.
        All available settings can be listed with Get-ClientToolSetting.
    .EXAMPLE
        Set-ClientToolSetting -Name "MaxConcurrentBackups" -Value "3"
        Sets the MaxConcurrentBackups setting to 3
    .EXAMPLE
        Set-ClientToolSetting -Name "MaxConcurrentBackups","CompressionLevel" -Value "3","High"
        Sets multiple settings at once
    .EXAMPLE
        Get-ClientToolSetting | Where-Object { $_.NAME -eq 'MaxConcurrentBackups' } | ForEach-Object { Set-ClientToolSetting -Name $_.NAME -Value "5" }
        Updates a specific setting based on current configuration
    .EXAMPLE
        Set-ClientToolSetting -Syntax
        Shows the command-line help for control.setting.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]        [string[]]$Name,
        [Parameter(Mandatory)]        [string[]]$Value,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.setting.modify' -ShowSyntax
        return
    }
    
    if ($Name.Count -ne $Value.Count) {
        throw "The number of names ($($Name.Count)) must match the number of values ($($Value.Count))"
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    foreach ($n in $Name) {
        $argList.Add('-name')
        $argList.Add($n)
    }
    
    foreach ($v in $Value) {
        $argList.Add('-value')
        $argList.Add($v)
    }
    
    $settingNames = $Name -join ', '
    
    if ($PSCmdlet.ShouldProcess("Settings: $settingNames", "Modify")) {
        Invoke-ClientTool -Command 'control.setting.modify' -Arguments $argList
    }
}

#endregion

#region Schedule Functions

function Get-ClientToolSchedule {
    <#
    .SYNOPSIS
        Lists backup schedules
    .DESCRIPTION
        Retrieves configured backup schedules. Returns a table with schedule details including
        ID, activation status, name, time, days, datasources, and associated script IDs.
        The Schedule ID can be used with Set-ClientToolSchedule or Remove-ClientToolSchedule 
        to modify or remove specific schedules.
    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)
    .PARAMETER NoHeader
        Suppress table header in output
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - ID      : Unique schedule identifier
        - ACTV    : Is schedule active (0=inactive, 1=active)
        - NAME    : Schedule name
        - TIME    : Time backup will fire at
        - DAYS    : Days backup will fire on
        - DSRC    : Datasources to backup
        - PRESID  : Pre-backup script ID
        - POSTSID : Post-backup script ID
    .NOTES
        ClientTool Command: control.schedule.list
        
        The schedule ID from the output can be used to modify or remove schedules:
        - Modify: Set-ClientToolSchedule -Id <ID>
        - Remove: Remove-ClientToolSchedule -Id <ID>
    .EXAMPLE
        Get-ClientToolSchedule
        Lists all configured backup schedules with their details
    .EXAMPLE
        Get-ClientToolSchedule | Where-Object { $_.ACTV -eq 1 }
        Lists only active schedules
    .EXAMPLE
        Get-ClientToolSchedule | Where-Object { $_.DSRC -like '*FileSystem*' }
        Lists schedules that include FileSystem datasource
    .EXAMPLE
        Get-ClientToolSchedule -Delimiter "," -NoHeader | Out-File schedules.csv
        Exports schedules to CSV format
    .EXAMPLE
        Get-ClientToolSchedule -Syntax
        Shows the command-line help for control.schedule.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.schedule.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($PSBoundParameters.ContainsKey('Delimiter')) {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.schedule.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function New-ClientToolSchedule {
    <#
    .SYNOPSIS
        Creates a new backup schedule
    .DESCRIPTION
        Adds a new schedule configuration with specified time, days, and datasources.
        Use Get-ClientToolSchedule to view existing schedules after creation.
        Schedules can optionally include pre-backup and post-backup scripts.
    .PARAMETER Name
        Name of the schedule (required)
    .PARAMETER Active
        Whether the schedule is active. Valid values: 0 (inactive), 1 (active). Default is 1
    .PARAMETER Time
        Schedule time in format hh:mm (e.g., "14:30"). Default is 00:00
    .PARAMETER Days
        Days when schedule is active. Valid values: Monday, Tuesday, Wednesday, Thursday, 
        Friday, Saturday, Sunday, All. Default is All
    .PARAMETER DataSources
        Datasources to backup. Valid values: Exchange, FileSystem, MySql, NetworkShares, 
        Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint, All. Default is All
    .PARAMETER PreBackupActionId
        ID of pre-backup script (use Get-ClientToolScript to view available scripts)
    .PARAMETER PostBackupActionId
        ID of post-backup script (use Get-ClientToolScript to view available scripts)
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.schedule.add
        
        Create new schedule. You can view existing schedules using Get-ClientToolSchedule 
        which also prints ID for each schedule.
    .EXAMPLE
        New-ClientToolSchedule -Name "Daily Backup"
        Creates a new schedule with default settings (All datasources, All days, 00:00)
    .EXAMPLE
        New-ClientToolSchedule -Name "Nightly FileSystem" -Time "02:00" -DataSources FileSystem -Days Monday,Wednesday,Friday
        Creates a schedule for FileSystem backups on MWF at 2:00 AM
    .EXAMPLE
        New-ClientToolSchedule -Name "SQL Backup" -DataSources VssMsSql -Time "23:00" -Days All
        Creates a daily SQL backup schedule at 11:00 PM
    .EXAMPLE
        New-ClientToolSchedule -Name "Weekend Backup" -Days Saturday,Sunday -Time "01:00" -Active 1
        Creates an active weekend backup schedule
    .EXAMPLE
        New-ClientToolSchedule -Syntax
        Shows the command-line help for control.schedule.add
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()] [string]$Name,
        [Parameter()]        [ValidateRange(0, 1)]
        [int]$Active = 1,
        [Parameter()]        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$Time = "00:00",
        [Parameter()]        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', 'All')]
        [string[]]$Days = @('All'),
        [Parameter()]        [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint', 'All')]
        [string[]]$DataSources = @('All'),
        [Parameter()] [int]$PreBackupActionId,
        [Parameter()] [int]$PostBackupActionId,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.schedule.add' -ShowSyntax
        return
    }
    
    # Validate required Name parameter
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host "`nBackup Schedule Creation Help" -ForegroundColor Cyan
        Write-Host "=" * 70 -ForegroundColor Gray
        Write-Host "`nThe -Name parameter is required to create a backup schedule.`n" -ForegroundColor Yellow
        Write-Host "Usage Examples:" -ForegroundColor White
        Write-Host "  New-ClientToolSchedule -Name 'Daily Backup'" -ForegroundColor Green
        Write-Host "  New-ClientToolSchedule -Name 'Nightly' -Time '02:00' -Days Monday,Friday" -ForegroundColor Green
        Write-Host "  New-ClientToolSchedule -Syntax  (show detailed help)`n" -ForegroundColor Green
        throw "Parameter -Name is required. Provide a name for the backup schedule."
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-active')
    $argList.Add($Active.ToString())
    $argList.Add('-time')
    $argList.Add($Time)
    $argList.Add('-days')
    $argList.Add(($Days -join ','))
    $argList.Add('-datasources')
    $argList.Add(($DataSources -join ','))
    
    if ($PSBoundParameters.ContainsKey('PreBackupActionId')) {
        $argList.Add('-pre-backup-action')
        $argList.Add($PreBackupActionId.ToString())
    }
    
    if ($PSBoundParameters.ContainsKey('PostBackupActionId')) {
        $argList.Add('-post-backup-action')
        $argList.Add($PostBackupActionId.ToString())
    }
    
    if ($PSCmdlet.ShouldProcess("Schedule '$Name'", "Create")) {
        Invoke-ClientTool -Command 'control.schedule.add' -Arguments $argList
    }
}

function Set-ClientToolSchedule {
    <#
    .SYNOPSIS
        Modifies an existing schedule
    .DESCRIPTION
        Updates schedule configuration by ID. All optional parameters will only update
        the corresponding properties if specified. If no ID is provided, displays available 
        schedules and prompts for selection.
        Use Get-ClientToolSchedule to view existing schedules and their IDs.
    .PARAMETER Id
        ID of the schedule to modify. If not provided, displays available schedules for selection.
    .PARAMETER Active
        Whether the schedule is active. Valid values: 0 (inactive), 1 (active)
    .PARAMETER Name
        Name of the schedule
    .PARAMETER Time
        Schedule time in format hh:mm (e.g., "14:30")
    .PARAMETER Days
        Days when schedule is active. Valid values: Monday, Tuesday, Wednesday, Thursday, 
        Friday, Saturday, Sunday, All
    .PARAMETER DataSources
        Datasources to backup. Valid values: Exchange, FileSystem, MySql, NetworkShares, 
        Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint, All
    .PARAMETER PreBackupActionId
        ID of pre-backup script (use Get-ClientToolScript to view available scripts)
    .PARAMETER PostBackupActionId
        ID of post-backup script (use Get-ClientToolScript to view available scripts)
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.schedule.modify
        
        Modify existing schedule. Schedule ID is used to locate the schedule to be modified. 
        All other arguments are optional and will not affect corresponding schedule properties 
        unless specified.
    .EXAMPLE
        Set-ClientToolSchedule -Id 253 -Active 1
        Activates schedule ID 253
    .EXAMPLE
        Set-ClientToolSchedule -Id 253 -Name "Daily Backup" -Time "02:00"
        Renames schedule and changes time to 2:00 AM
    .EXAMPLE
        Set-ClientToolSchedule -Id 253 -Days Monday,Wednesday,Friday -DataSources FileSystem,NetworkShares
        Sets schedule to run on MWF for FileSystem and NetworkShares
    .EXAMPLE
        Get-ClientToolSchedule | Where-Object { $_.NAME -eq 'NW Shares' } | ForEach-Object { Set-ClientToolSchedule -Id $_.ID -Active 1 }
        Activates schedule named 'NW Shares'
    .EXAMPLE
        Set-ClientToolSchedule
        Displays available schedules and prompts for ID to modify
    .EXAMPLE
        Set-ClientToolSchedule -Syntax
        Shows the command-line help for control.schedule.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [int]$Id,
        [Parameter()]        [ValidateRange(0, 1)]
        [int]$Active,
        [Parameter()] [string]$Name,
        [Parameter()]        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$Time,
        [Parameter()]        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', 'All')]
        [string[]]$Days,
        [Parameter()]        [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint', 'All')]
        [string[]]$DataSources,
        [Parameter()] [int]$PreBackupActionId,
        [Parameter()] [int]$PostBackupActionId,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.schedule.modify' -ShowSyntax
        return
    }
    
    # If no ID provided, list available schedules
    if (-not $PSBoundParameters.ContainsKey('Id')) {
        Write-Host "Available Schedules:" -ForegroundColor Cyan
        Write-Host ""
        
        $schedules = Get-ClientToolSchedule
        
        if (-not $schedules) {
            Write-Host "No schedules exist." -ForegroundColor Yellow
            return
        }
        
        $schedules | Format-Table -AutoSize
        
        # Prompt for ID
        $Id = Read-Host "Enter the Schedule ID to modify (or press Enter to cancel)"
        if ([string]::IsNullOrWhiteSpace($Id)) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
        
        # Validate the entered ID exists
        if ($schedules.ID -notcontains [int]$Id) {
            Write-Host "Schedule ID $Id not found." -ForegroundColor Red
            return
        }
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-id')
    $argList.Add($Id.ToString())
    
    if ($PSBoundParameters.ContainsKey('Active')) {
        $argList.Add('-active')
        $argList.Add($Active.ToString())
    }
    
    if ($PSBoundParameters.ContainsKey('Name')) {
        $argList.Add('-name')
        $argList.Add($Name)
    }
    
    if ($PSBoundParameters.ContainsKey('Time')) {
        $argList.Add('-time')
        $argList.Add($Time)
    }
    
    if ($PSBoundParameters.ContainsKey('Days')) {
        $argList.Add('-days')
        $argList.Add(($Days -join ','))
    }
    
    if ($PSBoundParameters.ContainsKey('DataSources')) {
        $argList.Add('-datasources')
        $argList.Add(($DataSources -join ','))
    }
    
    if ($PSBoundParameters.ContainsKey('PreBackupActionId')) {
        $argList.Add('-pre-backup-action')
        $argList.Add($PreBackupActionId.ToString())
    }
    
    if ($PSBoundParameters.ContainsKey('PostBackupActionId')) {
        $argList.Add('-post-backup-action')
        $argList.Add($PostBackupActionId.ToString())
    }
    
    if ($PSCmdlet.ShouldProcess("Schedule ID $Id", "Modify")) {
        Invoke-ClientTool -Command 'control.schedule.modify' -Arguments $argList
    }
}

function Remove-ClientToolSchedule {
    <#
    .SYNOPSIS
        Removes a backup schedule
    .DESCRIPTION
        Deletes an existing schedule configuration by ID.
        Use Get-ClientToolSchedule to view existing schedules and their IDs.
        If no ID is provided, displays available schedules and prompts for selection.
        This is a destructive operation that requires confirmation by default.
    .PARAMETER Id
        ID of the schedule to remove. If not provided, displays available schedules for selection.
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        Boolean
        Returns $true when operation completes
    .NOTES
        ClientTool Command: control.schedule.remove
        
        Remove existing schedule. Schedule ID is used to locate the schedule to be removed.
    .EXAMPLE
        Remove-ClientToolSchedule -Id 5
        Removes the schedule with ID 5 (prompts for confirmation)
    .EXAMPLE
        Remove-ClientToolSchedule -Id 5 -Confirm:$false
        Removes the schedule with ID 5 without prompting
    .EXAMPLE
        Get-ClientToolSchedule | Where-Object { $_.NAME -eq 'OldSchedule' } | ForEach-Object { Remove-ClientToolSchedule -Id $_.ID -Confirm:$false }
        Removes all schedules named 'OldSchedule' without prompting
    .EXAMPLE
        Remove-ClientToolSchedule
        Displays available schedules and prompts for ID to remove
    .EXAMPLE
        Remove-ClientToolSchedule -Syntax
        Shows the command-line help for control.schedule.remove
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)] [int]$Id,
        [Parameter()] [switch]$Syntax
    )
    
    Invoke-RemoveWithPrompt -Command 'control.schedule.remove' `
        -ItemType 'Schedule' `
        -IdentifierValue $Id `
        -GetItemsFunction { Get-ClientToolSchedule } `
        -Syntax:$Syntax
}

#endregion

#region Database Functions (MySQL, Oracle)

function Get-ClientToolMySqlServer {
    <#
    .SYNOPSIS
        Lists MySQL server entries
    .DESCRIPTION
        Retrieves configured MySQL server connection information.
        Returns details including name, username, password, and server port.
        Entry names can be used with Set-ClientToolMySqlServer or Remove-ClientToolMySqlServer.
    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)
    .PARAMETER NoHeader
        Suppress table header in output
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - NAME   : Unique entry name
        - USER   : Login username
        - PASSWD : Login password
        - SRVPORT: MySQL server port
    .NOTES
        ClientTool Command: control.mysqldb.list
        
        List existing MySQL server entries. Entry name can be used to modify or remove 
        that specific entry.
    .EXAMPLE
        Get-ClientToolMySqlServer
        Lists all MySQL server entries
    .EXAMPLE
        Get-ClientToolMySqlServer | Where-Object { $_.USER -eq 'root' }
        Lists MySQL servers using 'root' username
    .EXAMPLE
        Get-ClientToolMySqlServer -Delimiter "," -NoHeader | Out-File mysql-servers.csv
        Exports MySQL servers to CSV format
    .EXAMPLE
        Get-ClientToolMySqlServer -Syntax
        Shows the command-line help for control.mysqldb.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.mysqldb.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($PSBoundParameters.ContainsKey('Delimiter')) {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.mysqldb.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function New-ClientToolMySqlServer {
    <#
    .SYNOPSIS
        Adds a MySQL server entry
    .DESCRIPTION
        Creates a new MySQL server configuration with connection details.
        Use Get-ClientToolMySqlServer to view existing MySQL servers after creation.
    .PARAMETER Name
        Name of the MySQL server entry (required)
    .PARAMETER Password
        Password to connect to server (required)
    .PARAMETER ServerPort
        MySQL server port (required)
    .PARAMETER User
        Username to connect to server (required)
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.mysqldb.add
        
        Create new MySQL server entry.
    .EXAMPLE
        New-ClientToolMySqlServer -Name "MySQL-Main" -ServerPort 3306 -User "root" -Password "MyPass123"
        Creates a new MySQL server entry
    .EXAMPLE
        New-ClientToolMySqlServer -Name "MySQL-Secondary" -ServerPort 3307 -User "admin" -Password "SecurePass"
        Creates a MySQL server on alternate port
    .EXAMPLE
        New-ClientToolMySqlServer -Syntax
        Shows the command-line help for control.mysqldb.add
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Password,
        [Parameter(Mandatory = $true)] [int]$ServerPort,
        [Parameter(Mandatory = $true)] [string]$User,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.mysqldb.add' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-password')
    $argList.Add($Password)
    $argList.Add('-server-port')
    $argList.Add($ServerPort.ToString())
    $argList.Add('-user')
    $argList.Add($User)
    
    if ($PSCmdlet.ShouldProcess("MySQL server '$Name' on port $ServerPort", "Add")) {
        Invoke-ClientTool -Command 'control.mysqldb.add' -Arguments $argList
    }
}

function Set-ClientToolMySqlServer {
    <#
    .SYNOPSIS
        Modifies a MySQL server entry
    .DESCRIPTION
        Updates MySQL server configuration by name and port. All optional parameters will only update
        the corresponding properties if specified. If name or port are not provided, displays available
        servers and prompts for selection.
        Use Get-ClientToolMySqlServer to view existing MySQL servers.
    .PARAMETER Name
        Name of the MySQL server entry to modify
    .PARAMETER ServerPort
        Port of existing MySQL server entry to modify
    .PARAMETER NewPort
        New MySQL server port
    .PARAMETER User
        Username to connect to server
    .PARAMETER Password
        Password to connect to server
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output
    .NOTES
        ClientTool Command: control.mysqldb.modify
        
        Modify existing MySQL server entry. Entry name and port are used to locate the entry 
        to be modified. All other arguments are optional.
    .EXAMPLE
        Set-ClientToolMySqlServer -Name "MySQL-Main" -ServerPort 3306 -User "admin" -Password "newpass"
        Updates credentials for MySQL server
    .EXAMPLE
        Set-ClientToolMySqlServer -Name "MySQL-Main" -ServerPort 3306 -NewPort 3307
        Changes the port for MySQL server
    .EXAMPLE
        Set-ClientToolMySqlServer
        Displays available servers and prompts for selection
    .EXAMPLE
        Set-ClientToolMySqlServer -Syntax
        Shows the command-line help for control.mysqldb.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [string]$Name,
        [Parameter(Mandatory = $false)] [int]$ServerPort,
        [Parameter()] [int]$NewPort,
        [Parameter()] [string]$User,
        [Parameter()] [string]$Password,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.mysqldb.modify' -ShowSyntax
        return
    }
    
    # If no Name or ServerPort provided, list available MySQL servers
    if (-not $PSBoundParameters.ContainsKey('Name') -or -not $PSBoundParameters.ContainsKey('ServerPort')) {
        Write-Host "Available MySQL Servers:" -ForegroundColor Cyan
        Write-Host ""
        
        $servers = Get-ClientToolMySqlServer
        
        if (-not $servers) {
            Write-Host "No MySQL servers exist." -ForegroundColor Yellow
            return
        }
        
        $servers | Format-Table -AutoSize
        
        Write-Host "To modify a MySQL server, you must provide: -Name and -ServerPort (plus any optional parameters)" -ForegroundColor Yellow
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-server-port')
    $argList.Add($ServerPort.ToString())
    
    if ($PSBoundParameters.ContainsKey('NewPort')) {
        $argList.Add('-new-port')
        $argList.Add($NewPort.ToString())
    }
    
    if ($PSBoundParameters.ContainsKey('User')) {
        $argList.Add('-user')
        $argList.Add($User)
    }
    
    if ($PSBoundParameters.ContainsKey('Password')) {
        $argList.Add('-password')
        $argList.Add($Password)
    }
    
    if ($PSCmdlet.ShouldProcess("MySQL server '$Name' on port $ServerPort", "Modify")) {
        Invoke-ClientTool -Command 'control.mysqldb.modify' -Arguments $argList
    }
}

function Remove-ClientToolMySqlServer {
    <#
    .SYNOPSIS
        Removes a MySQL server entry
    .DESCRIPTION
        Deletes MySQL server configuration by server port.
        Use Get-ClientToolMySqlServer to view existing servers and their ports.
        If no port is provided, displays available servers and prompts for selection.
        This is a destructive operation that requires confirmation by default.
    .PARAMETER ServerPort
        Server port of the MySQL server entry to remove
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        Boolean
        Returns $true when operation completes
    .NOTES
        ClientTool Command: control.mysqldb.remove
        
        Remove existing MySQL server entry. Server port is used to locate the entry to be removed.
    .EXAMPLE
        Remove-ClientToolMySqlServer -ServerPort 3306
        Removes the MySQL server on port 3306 (prompts for confirmation)
    .EXAMPLE
        Remove-ClientToolMySqlServer -ServerPort 3306 -Confirm:$false
        Removes MySQL server without prompting
    .EXAMPLE
        Get-ClientToolMySqlServer | ForEach-Object { Remove-ClientToolMySqlServer -ServerPort $_.SRVPORT -Confirm:$false }
        Removes all MySQL server entries without prompting
    .EXAMPLE
        Remove-ClientToolMySqlServer
        Displays available servers and prompts for selection
    .EXAMPLE
        Remove-ClientToolMySqlServer -Syntax
        Shows the command-line help for control.mysqldb.remove
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)] [int]$ServerPort,
        [Parameter()] [switch]$Syntax
    )
    
    Invoke-RemoveWithPrompt -Command 'control.mysqldb.remove' `
        -ItemType 'MySQL server' `
        -IdentifierParam 'server-port' `
        -IdentifierValue $ServerPort `
        -GetItemsFunction { Get-ClientToolMySqlServer } `
        -IdentifierColumn 'PORT' `
        -Syntax:$Syntax
}

function Get-ClientToolOracleServer {
    <#
    .SYNOPSIS
        Lists Oracle server entries
    .DESCRIPTION
        Retrieves configured Oracle server connection information.
        Returns details including name, username, password, and local backup directory.
        Entry names can be used with Set-ClientToolOracleServer or Remove-ClientToolOracleServer.
    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)
    .PARAMETER NoHeader
        Suppress table header in output
    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command
    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - NAME   : Unique entry name
        - USER   : Login username
        - PASSWD : Login password
        - LOCDIR : Path to local backup directory
    .NOTES
        ClientTool Command: control.oracledb.list
        
        List existing Oracle server entries. Entry name can be used to modify or remove 
        that specific entry.
    .EXAMPLE
        Get-ClientToolOracleServer
        Lists all Oracle server entries
    .EXAMPLE
        Get-ClientToolOracleServer | Where-Object { $_.USER -eq 'system' }
        Lists Oracle servers using 'system' username
    .EXAMPLE
        Get-ClientToolOracleServer -Delimiter "," -NoHeader | Out-File oracle-servers.csv
        Exports Oracle servers to CSV format
    .EXAMPLE
        Get-ClientToolOracleServer -Syntax
        Shows the command-line help for control.oracledb.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.oracledb.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($PSBoundParameters.ContainsKey('Delimiter')) {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.oracledb.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function New-ClientToolOracleServer {
    <#
    .SYNOPSIS
        Adds an Oracle server entry

    .DESCRIPTION
        Creates a new Oracle server configuration with connection details and backup directory.
        Use Get-ClientToolOracleServer to view existing Oracle servers after creation.

    .PARAMETER LocalBackupDir
        Path to temporary directory to use during backup (required)

    .PARAMETER Name
        Name of the Oracle server entry (required)

    .PARAMETER Password
        Password to connect to server (required)

    .PARAMETER User
        Username to connect to server (required)

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.oracledb.add

        Create new Oracle server entry.
    .EXAMPLE
        New-ClientToolOracleServer -Name "ORCL" -LocalBackupDir "C:\Oracle\Backup" -User "system" -Password "MyPass123"
        Creates a new Oracle server entry
    .EXAMPLE
        New-ClientToolOracleServer -Name "ORCL-PROD" -LocalBackupDir "D:\Temp\Oracle" -User "admin" -Password "SecurePass"
        Creates an Oracle server with custom backup directory
    .EXAMPLE
        New-ClientToolOracleServer -Syntax
        Shows the command-line help for control.oracledb.add
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)] [string]$LocalBackupDir,
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Password,
        [Parameter(Mandatory = $true)] [string]$User,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.oracledb.add' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-local-backup-dir')
    $argList.Add($LocalBackupDir)
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-password')
    $argList.Add($Password)
    $argList.Add('-user')
    $argList.Add($User)
    
    if ($PSCmdlet.ShouldProcess("Oracle server '$Name'", "Add")) {
        Invoke-ClientTool -Command 'control.oracledb.add' -Arguments $argList
    }
}

function Set-ClientToolOracleServer {
    <#
    .SYNOPSIS
        Modifies an Oracle server entry

    .DESCRIPTION
        Updates Oracle server configuration by name. All optional parameters will only update
        the corresponding properties if specified. If Name or Rename are not provided, displays 
        available servers and prompts for selection.
        Use Get-ClientToolOracleServer to view existing Oracle servers.

    .PARAMETER Name
        Name of existing Oracle server entry to modify

    .PARAMETER Rename
        New name for the Oracle server entry

    .PARAMETER User
        Username to connect to server

    .PARAMETER Password
        Password to connect to server

    .PARAMETER LocalBackupDir
        Path to temporary directory to use during backup

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.oracledb.modify

        Modify existing Oracle server entry. Entry name is used to locate the entry to be modified. 
        All other arguments are optional.
    .EXAMPLE
        Set-ClientToolOracleServer -Name "ORCL" -Rename "ORCL" -User "admin" -Password "newpass"
        Updates credentials for Oracle server
    .EXAMPLE
        Set-ClientToolOracleServer -Name "ORCL-OLD" -Rename "ORCL-NEW"
        Renames Oracle server entry
    .EXAMPLE
        Set-ClientToolOracleServer
        Displays available servers and prompts for required parameters
    .EXAMPLE
        Set-ClientToolOracleServer -Syntax
        Shows the command-line help for control.oracledb.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [string]$Name,
        [Parameter(Mandatory = $false)] [string]$Rename,
        [Parameter()] [string]$User,
        [Parameter()] [string]$Password,
        [Parameter()] [string]$LocalBackupDir,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.oracledb.modify' -ShowSyntax
        return
    }
    
    # If no Name or Rename provided, list available Oracle servers
    if (-not $PSBoundParameters.ContainsKey('Name') -or -not $PSBoundParameters.ContainsKey('Rename')) {
        Write-Host "Available Oracle Servers:" -ForegroundColor Cyan
        Write-Host ""
        
        $servers = Get-ClientToolOracleServer
        
        if (-not $servers) {
            Write-Host "No Oracle servers exist." -ForegroundColor Yellow
            return
        }
        
        $servers | Format-Table -AutoSize
        
        Write-Host "To modify an Oracle server, you must provide: -Name and -Rename (plus any optional parameters)" -ForegroundColor Yellow
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-rename')
    $argList.Add($Rename)
    
    if ($PSBoundParameters.ContainsKey('User')) {
        $argList.Add('-user')
        $argList.Add($User)
    }
    
    if ($PSBoundParameters.ContainsKey('Password')) {
        $argList.Add('-password')
        $argList.Add($Password)
    }
    
    if ($PSBoundParameters.ContainsKey('LocalBackupDir')) {
        $argList.Add('-local-backup-dir')
        $argList.Add($LocalBackupDir)
    }
    
    if ($PSCmdlet.ShouldProcess("Oracle server '$Name'", "Modify")) {
        Invoke-ClientTool -Command 'control.oracledb.modify' -Arguments $argList
    }
}

function Remove-ClientToolOracleServer {
    <#
    .SYNOPSIS
        Removes an Oracle server entry

    .DESCRIPTION
        Deletes Oracle server configuration by name. If no name is provided, displays available 
        servers and prompts for selection. This is a destructive operation that requires 
        confirmation by default.
        Use Get-ClientToolOracleServer to view existing servers and their names.

    .PARAMETER Name
        Name of the Oracle server entry to remove

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        Boolean
        Returns $true when operation completes

    .NOTES
        ClientTool Command: control.oracledb.remove

        Remove existing Oracle server entry. Entry name is used to locate the entry to be removed.

    .EXAMPLE
        Remove-ClientToolOracleServer -Name "ORCL" -Confirm:$false
        Removes the Oracle server named ORCL without prompting
    .EXAMPLE
        Remove-ClientToolOracleServer
        Displays available servers and prompts for selection
    .EXAMPLE
        Get-ClientToolOracleServer | Where-Object { $_.NAME -like 'TEST*' } | ForEach-Object { Remove-ClientToolOracleServer -Name $_.NAME -Confirm:$false }
        Removes all Oracle servers starting with TEST without prompting
    .EXAMPLE
        Remove-ClientToolOracleServer -Syntax
        Shows the command-line help for control.oracledb.remove
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)] [string]$Name,
        [Parameter()] [switch]$Syntax
    )
    
    Invoke-RemoveWithPrompt -Command 'control.oracledb.remove' `
        -ItemType 'Oracle server' `
        -IdentifierParam 'name' `
        -IdentifierValue $Name `
        -GetItemsFunction { Get-ClientToolOracleServer } `
        -IdentifierColumn 'NAME' `
        -Syntax:$Syntax
}

#endregion

#region Network Share Functions

function Get-ClientToolNetworkShare {
    <#
    .SYNOPSIS
        Lists network share entries

    .DESCRIPTION
        Retrieves configured network share connection information.
        Returns details including path, domain, username, and password.
        Entry paths can be used with Set-ClientToolNetworkShare or Remove-ClientToolNetworkShare.

    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)

    .PARAMETER NoHeader
        Suppress table header in output

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - PATH   : Network share path
        - DOMAIN : Login domain
        - USER   : Login username
        - PASSWD : Login password

    .NOTES
        ClientTool Command: control.networkshare.list

        List existing network share entries. Entry path can be used to modify or remove that specific entry.
    .EXAMPLE
        Get-ClientToolNetworkShare
        Lists all network share entries
    .EXAMPLE
        Get-ClientToolNetworkShare | Where-Object { $_.DOMAIN -eq 'WORKGROUP' }
        Lists network shares in WORKGROUP domain
    .EXAMPLE
        Get-ClientToolNetworkShare -Delimiter "," -NoHeader | Out-File shares.csv
        Exports network shares to CSV format
    .EXAMPLE
        Get-ClientToolNetworkShare -Syntax
        Shows the command-line help for control.networkshare.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.networkshare.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($PSBoundParameters.ContainsKey('Delimiter')) {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.networkshare.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function New-ClientToolNetworkShare {
    <#
    .SYNOPSIS
        Adds a network share entry

    .DESCRIPTION
        Creates a new network share configuration with connection credentials.
        Use Get-ClientToolNetworkShare to view existing network shares after creation.

    .PARAMETER Domain
        Domain to use to connect to network share (required)

    .PARAMETER Path
        Path to network share (required)

    .PARAMETER User
        Username to use to connect to network share (required)

    .PARAMETER Password
        Password to use to connect to network share (optional)

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.networkshare.add

        Create new network share entry.
    .EXAMPLE
        New-ClientToolNetworkShare -Path "\\server\share" -Domain "DOMAIN" -User "admin"
        Creates a new network share entry without password
    .EXAMPLE
        New-ClientToolNetworkShare -Path "\\192.168.1.100\backup" -Domain "WORKGROUP" -User "backup" -Password "SecurePass"
        Creates a network share with password authentication
    .EXAMPLE
        New-ClientToolNetworkShare -Syntax
        Shows the command-line help for control.networkshare.add
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)] [string]$Domain,
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$User,
        [Parameter()] [string]$Password,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.networkshare.add' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-domain')
    $argList.Add($Domain)
    $argList.Add('-path')
    $argList.Add($Path)
    $argList.Add('-user')
    $argList.Add($User)
    
    if ($PSBoundParameters.ContainsKey('Password')) {
        $argList.Add('-password')
        $argList.Add($Password)
    }
    
    if ($PSCmdlet.ShouldProcess("Network share '$Path'", "Add")) {
        Invoke-ClientTool -Command 'control.networkshare.add' -Arguments $argList
    }
}

function Set-ClientToolNetworkShare {
    <#
    .SYNOPSIS
        Modifies a network share entry

    .DESCRIPTION
        Updates network share configuration by path. All optional parameters will only update
        the corresponding properties if specified. If Path is not provided, displays available 
        shares and prompts for selection.
        Use Get-ClientToolNetworkShare to view existing network shares.

    .PARAMETER Path
        Path of existing network share entry to modify

    .PARAMETER NewPath
        New path to network share

    .PARAMETER Domain
        Domain to use to connect to network share

    .PARAMETER User
        Username to use to connect to network share

    .PARAMETER Password
        Password to use to connect to network share

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.networkshare.modify

        Modify existing network share entry. Entry path is used to locate the entry to be modified. 
        All other arguments are optional.
    .EXAMPLE
        Set-ClientToolNetworkShare -Path "\\server\share" -User "admin" -Password "newpass"
        Updates credentials for network share
    .EXAMPLE
        Set-ClientToolNetworkShare -Path "\\oldserver\share" -NewPath "\\newserver\share"
        Changes the path for network share
    .EXAMPLE
        Set-ClientToolNetworkShare
        Displays available shares and prompts for parameters
    .EXAMPLE
        Set-ClientToolNetworkShare -Syntax
        Shows the command-line help for control.networkshare.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [string]$Path,
        [Parameter()] [string]$NewPath,
        [Parameter()] [string]$Domain,
        [Parameter()] [string]$User,
        [Parameter()] [string]$Password,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.networkshare.modify' -ShowSyntax
        return
    }
    
    # If no Path provided, list available network shares
    if (-not $PSBoundParameters.ContainsKey('Path')) {
        Write-Host "Available Network Shares:" -ForegroundColor Cyan
        Write-Host ""
        
        $shares = Get-ClientToolNetworkShare
        
        if (-not $shares) {
            Write-Host "No network shares exist." -ForegroundColor Yellow
            return
        }
        
        $shares | Format-Table -AutoSize
        
        Write-Host "To modify a network share, you must provide: -Path (plus any optional parameters)" -ForegroundColor Yellow
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-path')
    $argList.Add($Path)
    
    if ($PSBoundParameters.ContainsKey('NewPath')) {
        $argList.Add('-new-path')
        $argList.Add($NewPath)
    }
    
    if ($PSBoundParameters.ContainsKey('Domain')) {
        $argList.Add('-domain')
        $argList.Add($Domain)
    }
    
    if ($PSBoundParameters.ContainsKey('User')) {
        $argList.Add('-user')
        $argList.Add($User)
    }
    
    if ($PSBoundParameters.ContainsKey('Password')) {
        $argList.Add('-password')
        $argList.Add($Password)
    }
    
    if ($PSCmdlet.ShouldProcess("Network share '$Path'", "Modify")) {
        Invoke-ClientTool -Command 'control.networkshare.modify' -Arguments $argList
    }
}

function Remove-ClientToolNetworkShare {
    <#
    .SYNOPSIS
        Removes a network share entry

    .DESCRIPTION
        Deletes network share configuration by path. If no path is provided, displays available 
        shares and prompts for selection. This is a destructive operation that requires 
        confirmation by default.
        Use Get-ClientToolNetworkShare to view existing network shares and their paths.

    .PARAMETER Path
        Path of the network share entry to remove

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        Boolean
        Returns $true when operation completes

    .NOTES
        ClientTool Command: control.networkshare.remove

        Remove existing network share entry. Path is used to locate the entry to be removed.

    .EXAMPLE
        Remove-ClientToolNetworkShare -Path "\\server\share" -Confirm:$false
        Removes the network share at \\server\share without prompting
    .EXAMPLE
        Remove-ClientToolNetworkShare
        Displays available shares and prompts for selection
    .EXAMPLE
        Get-ClientToolNetworkShare | Where-Object { $_.PATH -like '\\oldserver*' } | ForEach-Object { Remove-ClientToolNetworkShare -Path $_.PATH -Confirm:$false }
        Removes all shares on oldserver without prompting
    .EXAMPLE
        Remove-ClientToolNetworkShare -Syntax
        Shows the command-line help for control.networkshare.remove
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)] [string]$Path,
        [Parameter()] [switch]$Syntax
    )
    
    Invoke-RemoveWithPrompt -Command 'control.networkshare.remove' `
        -ItemType 'Network share' `
        -IdentifierParam 'path' `
        -IdentifierValue $Path `
        -GetItemsFunction { Get-ClientToolNetworkShare } `
        -IdentifierColumn 'PATH' `
        -Syntax:$Syntax
}

#endregion

#region Filter Functions

function Get-ClientToolFilter {
    <#
    .SYNOPSIS
        Lists FileSystem datasource filters

    .DESCRIPTION
        Retrieves configured file system filter masks.
        Returns a list of file patterns to exclude from backup (e.g., *.tmp, *.cache).
        Use Set-ClientToolFilter to add or remove filter masks.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        String[]
        Returns array of filter mask patterns

    .NOTES
        ClientTool Command: control.filter.list

        List FileSystem datasource filters. Produces a list with one filter mask per line.

    .EXAMPLE
        Get-ClientToolFilter
        Lists all configured filter masks
    .EXAMPLE
        Get-ClientToolFilter | Where-Object { $_ -like '*.tmp' }
        Checks if *.tmp filter exists
    .EXAMPLE
        Get-ClientToolFilter -Syntax
        Shows the command-line help for control.filter.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.filter.list' -ShowSyntax
        return
    }
    
    $output = Invoke-ClientTool -Command 'control.filter.list' -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function Set-ClientToolFilter {
    <#
    .SYNOPSIS
        Modifies filters for FileSystem datasource

    .DESCRIPTION
        Adds or removes file system filter masks to control which files are excluded from backup.
        Already existing filters will not be duplicated, and already missing filters will not be removed.
        If the same filter mask is specified with both -Add and -Remove, it will be added.
        Use Get-ClientToolFilter to view existing filters.

    .PARAMETER Add
        Filter mask(s) to add (e.g., "*.txt", "*.docx")

    .PARAMETER Remove
        Filter mask(s) to remove (e.g., "*.mp3", "*.avi")

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.filter.modify

        Modify filters for FileSystem datasource. Already existing filters will not be added, 
        already missing filters will not be removed.
    .EXAMPLE
        Set-ClientToolFilter -Add "*.tmp","*.bak"
        Adds filter masks for temporary and backup files
    .EXAMPLE
        Set-ClientToolFilter -Remove "*.mp3","*.avi"
        Removes filter masks for media files
    .EXAMPLE
        Set-ClientToolFilter -Add "*.log" -Remove "*.old"
        Adds log filter and removes old filter in one operation
    .EXAMPLE
        Get-ClientToolFilter
        Set-ClientToolFilter -Add "*.cache"
        Lists existing filters then adds a new one
    .EXAMPLE
        Set-ClientToolFilter -Syntax
        Shows the command-line help for control.filter.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]        [string[]]$Add,
        [Parameter()]        [string[]]$Remove,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.filter.modify' -ShowSyntax
        return
    }
    
    # If no parameters provided, show current filters and usage
    if (-not $PSBoundParameters.ContainsKey('Add') -and -not $PSBoundParameters.ContainsKey('Remove')) {
        Write-Host "Current FileSystem Filters:" -ForegroundColor Cyan
        Write-Host ""
        
        $filters = Get-ClientToolFilter
        
        if (-not $filters) {
            Write-Host "No filters exist." -ForegroundColor Yellow
        } else {
            $filters | ForEach-Object { Write-Host "  $_" }
        }
        
        Write-Host ""
        Write-Host "To modify filters, use:" -ForegroundColor Yellow
        Write-Host "  Set-ClientToolFilter -Add '*.ext1','*.ext2'" -ForegroundColor Gray
        Write-Host "  Set-ClientToolFilter -Remove '*.ext1','*.ext2'" -ForegroundColor Gray
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($PSBoundParameters.ContainsKey('Add')) {
        foreach ($mask in $Add) {
            $argList.Add('-add')
            $argList.Add($mask)
        }
    }
    
    if ($PSBoundParameters.ContainsKey('Remove')) {
        foreach ($mask in $Remove) {
            $argList.Add('-remove')
            $argList.Add($mask)
        }
    }
    
    if ($PSCmdlet.ShouldProcess("FileSystem filters", "Modify")) {
        Invoke-ClientTool -Command 'control.filter.modify' -Arguments $argList
    }
}

#endregion

#region Script Functions

function Get-ClientToolScript {
    <#
    .SYNOPSIS
        Lists configured scripts

    .DESCRIPTION
        Retrieves custom scripts configured in Backup Manager for pre/post backup operations.
        Returns details including ID, name, user context, timeout, and error handling settings.
        Script IDs can be used with Set-ClientToolScript or Remove-ClientToolScript.

    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)

    .PARAMETER NoHeader
        Suppress the header row in output

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - ID    : Unique script identifier
        - NAME  : Script name
        - USER  : User to run script as
        - PASWD : User password
        - TOUT  : Execution timeout
        - FAIL  : Fail backup on error

    .NOTES
        ClientTool Command: control.script.list

        List existing scripts. Script ID can be used to modify or remove that specific script.

    .EXAMPLE
        Get-ClientToolScript
        Lists all configured scripts
    .EXAMPLE
        Get-ClientToolScript | Where-Object { $_.FAIL -eq '1' }
        Lists scripts that fail backup on error
    .EXAMPLE
        Get-ClientToolScript -Delimiter "," -NoHeader | Out-File scripts.csv
        Exports scripts to CSV format
    .EXAMPLE
        Get-ClientToolScript -Syntax
        Shows the command-line help for control.script.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.script.list' -ShowSyntax
        return
    }
    
    $arguments = @()
    if ($Delimiter) { $arguments += "-delimiter `"$Delimiter`"" }
    if ($NoHeader) { $arguments += "-noheader" }
    
    $output = Invoke-ClientTool -Command 'control.script.list' -Arguments $arguments -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function New-ClientToolScript {
    <#
    .SYNOPSIS
        Creates a new script

    .DESCRIPTION
        Adds a custom script configuration that can be used as pre- or post-backup action.
        Scripts can be associated with schedules to execute before or after backups.
        Use Get-ClientToolScript to view existing scripts and their IDs.

    .PARAMETER ContentFile
        Path to file containing the script body (required)

    .PARAMETER Name
        Name of the script (required)

    .PARAMETER Password
        System user password (required)

    .PARAMETER User
        System user to run script as (required)

    .PARAMETER FailSessionOnError
        Whether backup session should fail on script error when used as pre-backup action (0 = do not fail, 1 = fail). Default is 0

    .PARAMETER Timeout
        Execution timeout in seconds. Default is 0 (no timeout)

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.script.add

        Create new script. Scripts can be used with schedules as pre- and post-backup actions.
    .EXAMPLE
        New-ClientToolScript -ContentFile "C:\scripts\pre-backup.ps1" -Name "Pre-Backup Check" -User "Administrator" -Password "MyPass123"
        Creates a new script from file
    .EXAMPLE
        New-ClientToolScript -ContentFile "C:\scripts\post.bat" -Name "Post-Backup" -User "SYSTEM" -Password "" -Timeout 300
        Creates a script with 5 minute timeout
    .EXAMPLE
        New-ClientToolScript -ContentFile "C:\scripts\check.ps1" -Name "Validation" -User "admin" -Password "pass" -FailSessionOnError 1
        Creates a pre-backup script that will fail the session on error
    .EXAMPLE
        New-ClientToolScript -Syntax
        Shows the command-line help for control.script.add
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='Default')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName='Default')] [string]$ContentFile,
        [Parameter(Mandatory = $true, ParameterSetName='Default')] [string]$Name,
        [Parameter(Mandatory = $true, ParameterSetName='Default')] [string]$Password,
        [Parameter(Mandatory = $true, ParameterSetName='Default')] [string]$User,
        [Parameter(ParameterSetName='Default')]        [ValidateRange(0, 1)]
        [int]$FailSessionOnError = 0,
        [Parameter(ParameterSetName='Default')] [int]$Timeout = 0,
        [Parameter(ParameterSetName='Syntax')] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.script.add' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-content-file')
    $argList.Add($ContentFile)
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-password')
    $argList.Add($Password)
    $argList.Add('-user')
    $argList.Add($User)
    $argList.Add('-fail-session-on-error')
    $argList.Add($FailSessionOnError.ToString())
    $argList.Add('-timeout')
    $argList.Add($Timeout.ToString())
    
    if ($PSCmdlet.ShouldProcess("Script '$Name'", "Create")) {
        Invoke-ClientTool -Command 'control.script.add' -Arguments $argList
    }
}

function Set-ClientToolScript {
    <#
    .SYNOPSIS
        Modifies an existing script

    .DESCRIPTION
        Updates script configuration by ID. All optional parameters will only update
        the corresponding properties if specified. If ID is not provided, displays available 
        scripts and prompts for selection. User and Password are required parameters.
        Use Get-ClientToolScript to view existing scripts and their IDs.

    .PARAMETER Id
        ID of the script to modify

    .PARAMETER Password
        System user password (required when modifying)

    .PARAMETER User
        System user to run script as (required when modifying)

    .PARAMETER ContentFile
        Path to file containing the script body

    .PARAMETER Name
        Name of the script

    .PARAMETER FailSessionOnError
        Whether backup session should fail on script error when used as pre-backup action (0 = do not fail, 1 = fail)

    .PARAMETER Timeout
        Execution timeout in seconds (0 = no timeout)

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.script.modify

        Modify existing script. Script ID is used to locate the script to be modified. 
        All other arguments are optional.
    .EXAMPLE
        Set-ClientToolScript -Id 1 -User "Administrator" -Password "MyPass123" -Name "Updated Script"
        Updates script ID 1 with new name
    .EXAMPLE
        Set-ClientToolScript -Id 1 -User "SYSTEM" -Password "" -ContentFile "C:\scripts\backup.ps1"
        Updates script content from file
    .EXAMPLE
        Set-ClientToolScript
        Displays available scripts and usage information
    .EXAMPLE
        Set-ClientToolScript -Syntax
        Shows the command-line help for control.script.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [int]$Id,
        [Parameter(Mandatory = $false)] [string]$Password,
        [Parameter(Mandatory = $false)] [string]$User,
        [Parameter()] [string]$ContentFile,
        [Parameter()] [string]$Name,
        [Parameter()]        [ValidateRange(0, 1)]
        [int]$FailSessionOnError,
        [Parameter()] [int]$Timeout,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.script.modify' -ShowSyntax
        return
    }
    
    # If no ID provided, list available scripts
    if (-not $PSBoundParameters.ContainsKey('Id')) {
        Write-Host "Available Scripts:" -ForegroundColor Cyan
        Write-Host ""
        
        $scripts = Get-ClientToolScript
        
        if (-not $scripts) {
            Write-Host "No scripts exist." -ForegroundColor Yellow
            return
        }
        
        $scripts | Format-Table -AutoSize
        
        Write-Host "To modify a script, you must provide: -Id, -User, and -Password (plus any optional parameters)" -ForegroundColor Yellow
        return
    }
    
    # User and Password are required by ClientTool
    if (-not $PSBoundParameters.ContainsKey('User') -or -not $PSBoundParameters.ContainsKey('Password')) {
        Write-Host "Error: -User and -Password are required parameters for Set-ClientToolScript" -ForegroundColor Red
        Write-Host "Example: Set-ClientToolScript -Id $Id -User 'Administrator' -Password 'YourPassword'" -ForegroundColor Yellow
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-id')
    $argList.Add($Id.ToString())
    $argList.Add('-user')
    $argList.Add($User)
    $argList.Add('-password')
    $argList.Add($Password)
    
    if ($PSBoundParameters.ContainsKey('ContentFile')) {
        $argList.Add('-content-file')
        $argList.Add($ContentFile)
    }
    
    if ($PSBoundParameters.ContainsKey('Name')) {
        $argList.Add('-name')
        $argList.Add($Name)
    }
    
    if ($PSBoundParameters.ContainsKey('FailSessionOnError')) {
        $argList.Add('-fail-session-on-error')
        $argList.Add($FailSessionOnError.ToString())
    }
    
    if ($PSBoundParameters.ContainsKey('Timeout')) {
        $argList.Add('-timeout')
        $argList.Add($Timeout.ToString())
    }
    
    if ($PSCmdlet.ShouldProcess("Script ID $Id", "Modify")) {
        Invoke-ClientTool -Command 'control.script.modify' -Arguments $argList
    }
}

function Remove-ClientToolScript {
    <#
    .SYNOPSIS
        Removes a script

    .DESCRIPTION
        Deletes script configuration by ID. If no ID is provided, displays available 
        scripts and prompts for selection. This is a destructive operation that requires 
        confirmation by default.
        Use Get-ClientToolScript to view existing scripts and their IDs.

    .PARAMETER Id
        ID of the script to remove

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        Boolean
        Returns $true when operation completes

    .NOTES
        ClientTool Command: control.script.remove

        Remove existing script. Script ID is used to locate the script to be removed.

    .EXAMPLE
        Remove-ClientToolScript -Id 3 -Confirm:$false
        Removes the script with ID 3
    .EXAMPLE
        Get-ClientToolScript | Where-Object { $_.NAME -like '*old*' } | ForEach-Object { Remove-ClientToolScript -Id $_.ID }
        Removes scripts with 'old' in the name
    .EXAMPLE
        Remove-ClientToolScript -Syntax
        Shows the command-line help for control.script.remove
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)] [int]$Id,
        [Parameter()] [switch]$Syntax
    )
    
    Invoke-RemoveWithPrompt -Command 'control.script.remove' `
        -ItemType 'Script' `
        -IdentifierValue $Id `
        -GetItemsFunction { Get-ClientToolScript } `
        -Syntax:$Syntax
}

#endregion

#region Archiving Functions

function Get-ClientToolArchivingRule {
    <#
    .SYNOPSIS
        Lists archiving rules

    .DESCRIPTION
        Retrieves configured archiving rules with scheduling and datasource information.
        Returns details including ID, active status, name, datasources, time, and schedule patterns.
        Rule IDs can be used with Set-ClientToolArchivingRule or Remove-ClientToolArchivingRule.

    .PARAMETER Delimiter
        Field delimiter for machine-readable output (default: TAB)

    .PARAMETER NoHeader
        Suppress table header in output

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        PSCustomObject
        Returns objects with the following properties:
        - ID     : Unique archiving rule identifier
        - ACTV   : Is rule active or not
        - NAME   : Archiving rule name
        - DSRC   : Datasources to archive
        - TIME   : Time archiving will fire at
        - MONTHS : Months archiving will fire in
        - MDAYS  : Days of month archiving will fire on
        - WEEKS  : Weeks archiving will fire on
        - WDAYS  : Days of week archiving will fire on

    .NOTES
        ClientTool Command: control.archiving.list

        List existing archiving rules. Rule ID can be used to modify or remove that specific rule.
    .EXAMPLE
        Get-ClientToolArchivingRule
        Lists all archiving rules
    .EXAMPLE
        Get-ClientToolArchivingRule | Where-Object { $_.ACTV -eq '1' }
        Lists only active archiving rules
    .EXAMPLE
        Get-ClientToolArchivingRule -Delimiter "," -NoHeader | Out-File archive-rules.csv
        Exports archiving rules to CSV format
    .EXAMPLE
        Get-ClientToolArchivingRule -Syntax
        Shows the command-line help for control.archiving.list
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Delimiter,
        [Parameter()] [switch]$NoHeader,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.archiving.list' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($PSBoundParameters.ContainsKey('Delimiter')) {
        $argList.Add('-delimiter')
        $argList.Add($Delimiter)
    }
    
    if ($NoHeader) {
        $argList.Add('-no-header')
    }
    
    $output = Invoke-ClientTool -Command 'control.archiving.list' -Arguments $argList -MachineReadable
    
    if ($output) {
        $output | ConvertFrom-ClientToolTable
    }
}

function New-ClientToolArchivingRule {
    <#
    .SYNOPSIS
        Creates a new archiving rule

    .DESCRIPTION
        Adds an archiving rule configuration to automatically archive old backup data based on schedule.
        Rules define when and what datasources to archive using flexible scheduling options.
        Use Get-ClientToolArchivingRule to view existing archiving rules and their IDs.

    .PARAMETER Name
        Name of the archiving rule (required)

    .PARAMETER Active
        Whether the rule is active (0 = inactive, 1 = active). Default is 1

    .PARAMETER Time
        Time for rule activation in format hh:mm (e.g., "14:30"). Default is 00:00

    .PARAMETER DataSources
        Datasources to archive. Possible values: Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint, All. Default is All

    .PARAMETER DayOfWeek
        Day of week when rule is active. Must be used with -Weeks parameter

    .PARAMETER DaysOfMonth
        Day or range of days when rule is active (e.g., "2,[5-10],20,Last"). Default is [1-31]. Mutually exclusive with DayOfWeek and Weeks

    .PARAMETER Weeks
        Weeks when rule is active. Possible values: 1, 2, 3, 4, Last, All. Must be used with -DayOfWeek parameter

    .PARAMETER Months
        Months when rule is active. Possible values: Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec, All. Default is All

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.archiving.add

        Create new archiving rule.
    .EXAMPLE
        New-ClientToolArchivingRule -Name "Monthly Archive"
        Creates a basic monthly archiving rule with defaults
    .EXAMPLE
        New-ClientToolArchivingRule -Name "Weekly SQL" -DataSources VssMsSql -DayOfWeek Friday -Weeks 1,2,3,4,Last -Time "23:00"
        Creates a weekly SQL archiving rule for every Friday at 11:00 PM
    .EXAMPLE
        New-ClientToolArchivingRule -Name "Month End" -DaysOfMonth Last -Time "00:00"
        Creates an archiving rule that runs on the last day of each month
    .EXAMPLE
        New-ClientToolArchivingRule -Syntax
        Shows the command-line help for control.archiving.add
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()] [string]$Name,
        [Parameter()]        [ValidateRange(0, 1)]
        [int]$Active = 1,
        [Parameter()]        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$Time = "00:00",
        [Parameter()]        [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint', 'All')]
        [string[]]$DataSources = @('All'),
        [Parameter()]        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
        [string]$DayOfWeek,
        [Parameter()] [string]$DaysOfMonth,
        [Parameter()]        [ValidateSet('1', '2', '3', '4', 'Last', 'All')]
        [string[]]$Weeks,
        [Parameter()]        [ValidateSet('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'All')]
        [string[]]$Months = @('All'),
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.archiving.add' -ShowSyntax
        return
    }
    
    # Validate required Name parameter
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host "`nArchiving Rule Creation Help" -ForegroundColor Cyan
        Write-Host "=" * 70 -ForegroundColor Gray
        Write-Host "`nThe -Name parameter is required to create an archiving rule.`n" -ForegroundColor Yellow
        Write-Host "Usage Examples:" -ForegroundColor White
        Write-Host "  New-ClientToolArchivingRule -Name 'Weekly Archive' -DayOfWeek Friday -Weeks All" -ForegroundColor Green
        Write-Host "  New-ClientToolArchivingRule -Name 'Monthly' -DaysOfMonth '1,15,Last'" -ForegroundColor Green
        Write-Host "  New-ClientToolArchivingRule -Syntax  (show detailed help)`n" -ForegroundColor Green
        throw "Parameter -Name is required. Provide a name for the archiving rule."
    }
    
    # Validate mutually exclusive parameters
    if ($PSBoundParameters.ContainsKey('DaysOfMonth') -and 
        ($PSBoundParameters.ContainsKey('DayOfWeek') -or $PSBoundParameters.ContainsKey('Weeks'))) {
        throw "Parameter -DaysOfMonth is mutually exclusive with -DayOfWeek and -Weeks parameters"
    }
    
    # Validate DayOfWeek and Weeks are used together
    if ($PSBoundParameters.ContainsKey('DayOfWeek') -and -not $PSBoundParameters.ContainsKey('Weeks')) {
        throw "Parameter -DayOfWeek requires -Weeks parameter to be specified"
    }
    
    if ($PSBoundParameters.ContainsKey('Weeks') -and -not $PSBoundParameters.ContainsKey('DayOfWeek')) {
        throw "Parameter -Weeks requires -DayOfWeek parameter to be specified"
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-name')
    $argList.Add($Name)
    $argList.Add('-active')
    $argList.Add($Active.ToString())
    $argList.Add('-time')
    $argList.Add($Time)
    $argList.Add('-datasources')
    $argList.Add(($DataSources -join ','))
    $argList.Add('-months')
    $argList.Add(($Months -join ','))
    
    if ($PSBoundParameters.ContainsKey('DayOfWeek')) {
        $argList.Add('-day-of-week')
        $argList.Add($DayOfWeek)
    }
    
    if ($PSBoundParameters.ContainsKey('DaysOfMonth')) {
        $argList.Add('-days-of-month')
        $argList.Add($DaysOfMonth)
    }
    
    if ($PSBoundParameters.ContainsKey('Weeks')) {
        $argList.Add('-weeks')
        $argList.Add(($Weeks -join ','))
    }
    
    if ($PSCmdlet.ShouldProcess("Archiving rule '$Name'", "Create")) {
        $output = Invoke-ClientTool -Command 'control.archiving.add' -Arguments $argList
        
        # Parse the ID from the output and display the created rule
        if ($output -match 'Archiving rule with ID #(\d+) successfully created') {
            $newId = [int]$Matches[1]
            Write-Host $output -ForegroundColor Green
            Write-Host "`nRetrieving created archiving rule details..." -ForegroundColor Cyan
            
            # Get and display the newly created rule
            $newRule = Get-ClientToolArchivingRule | Where-Object { $_.ID -eq $newId }
            if ($newRule) {
                Write-Host ""
                $newRule | Format-Table -AutoSize
            }
        }
        else {
            # If we couldn't parse the ID, just show the output
            Write-Output $output
        }
    }
}

function Set-ClientToolArchivingRule {
    <#
    .SYNOPSIS
        Modifies an archiving rule

    .DESCRIPTION
        Updates archiving rule configuration by ID. All optional parameters will only update
        the corresponding properties if specified. If ID is not provided, displays available 
        rules and prompts for selection.
        Use Get-ClientToolArchivingRule to view existing rules and their IDs.

    .PARAMETER Id
        ID of the archiving rule to modify

    .PARAMETER Active
        Whether the rule is active (0 = inactive, 1 = active)

    .PARAMETER Name
        Name of the archiving rule

    .PARAMETER Time
        Time for rule activation in format hh:mm (e.g., "14:30")

    .PARAMETER DataSources
        Datasources to archive. Possible values: Exchange, FileSystem, MySql, NetworkShares, Oracle, SystemState, VMware, VssHyperV, VssMsSql, VssSharePoint, All

    .PARAMETER DayOfWeek
        Day of week when rule is active. Mutually exclusive with DaysOfMonth

    .PARAMETER DaysOfMonth
        Day or range of days when rule is active (e.g., "2,[5-10],20,Last"). Mutually exclusive with DayOfWeek and Weeks

    .PARAMETER Weeks
        Weeks when rule is active. Possible values: 1, 2, 3, 4, Last, All

    .PARAMETER Months
        Months when rule is active. Possible values: Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec, All

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.archiving.modify

        Modify existing archiving rule. Rule ID is used to locate the rule to be modified. 
        All other arguments are optional.
    .EXAMPLE
        Set-ClientToolArchivingRule -Id 602 -Active 1
        Activates archiving rule ID 602
    .EXAMPLE
        Set-ClientToolArchivingRule -Id 602 -Name "Monthly SQL" -Time "23:00"
        Renames rule and changes time to 11:00 PM
    .EXAMPLE
        Set-ClientToolArchivingRule -Id 602 -DayOfWeek Friday -Weeks 1,2,3,4,Last
        Sets rule to run every Friday
    .EXAMPLE
        Set-ClientToolArchivingRule
        Displays available rules and prompts for selection
    .EXAMPLE
        Set-ClientToolArchivingRule -Syntax
        Shows the command-line help for control.archiving.modify
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [int]$Id,
        [Parameter()]        [ValidateRange(0, 1)]
        [int]$Active,
        [Parameter()] [string]$Name,
        [Parameter()]        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$Time,
        [Parameter()]        [ValidateSet('Exchange', 'FileSystem', 'MySql', 'NetworkShares', 'Oracle', 'SystemState', 'VMware', 'VssHyperV', 'VssMsSql', 'VssSharePoint', 'All')]
        [string[]]$DataSources,
        [Parameter()]        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
        [string]$DayOfWeek,
        [Parameter()] [string]$DaysOfMonth,
        [Parameter()]        [ValidateSet('1', '2', '3', '4', 'Last', 'All')]
        [string[]]$Weeks,
        [Parameter()]        [ValidateSet('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'All')]
        [string[]]$Months,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.archiving.modify' -ShowSyntax
        return
    }
    
    # If no ID provided, list available archiving rules
    if (-not $PSBoundParameters.ContainsKey('Id')) {
        Write-Host "Available Archiving Rules:" -ForegroundColor Cyan
        Write-Host ""
        
        $rules = Get-ClientToolArchivingRule
        
        if (-not $rules) {
            Write-Host "No archiving rules exist." -ForegroundColor Yellow
            return
        }
        
        $rules | Format-Table -AutoSize
        
        # Prompt for ID
        $Id = Read-Host "Enter the Archiving Rule ID to modify (or press Enter to cancel)"
        if ([string]::IsNullOrWhiteSpace($Id)) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
        
        # Validate the entered ID exists
        if ($rules.ID -notcontains [int]$Id) {
            Write-Host "Archiving Rule ID $Id not found." -ForegroundColor Red
            return
        }
    }
    
    # Validate mutually exclusive parameters
    if ($PSBoundParameters.ContainsKey('DaysOfMonth') -and 
        ($PSBoundParameters.ContainsKey('DayOfWeek') -or $PSBoundParameters.ContainsKey('Weeks'))) {
        throw "Parameter -DaysOfMonth is mutually exclusive with -DayOfWeek and -Weeks parameters"
    }
    
    # Validate DayOfWeek and Weeks are used together (only if modifying scheduling)
    if ($PSBoundParameters.ContainsKey('DayOfWeek') -and $PSBoundParameters.ContainsKey('Weeks') -eq $false) {
        Write-Warning "Parameter -DayOfWeek should be used with -Weeks parameter for complete schedule modification"
    }
    
    if ($PSBoundParameters.ContainsKey('Weeks') -and $PSBoundParameters.ContainsKey('DayOfWeek') -eq $false) {
        Write-Warning "Parameter -Weeks should be used with -DayOfWeek parameter for complete schedule modification"
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-id')
    $argList.Add($Id.ToString())
    
    if ($PSBoundParameters.ContainsKey('Active')) {
        $argList.Add('-active')
        $argList.Add($Active.ToString())
    }
    
    if ($PSBoundParameters.ContainsKey('Name')) {
        $argList.Add('-name')
        $argList.Add($Name)
    }
    
    if ($PSBoundParameters.ContainsKey('Time')) {
        $argList.Add('-time')
        $argList.Add($Time)
    }
    
    if ($PSBoundParameters.ContainsKey('DataSources')) {
        $argList.Add('-datasources')
        $argList.Add(($DataSources -join ','))
    }
    
    if ($PSBoundParameters.ContainsKey('DayOfWeek')) {
        $argList.Add('-day-of-week')
        $argList.Add($DayOfWeek)
    }
    
    if ($PSBoundParameters.ContainsKey('DaysOfMonth')) {
        $argList.Add('-days-of-month')
        $argList.Add($DaysOfMonth)
    }
    
    if ($PSBoundParameters.ContainsKey('Weeks')) {
        $argList.Add('-weeks')
        $argList.Add(($Weeks -join ','))
    }
    
    if ($PSBoundParameters.ContainsKey('Months')) {
        $argList.Add('-months')
        $argList.Add(($Months -join ','))
    }
    
    if ($PSCmdlet.ShouldProcess("Archiving rule ID $Id", "Modify")) {
        Invoke-ClientTool -Command 'control.archiving.modify' -Arguments $argList
    }
}

function Remove-ClientToolArchivingRule {
    <#
    .SYNOPSIS
        Removes an archiving rule

    .DESCRIPTION
        Deletes archiving rule configuration by ID. If no ID is provided, displays available 
        rules and prompts for selection. This is a destructive operation that requires 
        confirmation by default.
        Use Get-ClientToolArchivingRule to view existing rules and their IDs.

    .PARAMETER Id
        ID of the archiving rule to remove

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        Boolean
        Returns $true when operation completes

    .NOTES
        ClientTool Command: control.archiving.remove

        Remove existing archiving rule. Rule ID is used to locate the rule to be removed.

    .EXAMPLE
        Remove-ClientToolArchivingRule -Id 2 -Confirm:$false
        Removes the archiving rule with ID 2 without prompting
    .EXAMPLE
        Remove-ClientToolArchivingRule
        Displays available rules and prompts for selection
    .EXAMPLE
        Get-ClientToolArchivingRule | Where-Object { $_.ACTV -eq 0 } | ForEach-Object { Remove-ClientToolArchivingRule -Id $_.ID -Confirm:$false }
        Removes all inactive archiving rules without prompting
    .EXAMPLE
        Remove-ClientToolArchivingRule -Syntax
        Shows the command-line help for control.archiving.remove
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)] [int]$Id,
        [Parameter()] [switch]$Syntax
    )
    
    Invoke-RemoveWithPrompt -Command 'control.archiving.remove' `
        -ItemType 'Archiving rule' `
        -IdentifierValue $Id `
        -GetItemsFunction { Get-ClientToolArchivingRule } `
        -Syntax:$Syntax
}

#endregion

#region Miscellaneous Functions

function Open-ClientToolUI {
    <#
    .SYNOPSIS
        Opens Backup Manager UI in default browser

    .DESCRIPTION
        Launches the Backup Manager web interface in your default browser.
        Opens the local management console for monitoring and controlling backups.

    .PARAMETER ConfigPath
        Full path to config.ini file. Optional - defaults to 'C:\Program Files\Backup Manager\config.ini' if not specified.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: bm-ui.open

        Open Backup Manager User Interface in a default browser.

    .EXAMPLE
        Open-ClientToolUI
        Opens the Backup Manager UI in default browser
    .EXAMPLE
        Open-ClientToolUI -ConfigPath "C:\Program Files\Backup Manager\config.ini"
        Opens UI using a specific config file
    .EXAMPLE
        Open-ClientToolUI -Syntax
        Shows the command-line help for bm-ui.open
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$ConfigPath = 'C:\Program Files\Backup Manager\config.ini',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'bm-ui.open' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($ConfigPath) {
        $argList.Add('-config-path')
        $argList.Add($ConfigPath)
    }
    
    Invoke-ClientTool -Command 'bm-ui.open' -Arguments $argList
}

function Reset-ClientToolDashboardEmail {
    <#
    .SYNOPSIS
        Resets dashboard email subscription

    .DESCRIPTION
        Unsubscribes from dashboard email notifications.
        Disables dashboard generation typically used after device uninstall.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.dashboard.unsubscribe

        Reset dashboard email. Disables dashboard generation after device uninstall.

    .EXAMPLE
        Reset-ClientToolDashboardEmail
        Unsubscribes from dashboard emails
    .EXAMPLE
        Reset-ClientToolDashboardEmail -Confirm:$false
        Unsubscribes without prompting
    .EXAMPLE
        Reset-ClientToolDashboardEmail -Syntax
        Shows the command-line help for control.dashboard.unsubscribe
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.dashboard.unsubscribe' -ShowSyntax
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Dashboard email", "Unsubscribe")) {
        Invoke-ClientTool -Command 'control.dashboard.unsubscribe'
    }
}

function Get-ClientToolAuthToken {
    <#
    .SYNOPSIS
        Gets InAgent authentication token

    .DESCRIPTION
        Retrieves an authentication token that can be exchanged with BackupFP API.
        Token can be used with /jsonrpcv1 method InAgentAuthenticationTokenLogin.

    .PARAMETER ConfigPath
        Full path to config.ini file. Optional - defaults to 'C:\Program Files\Backup Manager\config.ini' if not specified.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        String[]
        Returns authentication token

    .NOTES
        ClientTool Command: in-agent-authentication-token.get

        Gets InAgentAuthentication token which can be exchanged with BackupFP API.

    .EXAMPLE
        Get-ClientToolAuthToken -ConfigPath "C:\Program Files\Backup Manager\config.ini"
        Retrieves authentication token for API use
    .EXAMPLE
        $token = Get-ClientToolAuthToken -ConfigPath "C:\Program Files\Backup Manager\config.ini"
        Stores the token in a variable for API calls
    .EXAMPLE
        Get-ClientToolAuthToken -Syntax
        Shows the command-line help for in-agent-authentication-token.get
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$ConfigPath = 'C:\Program Files\Backup Manager\config.ini',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'in-agent-authentication-token.get' -ShowSyntax
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    $argList.Add('-config-path')
    $argList.Add($ConfigPath)
    
    Invoke-ClientTool -Command 'in-agent-authentication-token.get' -Arguments $argList -MachineReadable
}

function Test-ClientToolPassword {
    <#
    .SYNOPSIS
        Checks password requirements

    .DESCRIPTION
        Validates if a password meets the required criteria for Backup Manager.
        Returns whether the password passes validation.

    .PARAMETER Password
        The password to validate

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        Boolean
        Returns $true if password meets requirements, $false otherwise

    .NOTES
        ClientTool Command: password.requirements.check

        Checks requirements for the provided password.

    .EXAMPLE
        Test-ClientToolPassword -Password 'MyP@ssw0rd123'
        Validates if the password meets requirements
    .EXAMPLE
        Test-ClientToolPassword -Syntax
        Shows the command-line help for password.requirements.check
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)] [string]$Password,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'password.requirements.check' -ShowSyntax
        return
    }
    
    # Note: Need to determine actual arguments for passing password
    $argList = [System.Collections.Generic.List[string]]::new()
    # Password argument format needs to be determined from actual command help
    
    Invoke-ClientTool -Command 'password.requirements.check' -Arguments $argList
}

function Get-ClientToolPasswordRequirements {
    <#
    .SYNOPSIS
        Gets password requirements

    .DESCRIPTION
        Retrieves the password complexity requirements for Backup Manager.
        Returns rules such as minimum length, character types, etc.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        String[]
        Returns list of password requirements

    .NOTES
        ClientTool Command: password.requirements.get

        Retrieves the requirements for a valid password.

    .EXAMPLE
        Get-ClientToolPasswordRequirements
        Lists all password requirements
    .EXAMPLE
        Get-ClientToolPasswordRequirements -Syntax
        Shows the command-line help for password.requirements.get
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'password.requirements.get' -ShowSyntax
        return
    }
    
    Invoke-ClientTool -Command 'password.requirements.get'
}

function Set-ClientToolPath {
    <#
    .SYNOPSIS
        Sets the path to ClientTool.exe

    .DESCRIPTION
        Updates the module variable for ClientTool.exe location.
        Use this if ClientTool.exe is installed in a non-standard location.

    .PARAMETER Path
        Full path to ClientTool.exe

    .OUTPUTS
        None

    .NOTES
        Internal Module Function

        Updates the script-scoped $ClientToolPath variable used by all module commands.

    .EXAMPLE
        Set-ClientToolPath -Path 'D:\Custom\Path\ClientTool.exe'
        Sets custom ClientTool.exe location
    .EXAMPLE
        Set-ClientToolPath -Path 'C:\Program Files\Backup Manager\ClientTool.exe'
        Resets to default location
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]        [ValidateScript({
            if (Test-Path $_ -PathType Leaf) { $true }
            else { throw "File not found: $_" }
        })]
        [string]$Path
    )
    
    $script:ClientToolPath = $Path
    Write-Verbose "ClientTool path set to: $Path"
}

function Get-ClientToolPath {
    <#
    .SYNOPSIS
        Gets the current ClientTool.exe path

    .DESCRIPTION
        Returns the path currently configured for ClientTool.exe location.
        Default is C:\Program Files\Backup Manager\ClientTool.exe.

    .OUTPUTS
        String
        Returns the full path to ClientTool.exe

    .NOTES
        Internal Module Function

        Returns the script-scoped $ClientToolPath variable value.

    .EXAMPLE
        Get-ClientToolPath
        Gets the current ClientTool.exe path
    .EXAMPLE
        $path = Get-ClientToolPath; Write-Host "Using: $path"
        Stores and displays the current path
    #>
    [CmdletBinding()]
    param()
    
    return $script:ClientToolPath
}

#endregion

#region Hidden/Advanced Functions

function Stop-ClientToolApplication {
    <#
    .SYNOPSIS
        Closes the Backup Manager application

    .DESCRIPTION
        Shuts down the Backup Manager application gracefully.
        This is a destructive operation that requires confirmation by default.
        Active backup/restore sessions will be terminated.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns command execution output

    .NOTES
        ClientTool Command: control.shutdown

        Shutdown Backup Manager application gracefully.

    .EXAMPLE
        Stop-ClientToolApplication
        Stops Backup Manager (prompts for confirmation)
    .EXAMPLE
        Stop-ClientToolApplication -Confirm:$false
        Stops Backup Manager without prompting
    .EXAMPLE
        Stop-ClientToolApplication -WhatIf
        Shows what would happen without actually stopping
    .EXAMPLE
        Stop-ClientToolApplication -Syntax
        Shows the command-line help for control.shutdown
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.shutdown' -ShowSyntax -HiddenCommand
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Backup Manager application", "Shutdown")) {
        Invoke-ClientTool -Command 'control.shutdown'
    }
}

function Test-ClientToolConnection {
    <#
    .SYNOPSIS
        Tests connection to management node

    .DESCRIPTION
        Checks connectivity to the backup management node with optional authentication and proxy settings.
        Validates whether the device can communicate with N-able cloud services.

    .PARAMETER Account
        Account name for authentication

    .PARAMETER Password
        Password for authentication

    .PARAMETER ProxyAddress
        Proxy server address

    .PARAMETER ProxyPort
        Proxy server port

    .PARAMETER ProxyType
        Proxy protocol type

    .PARAMETER ProxyUsername
        Proxy username

    .PARAMETER ProxyPassword
        Proxy password

    .PARAMETER UseProxy
        Enable proxy usage

    .PARAMETER UseProxyAuthorization
        Enable proxy authorization

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        Boolean
        Returns $true if connection successful, $false otherwise

    .NOTES
        ClientTool Command: control.test.connection

        Test connection to management node.

    .EXAMPLE
        Test-ClientToolConnection
        Tests connection with default settings
    .EXAMPLE
        Test-ClientToolConnection -Account "myaccount" -Password "mypassword"
        Tests connection with specific credentials
    .EXAMPLE
        Test-ClientToolConnection -UseProxy $true -ProxyAddress "proxy.domain.com" -ProxyPort 8080
        Tests connection through a proxy server
    .EXAMPLE
        Test-ClientToolConnection -Syntax
        Shows the command-line help for control.test.connection
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string]$Account,
        [Parameter()] [string]$Password,
        [Parameter()] [string]$ProxyAddress,
        [Parameter()] [int]$ProxyPort,
        [Parameter()] [string]$ProxyType,
        [Parameter()] [string]$ProxyUsername,
        [Parameter()] [string]$ProxyPassword,
        [Parameter()] [bool]$UseProxy,
        [Parameter()] [bool]$UseProxyAuthorization,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'control.test.connection' -ShowSyntax -HiddenCommand
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($Account) {
        $argList.Add('-account')
        $argList.Add($Account)
    }
    
    if ($Password) {
        $argList.Add('-password')
        $argList.Add($Password)
    }
    
    if ($ProxyAddress) {
        $argList.Add('-proxy-address')
        $argList.Add($ProxyAddress)
    }
    
    if ($ProxyPort) {
        $argList.Add('-proxy-port')
        $argList.Add($ProxyPort.ToString())
    }
    
    if ($ProxyType) {
        $argList.Add('-proxy-type')
        $argList.Add($ProxyType)
    }
    
    if ($ProxyUsername) {
        $argList.Add('-proxy-username')
        $argList.Add($ProxyUsername)
    }
    
    if ($ProxyPassword) {
        $argList.Add('-proxy-password')
        $argList.Add($ProxyPassword)
    }
    
    if ($PSBoundParameters.ContainsKey('UseProxy')) {
        $argList.Add('-use-proxy')
        if ($UseProxy) {
            $argList.Add('1')
        }
        else {
            $argList.Add('0')
        }
    }
    
    if ($PSBoundParameters.ContainsKey('UseProxyAuthorization')) {
        $argList.Add('-use-proxy-authorization')
        if ($UseProxyAuthorization) {
            $argList.Add('1')
        }
        else {
            $argList.Add('0')
        }
    }
    
    $result = Invoke-ClientTool -Command 'connection.check' -Arguments $argList
    
    if ($result) {
        Write-Host $result -ForegroundColor Green
        return $result
    }
}

function Test-ClientToolVSS {
    <#
    .SYNOPSIS
        Tests if VSS is available for use

    .DESCRIPTION
        Checks VSS (Volume Shadow Copy Service) availability for backup operations.
        Can optionally resolve Exchange writer issues and show components included in snapshot.

    .PARAMETER Resolve
        Resolve Exchange writer issues

    .PARAMETER ShowPaths
        Show components that will be included in snapshot

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        String[]
        Returns VSS availability status and component details

    .NOTES
        ClientTool Command: vss.check

        Test VSS (Volume Shadow Copy Service) availability.

    .EXAMPLE
        Test-ClientToolVSS
        Checks VSS availability
    .EXAMPLE
        Test-ClientToolVSS -ShowPaths
        Checks VSS and displays included components
    .EXAMPLE
        Test-ClientToolVSS -Resolve
        Checks VSS and resolves Exchange writer issues
    .EXAMPLE
        Test-ClientToolVSS -Syntax
        Shows the command-line help for vss.check
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [switch]$Resolve,
        [Parameter()] [switch]$ShowPaths,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'vss.check' -ShowSyntax -HiddenCommand
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($Resolve) {
        $argList.Add('-resolve')
    }
    
    if ($ShowPaths) {
        $argList.Add('-showpaths')
    }
    
    $result = Invoke-ClientTool -Command 'vss.check' -Arguments $argList
    
    if ($result) {
        Write-Host $result -ForegroundColor Cyan
        return $result
    }
}

function Test-ClientToolVSSExchange {
    <#
    .SYNOPSIS
        Tests if VSS is available for Exchange

    .DESCRIPTION
        Checks VSS (Volume Shadow Copy Service) availability specifically for Exchange Server.
        Can resolve Exchange writer issues and display components.

    .PARAMETER Resolve
        Resolve Exchange writer issues

    .PARAMETER ShowPaths
        Show components that will be included in snapshot

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        String[]
        Returns Exchange VSS availability status

    .NOTES
        ClientTool Command: vss.check.exchange

        Test VSS availability for Exchange Server.

    .EXAMPLE
        Test-ClientToolVSSExchange
        Checks Exchange VSS availability
    .EXAMPLE
        Test-ClientToolVSSExchange -ShowPaths
        Shows Exchange components for VSS snapshot
    .EXAMPLE
        Test-ClientToolVSSExchange -Resolve
        Resolves Exchange writer issues
    .EXAMPLE
        Test-ClientToolVSSExchange -Syntax
        Shows the command-line help for vss.check.exchange
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [switch]$Resolve,
        [Parameter()] [switch]$ShowPaths,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'vss.check.exchange' -ShowSyntax -HiddenCommand
        return
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    if ($Resolve) {
        $argList.Add('-resolve')
    }
    
    if ($ShowPaths) {
        $argList.Add('-showpaths')
    }
    
    $result = Invoke-ClientTool -Command 'vss.exchange.check' -Arguments $argList
    
    if ($result) {
        Write-Host $result -ForegroundColor Cyan
        return $result
    }
}

function Set-ClientToolEncryptionKey {
    <#
    .SYNOPSIS
        Sets the data encryption key

    .DESCRIPTION
        Sets the encryption key for the current device and validates it.
        Prompts for key if not provided. This is a security-sensitive operation.

    .PARAMETER EncryptionKey
        The encryption key to use for encrypting data

    .PARAMETER ForceKey
        Use key even if contract is already in use

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns validation result

    .NOTES
        ClientTool Command: encryption-key.set

        Set and validate encryption key for current device. Handle with care as this affects data security.

    .EXAMPLE
        Set-ClientToolEncryptionKey -EncryptionKey "MySecureKey123"
        Sets the encryption key
    .EXAMPLE
        Set-ClientToolEncryptionKey -EncryptionKey "MyKey" -ForceKey
        Forces key even if contract already in use
    .EXAMPLE
        Set-ClientToolEncryptionKey
        Prompts for encryption key securely
    .EXAMPLE
        Set-ClientToolEncryptionKey -Syntax
        Shows the command-line help for encryption-key.set
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)] [string]$EncryptionKey,
        [Parameter()] [switch]$ForceKey,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'encryption-key.set' -ShowSyntax -HiddenCommand
        return
    }
    
    # Prompt for encryption key if not provided
    if (-not $PSBoundParameters.ContainsKey('EncryptionKey')) {
        $EncryptionKey = Read-Host "Enter the encryption key (or press Enter to cancel)"
        if ([string]::IsNullOrWhiteSpace($EncryptionKey)) {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    $argList = [System.Collections.Generic.List[string]]::new()
    
    $argList.Add('-encryption-key')
    $argList.Add($EncryptionKey)
    
    if ($ForceKey) {
        $argList.Add('-force-key')
    }
    
    if ($PSCmdlet.ShouldProcess("Encryption key", "Set")) {
        Invoke-ClientTool -Command 'encryption-key.set' -Arguments $argList
    }
}

function Clear-ClientToolLocalSpeedVault {
    <#
    .SYNOPSIS
        Cleans Local Speed Vault of duplicate cabinets

    .DESCRIPTION
        Removes duplicate cabinet files from the Local Speed Vault to free up disk space.
        This is a destructive operation that requires confirmation by default.

    .PARAMETER Mode
        Cleaning mode (required). Supported values: duplicates

    .PARAMETER IgnoreFileUsedError
        Ignore errors when files are in use

    .PARAMETER IgnorePermissionError
        Ignore permission-related errors

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns cleaning operation results

    .NOTES
        ClientTool Command: lsv.clean

        Clean Local Speed Vault. Removes duplicate files to reclaim disk space.

    .EXAMPLE
        Clear-ClientToolLocalSpeedVault -Mode duplicates
        Cleans duplicate cabinets (prompts for confirmation)
    .EXAMPLE
        Clear-ClientToolLocalSpeedVault -Mode duplicates -IgnoreFileUsedError -Confirm:$false
        Cleans duplicates, ignoring file-in-use errors, without prompting
    .EXAMPLE
        Clear-ClientToolLocalSpeedVault -Syntax
        Shows the command-line help for lsv.clean
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]        [ValidateSet('duplicates')]
        [string]$Mode,
        [Parameter()] [switch]$IgnoreFileUsedError,
        [Parameter()] [switch]$IgnorePermissionError,
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'lsv.clean' -ShowSyntax -HiddenCommand
        return
    }
    
    if ($PSCmdlet.ShouldProcess("Local Speed Vault", "Clean $Mode")) {
        $arguments = @("-mode $Mode")
        if ($IgnoreFileUsedError) { $arguments += "-ignore-file-used-error" }
        if ($IgnorePermissionError) { $arguments += "-ignore-permission-error" }
        
        Invoke-ClientTool -Command 'lsv.clean' -Arguments $arguments
    }
}

function Test-ClientToolStorage {
    <#
    .SYNOPSIS
        Tests storage and home nodes

    .DESCRIPTION
        Tests connectivity and functionality of home and storage nodes.
        Returns a summary showing state, home node URL, and storage node URL.
        Displays detailed errors if tests fail.

    .OUTPUTS
        PSCustomObject
        Returns object with the following properties:
        - State       : OK or ERROR
        - HomeNode    : Home node URL
        - StorageNode : Storage node URL
        - Errors      : Array of error messages (only if State is ERROR)

    .NOTES
        ClientTool Command: storage.test

        Test storage and home node connectivity.

    .EXAMPLE
        Test-ClientToolStorage
        Tests storage connectivity and displays results
    .EXAMPLE
        $result = Test-ClientToolStorage; if ($result.State -eq 'OK') { Write-Host "All OK" }
        Tests storage and checks result programmatically
    #>
    [CmdletBinding()]
    param()
    
    # Storage test command returns exit code 1 even on success, so we handle it manually
    if (-not (Test-Path $script:ClientToolPath)) {
        throw "ClientTool.exe not found at: $script:ClientToolPath"
    }
    
    Write-Verbose "Executing: $script:ClientToolPath 'storage.test'"
    # Use ProcessStartInfo for in-memory output capture
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:ClientToolPath
    $psi.Arguments = 'storage.test'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    # Read output streams to prevent blocking
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    # Combine output (stdout is primary, stderr as fallback)
    $rawOutput = if ($stdout) { $stdout } elseif ($stderr) { $stderr } else { $null }
    if ($rawOutput) {
        # Parse output to extract node URLs and check for errors
        $lines = $rawOutput -split "`r?`n"
        $homeNode = $null
        $storageNode = $null
        $errors = @()
        $allOk = $true
        foreach ($line in $lines) {
            # Extract home node URL
            if ($line -match 'Home node') {
                $nextLineIndex = $lines.IndexOf($line) + 1
                if ($nextLineIndex -lt $lines.Count -and $lines[$nextLineIndex] -match 'Connecting to <([^>]+)>') {
                    $homeNode = $matches[1]
                }
            }
            
            # Extract storage node URL
            if ($line -match 'Storage node') {
                $nextLineIndex = $lines.IndexOf($line) + 1
                if ($nextLineIndex -lt $lines.Count -and $lines[$nextLineIndex] -match 'Connecting to <([^>]+)>') {
                    $storageNode = $matches[1]
                }
            }
            
            # Check for errors (lines that don't end with "ok")
            if ($line -match '^\s+\*.*\.\.\.\s*(.+)$' -and $matches[1] -ne 'ok') {
                $errors += $line.Trim()
                $allOk = $false
            }
        }
        
        # Build result object
        $result = [PSCustomObject]@{
            State = if ($allOk) { 'OK' } else { 'ERROR' }
            HomeNode = $homeNode
            StorageNode = $storageNode
        }
        
        # Display summary
        if ($allOk) {
            Write-Host "State       : " -NoNewline
            Write-Host $result.State -ForegroundColor Green
            Write-Host "Home Node   : " -NoNewline
            Write-Host $result.HomeNode -ForegroundColor Cyan
            Write-Host "Storage Node: " -NoNewline
            Write-Host $result.StorageNode -ForegroundColor Cyan
        }
        else {
            Write-Host "State       : " -NoNewline
            Write-Host $result.State -ForegroundColor Red
            Write-Host "Home Node   : " -NoNewline
            Write-Host $result.HomeNode -ForegroundColor Cyan
            Write-Host "Storage Node: " -NoNewline
            Write-Host $result.StorageNode -ForegroundColor Cyan
            Write-Host "Errors      :" -ForegroundColor Yellow
            foreach ($error in $errors) {
                Write-Host "  $error" -ForegroundColor Red
            }
            $result | Add-Member -NotePropertyName 'Errors' -NotePropertyValue $errors
        }
        
        # Return raw output in verbose mode
        Write-Verbose $rawOutput
        return $result
    }
}

function Show-ClientToolProgressBar {
    <#
    .SYNOPSIS
        Shows progress bar for in-progress session

    .DESCRIPTION
        Displays a real-time progress bar for the currently running backup or restore session.
        Provides visual feedback on the status and completion percentage of active operations.
        Only displays progress for sessions that are currently active.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .OUTPUTS
        None
        Displays interactive progress bar in terminal

    .NOTES
        ClientTool Command: show.progress-bar

        This command only displays progress for sessions that are currently active.
        If no session is running, the command exits without showing a progress bar.

    .EXAMPLE
        Show-ClientToolProgressBar
        Displays the progress bar for any active backup or restore session
    .EXAMPLE
        Show-ClientToolProgressBar -Syntax
        Shows the command-line help for show.progress-bar
    #>
    [CmdletBinding()]
    param()
    
    # Progress bar command returns exit code 1 even on success, so we call it directly
    if (-not (Test-Path $script:ClientToolPath)) {
        throw "ClientTool.exe not found at: $script:ClientToolPath"
    }
    
    & $script:ClientToolPath 'show.progress-bar'
}

function Update-ClientToolMTLSCertificate {
    <#
    .SYNOPSIS
        Renews the mTLS certificate for secure communications

    .DESCRIPTION
        Renews the mutual TLS (mTLS) certificate used for secure communications between
        the Backup Manager and remote services. Ensures continued encrypted connectivity
        and authentication. May temporarily interrupt backup operations during renewal.

    .PARAMETER CertificateUpdatePeriod
        Certificate update period in days. Specifies how often the certificate should be renewed.
        Default behavior uses system-configured renewal period if not specified.

    .PARAMETER ConfigPath
        Full path to config.ini file. Optional - defaults to 'C:\Program Files\Backup Manager\config.ini' if not specified.

    .PARAMETER Syntax
        Display the ClientTool command-line syntax for this command

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .OUTPUTS
        String[]
        Returns certificate renewal operation results

    .NOTES
        ClientTool Command: mtls.certificate.renew

        Renew mTLS certificate. Recommended to run during maintenance windows.

    .EXAMPLE
        Update-ClientToolMTLSCertificate
        Renews the mTLS certificate using default settings
    .EXAMPLE
        Update-ClientToolMTLSCertificate -CertificateUpdatePeriod 30
        Renews certificate with a 30-day update period
    .EXAMPLE
        Update-ClientToolMTLSCertificate -ConfigPath "C:\Program Files\Backup Manager\config.ini"
        Renews certificate for a specific Backup Manager instance
    .EXAMPLE
        Update-ClientToolMTLSCertificate -Syntax
        Shows the command-line help for mtls.certificate.renew
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()] [int]$CertificateUpdatePeriod,
        [Parameter()] [string]$ConfigPath = 'C:\Program Files\Backup Manager\config.ini',
        [Parameter()] [switch]$Syntax
    )
    
    if ($Syntax) {
        Invoke-ClientTool -Command 'mtls.certificate.renew' -ShowSyntax -HiddenCommand
        return
    }
    
    if ($PSCmdlet.ShouldProcess("mTLS certificate", "Renew")) {
        $argList = [System.Collections.Generic.List[string]]::new()
        
        if ($CertificateUpdatePeriod) {
            $argList.Add('-certificate-update-period')
            $argList.Add($CertificateUpdatePeriod.ToString())
        }
        
        if ($ConfigPath) {
            $argList.Add('-config-path')
            $argList.Add($ConfigPath)
        }
        
        Invoke-ClientTool -Command 'mtls.certificate.renew' -Arguments $argList
    }
}

#endregion

#region Module Exports

# Export all functions
Export-ModuleMember -Function @(
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

#endregion
