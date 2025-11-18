<#
.SYNOPSIS
    Prepares and publishes the ClientTool module to GitHub.

.DESCRIPTION
    This script automates the process of preparing your ClientTool module for GitHub publication.
    It cleans up backup files, initializes git repository, and provides guidance for publishing.

.PARAMETER Clean
    Remove backup and temporary files from the module directory.

.PARAMETER Init
    Initialize git repository and add remote.

.PARAMETER Commit
    Add, commit, and push files to GitHub.

.PARAMETER Tag
    Create and push a version tag.

.PARAMETER All
    Perform all steps (clean, init, commit, tag).

.EXAMPLE
    .\Publish-ModuleToGitHub.ps1 -Clean
    Removes backup files from the module directory.

.EXAMPLE
    .\Publish-ModuleToGitHub.ps1 -All
    Performs all publishing steps.

.NOTES
    Author: BackupNerd
    Version: 1.0.0
    Date: 2025-11-18
#>

[CmdletBinding(DefaultParameterSetName='Help')]
param(
    [Parameter(ParameterSetName='Clean')]
    [switch]$Clean,
    
    [Parameter(ParameterSetName='Init')]
    [switch]$Init,
    
    [Parameter(ParameterSetName='Commit')]
    [switch]$Commit,
    
    [Parameter(ParameterSetName='Tag')]
    [switch]$Tag,
    
    [Parameter(ParameterSetName='All')]
    [switch]$All,
    
    [Parameter()]
    [string]$GitHubRepo = "https://github.com/BackupNerd/ClientTool.git",
    
    [Parameter()]
    [string]$Version = "1.1.0",
    
    [Parameter()]
    [string]$CommitMessage = "Version $Version - Production release with enhanced features"
)

$ModulePath = $PSScriptRoot

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ClientTool Module - GitHub Publishing Helper          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Cyan
}

function Clean-ModuleDirectory {
    Write-Step "Cleaning backup and temporary files..."
    
    $backupFiles = @(
        "ClientTool.psm1.afterwhatif",
        "ClientTool.psm1.beforestyle",
        "ClientTool.psm1.beforewhatif",
        "ClientTool.psm1.complete-20251118-115336",
        "ClientTool.psm1.final-20251118-114951",
        "ClientTool.psm1.withhelperexamples"
    )
    
    foreach ($file in $backupFiles) {
        $filePath = Join-Path $ModulePath $file
        if (Test-Path $filePath) {
            Remove-Item $filePath -Force
            Write-Success "Removed: $file"
        }
    }
    
    Write-Success "Cleanup complete"
}

function Initialize-GitRepository {
    Write-Step "Initializing Git repository..."
    
    Push-Location $ModulePath
    
    try {
        # Check if git repo exists
        $isRepo = git rev-parse --git-dir 2>$null
        
        if (-not $isRepo) {
            git init
            Write-Success "Git repository initialized"
        } else {
            Write-Info "Git repository already exists"
        }
        
        # Add remote if not exists
        $remotes = git remote
        if ($remotes -notcontains 'origin') {
            git remote add origin $GitHubRepo
            Write-Success "Added remote: $GitHubRepo"
        } else {
            Write-Info "Remote 'origin' already exists"
            git remote set-url origin $GitHubRepo
            Write-Success "Updated remote URL: $GitHubRepo"
        }
        
        # Verify .gitignore exists
        if (-not (Test-Path (Join-Path $ModulePath ".gitignore"))) {
            Write-Warning ".gitignore file not found! Create it before committing."
        } else {
            Write-Success ".gitignore file found"
        }
        
    } finally {
        Pop-Location
    }
}

