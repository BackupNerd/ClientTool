<#
.SYNOPSIS
    Installs the ClientTool module from GitHub to your PowerShell modules directory

.DESCRIPTION
    Downloads and installs the ClientTool module from GitHub to your PowerShell modules folder,
    making it available for import from any PowerShell session.

.PARAMETER Scope
    Install for CurrentUser or AllUsers (requires admin for AllUsers)

.PARAMETER FromGitHub
    Download from GitHub instead of using local files

.PARAMETER Version
    Specific version to download from GitHub (e.g., 'v1.1.0'). Defaults to latest (main branch)

.EXAMPLE
    .\Install-Module.ps1
    Installs from local files for current user

.EXAMPLE
    .\Install-Module.ps1 -FromGitHub
    Downloads and installs latest version from GitHub for current user

.EXAMPLE
    .\Install-Module.ps1 -FromGitHub -Version v1.1.0
    Downloads and installs specific version from GitHub

.EXAMPLE
    .\Install-Module.ps1 -Scope AllUsers
    Installs for all users (requires admin)

.EXAMPLE
    irm https://raw.githubusercontent.com/BackupNerd/ClientTool/main/Install-Module.ps1 | iex
    One-liner to download and run this script directly from GitHub
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    
    [Parameter()]
    [switch]$FromGitHub,
    
    [Parameter()]
    [string]$Version = 'main'
)

$moduleName = 'ClientTool'
$githubRepo = 'BackupNerd/ClientTool'

# If running from web (no $PSScriptRoot), force GitHub download
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Write-Host "Running from web - downloading from GitHub..." -ForegroundColor Cyan
    $FromGitHub = $true
}

$sourceDir = $PSScriptRoot

# Determine target directory based on scope
if ($Scope -eq 'AllUsers') {
    $targetBase = "$env:ProgramFiles\PowerShell\Modules"
    
    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Installing for AllUsers requires administrator privileges. Please run as administrator or use -Scope CurrentUser"
        exit 1
    }
}
else {
    # Support both PowerShell 7+ and Windows PowerShell
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $targetBase = "$HOME\Documents\PowerShell\Modules"
    } else {
        $targetBase = "$HOME\Documents\WindowsPowerShell\Modules"
    }
}

$targetDir = Join-Path $targetBase $moduleName

Write-Host "`n╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          ClientTool Module Installation                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Download from GitHub if requested or running from web
if ($FromGitHub) {
    Write-Host "📥 Downloading from GitHub..." -ForegroundColor Yellow
    
    # Determine download URL
    if ($Version -eq 'main') {
        $downloadUrl = "https://github.com/$githubRepo/archive/refs/heads/main.zip"
        $extractFolder = "$moduleName-main"
    } else {
        $downloadUrl = "https://github.com/$githubRepo/archive/refs/tags/$Version.zip"
        $extractFolder = "$moduleName-$($Version.TrimStart('v'))"
    }
    
    $tempZip = Join-Path $env:TEMP "ClientTool-Download.zip"
    $tempExtract = Join-Path $env:TEMP "ClientTool-Extract"
    
    try {
        # Download
        Write-Host "   Downloading from: $downloadUrl" -ForegroundColor Gray
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
        Write-Host "   ✓ Downloaded" -ForegroundColor Green
        
        # Extract
        Write-Host "   Extracting..." -ForegroundColor Gray
        if (Test-Path $tempExtract) {
            Remove-Item $tempExtract -Recurse -Force
        }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        Write-Host "   ✓ Extracted" -ForegroundColor Green
        
        # Set source directory to extracted folder
        $sourceDir = Join-Path $tempExtract $extractFolder
        
        if (-not (Test-Path $sourceDir)) {
            Write-Error "Extracted folder not found: $sourceDir"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to download from GitHub: $_"
        exit 1
    }
}

Write-Host "📦 Installing ClientTool module..." -ForegroundColor Cyan
Write-Host "   Source: $sourceDir" -ForegroundColor Gray
Write-Host "   Target: $targetDir" -ForegroundColor Gray
Write-Host ""

# Create target directory if it doesn't exist
if (-not (Test-Path $targetDir)) {
    Write-Host "   Creating directory..." -ForegroundColor Yellow
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}
else {
    Write-Host "   Removing existing installation..." -ForegroundColor Yellow
    Remove-Item -Path "$targetDir\*" -Recurse -Force
}

# Copy all module files
Write-Host "   Copying files..." -ForegroundColor Yellow
Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force -Exclude @('*.backup', '.git', '.gitignore', 'Publish-ModuleToGitHub.ps1')

# Clean up downloaded files
if ($FromGitHub) {
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "   ✓ Installation complete!" -ForegroundColor Green


Write-Host "`n✅ Module installed successfully!`n" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Test import
Write-Host "`n🔄 Testing module import..." -ForegroundColor Yellow
try {
    Import-Module ClientTool -Force
    $module = Get-Module ClientTool
    $commands = Get-Command -Module ClientTool
    
    Write-Host "   ✓ Module imported successfully!" -ForegroundColor Green
    Write-Host "   ✓ Version: $($module.Version)" -ForegroundColor Green
    Write-Host "   ✓ Available commands: $($commands.Count)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import module: $_"
    exit 1
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "`n📚 Getting Started:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Import the module:" -ForegroundColor White
Write-Host "   Import-Module ClientTool" -ForegroundColor Green
Write-Host ""
Write-Host "   See all available commands:" -ForegroundColor White
Write-Host "   Get-Command -Module ClientTool" -ForegroundColor Green
Write-Host ""
Write-Host "   Get help on any command:" -ForegroundColor White
Write-Host "   Get-Help Get-ClientToolStatus -Full" -ForegroundColor Green
Write-Host ""
Write-Host "   Quick status check:" -ForegroundColor White
Write-Host "   Get-ClientToolStatus" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "`n📖 Documentation: https://github.com/$githubRepo" -ForegroundColor Cyan
Write-Host ""

