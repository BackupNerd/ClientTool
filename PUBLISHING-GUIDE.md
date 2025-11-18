# How to Publish ClientTool Module to GitHub

This guide will help you publish your PowerShell module to GitHub so others can download and use it.

## Prerequisites

- GitHub account (BackupNerd)
- Git installed on your system
- Module files ready for publication

## Step-by-Step Publishing Guide

### 1. Clean Up Module Directory

First, remove backup/temporary files from your module directory:

```powershell
# Navigate to module directory
cd "c:\Script Root\0-Script Master\Modules\ClientTool"

# Remove backup files (keep only production files)
Remove-Item "ClientTool.psm1.afterwhatif" -Force
Remove-Item "ClientTool.psm1.beforestyle" -Force
Remove-Item "ClientTool.psm1.beforewhatif" -Force
Remove-Item "ClientTool.psm1.complete-20251118-115336" -Force
Remove-Item "ClientTool.psm1.final-20251118-114951" -Force
Remove-Item "ClientTool.psm1.withhelperexamples" -Force
```

### 2. Create GitHub Repository

**Option A: Via GitHub Web Interface**
1. Go to https://github.com/new
2. Repository name: `ClientTool`
3. Description: "PowerShell module for N-able Cove Data Protection (Backup Manager) ClientTool.exe"
4. Choose Public or Private
5. Do NOT initialize with README (you already have one)
6. Click "Create repository"

**Option B: Via GitHub CLI**
```powershell
gh repo create ClientTool --public --description "PowerShell module for N-able Cove Data Protection ClientTool.exe"
```

### 3. Initialize Git Repository (if not already done)

```powershell
# Navigate to module directory
cd "c:\Script Root\0-Script Master\Modules\ClientTool"

# Initialize git repository
git init

# Add remote (replace with your actual GitHub URL)
git remote add origin https://github.com/BackupNerd/ClientTool.git
```

### 4. Create .gitignore File

Create a `.gitignore` file to exclude backup files:

```powershell
@"
# PowerShell backup files
*.backup
*.psm1.after*
*.psm1.before*
*.psm1.complete-*
*.psm1.final-*
*.psm1.with*

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*~
"@ | Out-File -FilePath ".gitignore" -Encoding UTF8
```

### 5. Add and Commit Files

```powershell
# Add all files
git add .

# Commit with message
git commit -m "Initial release: ClientTool PowerShell module v1.1.0

Features:
- Complete wrapper for ClientTool.exe commands
- Default config path support (C:\Program Files\Backup Manager\config.ini)
- Parameter validation for archiving rules
- Auto-display of created resources
- Comprehensive help documentation
- 70+ functions covering all ClientTool operations"

# Set default branch to main (GitHub standard)
git branch -M main

# Push to GitHub
git push -u origin main
```

### 6. Create a Release Tag

```powershell
# Create and push version tag
git tag -a v1.1.0 -m "Version 1.1.0 - Production Release"
git push origin v1.1.0
```

### 7. Create GitHub Release

**Via GitHub Web Interface:**
1. Go to your repository: https://github.com/BackupNerd/ClientTool
2. Click "Releases" → "Create a new release"
3. Choose tag: `v1.1.0`
4. Release title: `ClientTool v1.1.0 - Initial Release`
5. Description:
```markdown
## ClientTool PowerShell Module v1.1.0

A comprehensive PowerShell wrapper for N-able Cove Data Protection (Backup Manager) ClientTool.exe.

### ✨ Features

- 70+ PowerShell functions covering all ClientTool operations
- Default config path support
- Parameter validation and helpful error messages
- Auto-display of created resources
- Comprehensive comment-based help
- SupportsShouldProcess (WhatIf/Confirm support)

### 📦 Installation

See [INSTALLATION.md](INSTALLATION.md) for detailed installation instructions.

**Quick Install:**
```powershell
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
New-Item -ItemType Directory -Path $modulePath -Force
Invoke-WebRequest -Uri "https://github.com/BackupNerd/ClientTool/archive/refs/tags/v1.1.0.zip" -OutFile "$env:TEMP\ClientTool.zip"
Expand-Archive -Path "$env:TEMP\ClientTool.zip" -DestinationPath "$env:TEMP\ClientTool" -Force
Copy-Item -Path "$env:TEMP\ClientTool\ClientTool-1.1.0\*" -Destination $modulePath -Recurse -Force
Import-Module ClientTool
```

### 📚 Documentation

- [README.md](README.md) - Overview and features
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [INSTALLATION.md](INSTALLATION.md) - Installation instructions
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Command reference
- [Examples.ps1](Examples.ps1) - Usage examples

### 🚀 Quick Start

```powershell
Import-Module ClientTool
Get-ClientToolStatus
Get-ClientToolBackupSession
New-ClientToolArchivingRule -Name "Weekly-Friday" -DayOfWeek Friday -Weeks All
```

### 📋 Requirements

- PowerShell 5.1 or higher (PowerShell 7+ recommended)
- N-able Cove Data Protection Backup Manager installed
- ClientTool.exe at: `C:\Program Files\Backup Manager\ClientTool.exe`

### 🐛 Issues & Support

Report issues at: https://github.com/BackupNerd/ClientTool/issues
```