function Commit-AndPush {
    Write-Step "Committing and pushing to GitHub..."
    
    Push-Location $ModulePath
    
    try {
        # Check for changes
        $status = git status --porcelain
        
        if (-not $status) {
            Write-Info "No changes to commit"
            return
        }
        
        # Add all files
        git add .
        Write-Success "Files staged"
        
        # Show what will be committed
        Write-Info "Files to be committed:"
        git status --short
        
        # Commit
        git commit -m $CommitMessage
        Write-Success "Changes committed"
        
        # Set branch to main
        $currentBranch = git branch --show-current
        if ($currentBranch -ne 'main') {
            git branch -M main
            Write-Success "Branch renamed to 'main'"
        }
        
        # Push
        Write-Info "Pushing to GitHub..."
        git push -u origin main
        Write-Success "Pushed to GitHub"
        
    } catch {
        Write-Error "Failed to commit/push: $_"
    } finally {
        Pop-Location
    }
}

function Create-VersionTag {
    Write-Step "Creating version tag v$Version..."
    
    Push-Location $ModulePath
    
    try {
        # Check if tag exists
        $tagExists = git tag -l "v$Version"
        
        if ($tagExists) {
            Write-Warning "Tag v$Version already exists"
            $response = Read-Host "Do you want to delete and recreate it? (y/N)"
            if ($response -eq 'y') {
                git tag -d "v$Version"
                git push origin ":refs/tags/v$Version" 2>$null
                Write-Success "Deleted existing tag"
            } else {
                return
            }
        }
        
        # Create tag
        git tag -a "v$Version" -m "Version $Version"
        Write-Success "Created tag: v$Version"
        
        # Push tag
        git push origin "v$Version"
        Write-Success "Pushed tag to GitHub"
        
        Write-Info "Tag URL: $($GitHubRepo -replace '\.git$','')/releases/tag/v$Version"
        
    } catch {
        Write-Error "Failed to create tag: $_"
    } finally {
        Pop-Location
    }
}

function Show-NextSteps {
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    Next Steps                              ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host "`n1. Create GitHub Repository (if not exists):" -ForegroundColor Yellow
    Write-Host "   https://github.com/new" -ForegroundColor Cyan
    Write-Host "   Repository name: ClientTool" -ForegroundColor White
    Write-Host "   Description: PowerShell module for N-able Cove Data Protection ClientTool.exe`n" -ForegroundColor White
    
    Write-Host "2. Create GitHub Release:" -ForegroundColor Yellow
    Write-Host "   $($GitHubRepo -replace '\.git$','')/releases/new" -ForegroundColor Cyan
    Write-Host "   Tag: v$Version" -ForegroundColor White
    Write-Host "   Title: ClientTool v$Version - Production Release" -ForegroundColor White
    Write-Host "   See CHANGELOG.md for release notes`n" -ForegroundColor White
    
    Write-Host "3. Users can now install with:" -ForegroundColor Yellow
    Write-Host @"
   ```powershell
   `$modulePath = "`$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
   New-Item -ItemType Directory -Path `$modulePath -Force
   Invoke-WebRequest -Uri "$($GitHubRepo -replace '\.git$','')/archive/refs/heads/main.zip" -OutFile "`$env:TEMP\ClientTool.zip"
   Expand-Archive -Path "`$env:TEMP\ClientTool.zip" -DestinationPath "`$env:TEMP\ClientTool" -Force
   Copy-Item -Path "`$env:TEMP\ClientTool\ClientTool-main\*" -Destination `$modulePath -Recurse -Force
   Import-Module ClientTool
   ```
"@ -ForegroundColor Cyan
    
    Write-Host "`n4. Optional - Publish to PowerShell Gallery:" -ForegroundColor Yellow
    Write-Host "   Publish-Module -Name ClientTool -NuGetApiKey YOUR-API-KEY`n" -ForegroundColor Cyan
    
    Write-Host "For detailed instructions, see: PUBLISHING-GUIDE.md`n" -ForegroundColor White
}

# Main execution
if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

if ($All -or $Clean) {
    Clean-ModuleDirectory
}

if ($All -or $Init) {
    Initialize-GitRepository
}

if ($All -or $Commit) {
    Commit-AndPush
}

if ($All -or $Tag) {
    Create-VersionTag
}

if ($All) {
    Show-NextSteps
}

Write-Host "`n✓ Publishing process complete!`n" -ForegroundColor Green
