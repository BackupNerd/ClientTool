<#
.SYNOPSIS
    Example script demonstrating ClientTool PowerShell module usage

.DESCRIPTION
    This script provides working examples of how to use the ClientTool module
    for common backup management tasks.

.NOTES
    Author: BackupNerd
    Date: November 14, 2025
#>

# Import the module (assuming you're in the module directory or it's in your PSModulePath)
Import-Module "$PSScriptRoot\ClientTool.psd1" -Force -Verbose

Write-Host "=== ClientTool PowerShell Module Examples ===" -ForegroundColor Cyan
Write-Host ""

# Example 1: Get Current Status
Write-Host "Example 1: Getting Backup Manager Status" -ForegroundColor Yellow
try {
    $status = Get-ClientToolStatus
    Write-Host "Status retrieved successfully" -ForegroundColor Green
    $status
}
catch {
    Write-Warning "Failed to get status: $_"
}
Write-Host ""

# Example 2: List Current Selections
Write-Host "Example 2: Listing Current Backup Selections" -ForegroundColor Yellow
try {
    $selections = Get-ClientToolSelection
    if ($selections) {
        Write-Host "Current selections:" -ForegroundColor Green
        $selections | Format-Table -AutoSize
    }
    else {
        Write-Host "No selections configured" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "Failed to get selections: $_"
}
Write-Host ""

# Example 3: List FileSystem Selections Only
Write-Host "Example 3: Listing FileSystem Selections" -ForegroundColor Yellow
try {
    $fsSelections = Get-ClientToolSelection -DataSource FileSystem
    if ($fsSelections) {
        Write-Host "FileSystem selections:" -ForegroundColor Green
        $fsSelections | Format-Table -AutoSize
    }
    else {
        Write-Host "No FileSystem selections configured" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "Failed to get FileSystem selections: $_"
}
Write-Host ""

# Example 4: List Recent Sessions
Write-Host "Example 4: Listing Recent Backup/Restore Sessions" -ForegroundColor Yellow
try {
    $sessions = Get-ClientToolSession
    if ($sessions) {
        Write-Host "Recent sessions:" -ForegroundColor Green
        $sessions | Select-Object -First 10 | Format-Table -AutoSize
    }
    else {
        Write-Host "No sessions found" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "Failed to get sessions: $_"
}
Write-Host ""

# Example 5: Get System Information
Write-Host "Example 5: Getting System Information" -ForegroundColor Yellow
try {
    $sysInfo = Get-ClientToolSystemInfo
    if ($sysInfo) {
        Write-Host "System Information:" -ForegroundColor Green
        $sysInfo | ConvertTo-Json -Depth 5
    }
}
catch {
    Write-Warning "Failed to get system info: $_"
}
Write-Host ""

# Example 6: Check Application Status
Write-Host "Example 6: Getting Application Status" -ForegroundColor Yellow
try {
    $appStatus = Get-ClientToolApplicationStatus
    Write-Host "Application status retrieved" -ForegroundColor Green
    $appStatus
}
catch {
    Write-Warning "Failed to get application status: $_"
}
Write-Host ""

# Example 7: List Schedules
Write-Host "Example 7: Listing Configured Schedules" -ForegroundColor Yellow
try {
    $schedules = Get-ClientToolSchedule
    if ($schedules) {
        Write-Host "Configured schedules:" -ForegroundColor Green
        $schedules | Format-Table -AutoSize
    }
    else {
        Write-Host "No schedules configured" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "Failed to get schedules: $_"
}
Write-Host ""

# Example 8: Demonstration of WhatIf (safe to run)
Write-Host "Example 8: Using -WhatIf Parameter (Preview Actions)" -ForegroundColor Yellow
Write-Host "This shows what would happen without actually doing it:" -ForegroundColor Gray
try {
    # This won't actually start a backup, just shows what would happen
    Start-ClientToolBackup -DataSource FileSystem -WhatIf
}
catch {
    Write-Warning "WhatIf simulation failed: $_"
}
Write-Host ""

# Example 9: Working with Pipeline
Write-Host "Example 9: Using Pipeline to Filter Sessions" -ForegroundColor Yellow
try {
    $sessions = Get-ClientToolSession
    if ($sessions) {
        $fsSessions = $sessions | Where-Object { $_.DSRC -eq 'FileSystem' }
        if ($fsSessions) {
            Write-Host "FileSystem sessions only:" -ForegroundColor Green
            $fsSessions | Select-Object -First 5 | Format-Table -AutoSize
        }
        else {
            Write-Host "No FileSystem sessions found" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Warning "Failed to filter sessions: $_"
}
Write-Host ""

# Example 10: Get Settings
Write-Host "Example 10: Listing Application Settings" -ForegroundColor Yellow
try {
    $settings = Get-ClientToolSetting
    if ($settings) {
        Write-Host "Application settings:" -ForegroundColor Green
        $settings | Format-Table -AutoSize
    }
}
catch {
    Write-Warning "Failed to get settings: $_"
}
Write-Host ""

Write-Host "=== Examples Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "For more information, use: Get-Help <CommandName> -Full" -ForegroundColor Green
Write-Host "To see all available commands: Get-Command -Module ClientTool" -ForegroundColor Green