6. Attach files (optional): You can attach a ZIP of the module
7. Click "Publish release"

### 8. Update README with Installation Instructions

Add installation badge and instructions to your README.md:

```markdown
## Installation

### From GitHub

```powershell
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\ClientTool"
New-Item -ItemType Directory -Path $modulePath -Force
Invoke-WebRequest -Uri "https://github.com/BackupNerd/ClientTool/archive/refs/heads/main.zip" -OutFile "$env:TEMP\ClientTool.zip"
Expand-Archive -Path "$env:TEMP\ClientTool.zip" -DestinationPath "$env:TEMP\ClientTool" -Force
Copy-Item -Path "$env:TEMP\ClientTool\ClientTool-main\*" -Destination $modulePath -Recurse -Force
Import-Module ClientTool
```

See [INSTALLATION.md](INSTALLATION.md) for more installation methods.
```

## Usage After Publishing

Once published, users can install your module using:

```powershell
# Direct download from GitHub
Invoke-WebRequest -Uri "https://github.com/BackupNerd/ClientTool/archive/refs/heads/main.zip" -OutFile "$env:TEMP\ClientTool.zip"
```

Or clone the repository:

```powershell
git clone https://github.com/BackupNerd/ClientTool.git
cd ClientTool
Import-Module .\ClientTool.psm1
```

## Publishing to PowerShell Gallery (Optional)

To make your module available via `Install-Module`:

### 1. Get PowerShell Gallery API Key

1. Create account at https://www.powershellgallery.com/
2. Go to https://www.powershellgallery.com/account/apikeys
3. Create new API key

### 2. Publish Module

```powershell
# Publish to PowerShell Gallery
Publish-Module -Name ClientTool -NuGetApiKey "YOUR-API-KEY-HERE"
```

Then users can install with:

```powershell
Install-Module -Name ClientTool -Scope CurrentUser
```

## Maintenance

### Updating Your Module

```powershell
# Make changes to your module
# Update version in ClientTool.psd1

# Commit changes
git add .
git commit -m "Version 1.1.1 - Bug fixes and improvements"
git push

# Create new tag
git tag -a v1.1.1 -m "Version 1.1.1"
git push origin v1.1.1

# Create new GitHub release
```

### Keep Repository Clean

Regularly update `.gitignore` to exclude:
- Backup files (*.backup, *.psm1.*)
- Test files
- Temporary files
- Personal configuration files

## Best Practices

1. **Semantic Versioning:** Use MAJOR.MINOR.PATCH (e.g., 1.1.0)
2. **Changelog:** Maintain CHANGELOG.md with release notes
3. **License:** Add LICENSE file (MIT, Apache, etc.)
4. **Contributing:** Add CONTRIBUTING.md for contributors
5. **Issues:** Enable GitHub Issues for bug reports
6. **Wiki:** Use GitHub Wiki for extended documentation
7. **CI/CD:** Consider GitHub Actions for automated testing

## Repository Structure

Your published repository should have:

```
ClientTool/
├── .gitignore
├── LICENSE
├── README.md
├── INSTALLATION.md
├── QUICKSTART.md
├── QUICK-REFERENCE.md
├── CLIENTTOOL-COMMANDS.md
├── CHANGELOG.md (create this)
├── ClientTool.psd1
├── ClientTool.psm1
├── Examples.ps1
└── Install-Module.ps1
```

## Need Help?

- GitHub Docs: https://docs.github.com/en/repositories
- PowerShell Gallery: https://www.powershellgallery.com/
- Git Documentation: https://git-scm.com/doc
