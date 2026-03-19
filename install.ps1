# AI Agent Shell — Windows Installer
# Run from PowerShell: .\install.ps1
# Sets up ai-agent.ps1 on the Windows PATH so it can be called from any directory.

param(
    [Alias('h')]
    [switch]$Help,
    [string]$InstallDir = "$env:USERPROFILE\Scripts"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Launcher  = Join-Path $ScriptDir "ai-agent.ps1"

function Show-Usage {
    Write-Host @"
Usage: .\install.ps1 [OPTIONS]

Copies ai-agent.ps1 to a directory on your PowerShell PATH.

Options:
  -InstallDir <path>   Destination directory (default: ~\Scripts)
  -h, -Help            Show this help

After install, run 'ai-agent' from any PowerShell window.
"@
}

if ($Help) { Show-Usage; exit 0 }

Write-Host "AI Agent Shell - Windows Installer" -ForegroundColor Cyan
Write-Host ""

# Verify launcher exists in repo
if (-not (Test-Path $Launcher)) {
    Write-Host "ERROR: ai-agent.ps1 not found at: $Launcher" -ForegroundColor Red
    exit 1
}

# Create install dir
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
    Write-Host "Created: $InstallDir" -ForegroundColor Green
}

# Copy launcher
$Dest = Join-Path $InstallDir "ai-agent.ps1"
Copy-Item -Path $Launcher -Destination $Dest -Force
Write-Host "Installed: $Dest" -ForegroundColor Green

# Check if InstallDir is in PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$InstallDir", "User")
    Write-Host "Added $InstallDir to user PATH" -ForegroundColor Green
    Write-Host "Restart PowerShell for PATH change to take effect." -ForegroundColor Yellow
} else {
    Write-Host "$InstallDir already in PATH" -ForegroundColor Green
}

# Credentials check
$CredsPath = "$env:USERPROFILE\.claude\.credentials.json"
if (Test-Path $CredsPath) {
    Write-Host "Found Claude credentials at: $CredsPath" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "NOTE: No Claude credentials found at: $CredsPath" -ForegroundColor Yellow
    Write-Host "Claude will prompt for login on first run." -ForegroundColor Yellow
    Write-Host "After logging in via the container, credentials persist automatically." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Run 'ai-agent' from any directory to launch the container." -ForegroundColor Cyan
