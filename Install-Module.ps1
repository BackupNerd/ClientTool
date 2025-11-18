<#
.SYNOPSIS
    Installs the ClientTool module to your PowerShell modules directory

.DESCRIPTION
    Copies the ClientTool module to your user's PowerShell modules folder,
    making it available for import from any PowerShell session.

.PARAMETER Scope
    Install for CurrentUser or AllUsers (requires admin for AllUsers)

.EXAMPLE
    .\Install-Module.ps1
    Installs for current user

.EXAMPLE
    .\Install-Module.ps1 -Scope AllUsers
    Installs for all users (requires admin)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
)

$moduleName = 'ClientTool'
$sourceDir = $PSScriptRoot

# Determine target directory based on scope
if ($Scope -eq 'AllUsers') {
    $targetBase = "$env:ProgramFiles\WindowsPowerShell\Modules"
    
    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Installing for AllUsers requires administrator privileges. Please run as administrator or use -Scope CurrentUser"
        exit 1
    }
}
else {
    $targetBase = "$HOME\Documents\WindowsPowerShell\Modules"
}

$targetDir = Join-Path $targetBase $moduleName

Write-Host "Installing ClientTool module..." -ForegroundColor Cyan
Write-Host "  Source: $sourceDir" -ForegroundColor Gray
Write-Host "  Target: $targetDir" -ForegroundColor Gray
Write-Host ""

# Create target directory if it doesn't exist
if (-not (Test-Path $targetDir)) {
    Write-Host "Creating directory: $targetDir" -ForegroundColor Yellow
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

# Copy files
$filesToCopy = @(
    'ClientTool.psm1',
    'ClientTool.psd1',
    'README.md'
)

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $sourceDir $file
    $targetPath = Join-Path $targetDir $file
    
    if (Test-Path $sourcePath) {
        Write-Host "Copying $file..." -ForegroundColor Green
        Copy-Item -Path $sourcePath -Destination $targetPath -Force
    }
    else {
        Write-Warning "File not found: $file"
    }
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now use the module in any PowerShell session:" -ForegroundColor Cyan
Write-Host "  Import-Module ClientTool" -ForegroundColor White
Write-Host ""
Write-Host "To see available commands:" -ForegroundColor Cyan
Write-Host "  Get-Command -Module ClientTool" -ForegroundColor White
Write-Host ""
Write-Host "To get help on any command:" -ForegroundColor Cyan
Write-Host "  Get-Help <CommandName> -Full" -ForegroundColor White
Write-Host ""

# Test import
Write-Host "Testing module import..." -ForegroundColor Yellow
try {
    Import-Module ClientTool -Force
    Write-Host "Module imported successfully!" -ForegroundColor Green
    
    $commands = Get-Command -Module ClientTool
    Write-Host "Available commands: $($commands.Count)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import module: $_"
}
