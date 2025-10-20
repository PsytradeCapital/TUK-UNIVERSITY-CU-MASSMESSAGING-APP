# Quick Setup Script for Christian Union Attendance App
# This script installs everything needed to run the Flutter app

Write-Host "Christian Union Attendance App - Quick Setup" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Attempting to restart as Administrator..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
    exit
}

# Set TLS version for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Create temp directory
$tempDir = "$env:TEMP\flutter_setup"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-Host "Step 1: Installing Chocolatey (Package Manager)..." -ForegroundColor Cyan
try {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Chocolatey already installed" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to install Chocolatey, proceeding with manual installation..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 2: Installing Git..." -ForegroundColor Cyan
try {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install git -y
    } else {
        # Manual Git installation
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
        $gitPath = "$tempDir\git-installer.exe"
        Write-Host "Downloading Git..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitPath
        Write-Host "Installing Git..." -ForegroundColor Yellow
        Start-Process -FilePath $gitPath -ArgumentList "/SILENT" -Wait
    }
    Write-Host "Git installation completed!" -ForegroundColor Green
} catch {
    Write-Host "Git installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 3: Installing Flutter SDK..." -ForegroundColor Cyan
try {
    $flutterPath = "C:\flutter"
    if (Test-Path $flutterPath) {
        Write-Host "Removing existing Flutter installation..." -ForegroundColor Yellow
        Remove-Item $flutterPath -Recurse -Force
    }
    
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip"
    $flutterZip = "$tempDir\flutter.zip"
    
    Write-Host "Downloading Flutter SDK..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip
    
    Write-Host "Extracting Flutter SDK..." -ForegroundColor Yellow
    Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force
    
    # Add to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*C:\flutter\bin*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;C:\flutter\bin", "Machine")
        $env:PATH = "$env:PATH;C:\flutter\bin"
    }
    
    Write-Host "Flutter SDK installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Flutter installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 4: Installing Android Studio..." -ForegroundColor Cyan
try {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install androidstudio -y
    } else {
        # Manual Android Studio installation
        $androidUrl = "https://redirector.gvt1.com/edgedl/android/studio/install/2023.1.1.28/android-studio-2023.1.1.28-windows.exe"
        $androidPath = "$tempDir\android-studio.exe"
        Write-Host "Downloading Android Studio..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $androidUrl -OutFile $androidPath
        Write-Host "Starting Android Studio installer..." -ForegroundColor Yellow
        Write-Host "Please complete the Android Studio installation and install Android SDK" -ForegroundColor Cyan
        Start-Process -FilePath $androidPath -Wait
    }
    Write-Host "Android Studio installation completed!" -ForegroundColor Green
} catch {
    Write-Host "Android Studio installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 5: Installing Java JDK..." -ForegroundColor Cyan
try {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install openjdk11 -y
    } else {
        Write-Host "Please install Java JDK manually from: https://adoptium.net/" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Java installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up
Write-Host ""
Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Refresh environment
Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Running Flutter Doctor to verify installation..." -ForegroundColor Cyan
try {
    & "C:\flutter\bin\flutter.bat" doctor
} catch {
    Write-Host "Flutter not found in PATH. Please restart your terminal." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "1. Restart your terminal/PowerShell" -ForegroundColor White
Write-Host "2. Run: flutter doctor --android-licenses" -ForegroundColor White
Write-Host "3. Navigate to your project directory" -ForegroundColor White
Write-Host "4. Run: flutter pub get" -ForegroundColor White
Write-Host "5. Connect Android device or start emulator" -ForegroundColor White
Write-Host "6. Run: flutter run" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"