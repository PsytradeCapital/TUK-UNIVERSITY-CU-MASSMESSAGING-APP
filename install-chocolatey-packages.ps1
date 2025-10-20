# Install all required packages using Chocolatey
# Run as Administrator

Write-Host "Installing development tools via Chocolatey..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Install Chocolatey if not present
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# List of packages to install
$packages = @(
    "git",
    "androidstudio", 
    "openjdk11",
    "flutter"
)

Write-Host "Installing packages: $($packages -join ', ')" -ForegroundColor Cyan

foreach ($package in $packages) {
    Write-Host "Installing $package..." -ForegroundColor Yellow
    try {
        choco install $package -y
        Write-Host "$package installed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install $package" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "Please restart your terminal and run 'flutter doctor'" -ForegroundColor Cyan

Read-Host "Press Enter to exit"