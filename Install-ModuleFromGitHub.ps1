# Install ClientTool Module from GitHub

# Method 1: One-Liner (Recommended) - Auto-compatible
irm https://raw.githubusercontent.com/BackupNerd/ClientTool/main/Install-Module.ps1 | iex

# Method 2: Manual Installation (PS 5.1 & PS 7+ Compatible)
$modulePath = Join-Path (($env:PSModulePath -split ';' | Where-Object { Test-Path $_ })[0]) 'ClientTool'
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
Invoke-WebRequest -Uri "https://github.com/BackupNerd/ClientTool/archive/refs/heads/main.zip" `
    -OutFile "$env:TEMP\ClientTool.zip" -UseBasicParsing
Expand-Archive -Path "$env:TEMP\ClientTool.zip" -DestinationPath "$env:TEMP\ClientTool" -Force
Copy-Item -Path "$env:TEMP\ClientTool\ClientTool-main\*" -Destination $modulePath -Recurse -Force
Remove-Item -Path "$env:TEMP\ClientTool.zip", "$env:TEMP\ClientTool" -Recurse -Force
Import-Module ClientTool -Force

# Method 3: Download & Run Installer - Auto-compatible
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BackupNerd/ClientTool/main/Install-Module.ps1" `
    -OutFile "Install-ClientTool.ps1" -UseBasicParsing
.\Install-ClientTool.ps1 -FromGitHub