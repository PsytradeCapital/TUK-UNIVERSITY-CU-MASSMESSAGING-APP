# Flutter Installation Script for Windows
# This script downloads and installs Flutter SDK

Write-Host "🚀 Flutter Installation Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "⚠️  This script should be run as Administrator for best results" -ForegroundColor Yellow
    Write-Host "   Some features may not work properly without admin privileges" -ForegroundColor Yellow
    Write-Host ""
}

# Configuration
$flutterVersion = "3.16.5"  # Stable version
$installPath = "C:\flutter"
$downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$flutterVersion-stable.zip"
$zipPath = "$env:TEMP\flutter_windows.zip"

Write-Host "📋 Installation Configuration:" -ForegroundColor Green
Write-Host "   Flutter Version: $flutterVersion" -ForegroundColor White
Write-Host "   Install Path: $installPath" -ForegroundColor White
Write-Host "   Download URL: $downloadUrl" -ForegroundColor White
Write-Host ""

# Check if Flutter is already installed
if (Test-Path "$installPath\bin\flutter.bat") {
    Write-Host "✅ Flutter is already installed at $installPath" -ForegroundColor Green
    
    # Check version
    $currentVersion = & "$installPath\bin\flutter.bat" --version 2>$null | Select-String "Flutter" | ForEach-Object { $_.ToString().Split()[1] }
    Write-Host "   Current version: $currentVersion" -ForegroundColor White
    
    $continue = Read-Host "Do you want to reinstall? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Step 1: Download Flutter
Write-Host "📥 Step 1: Downloading Flutter SDK..." -ForegroundColor Blue
try {
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    Write-Host "   Downloading from: $downloadUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "   ✅ Download completed" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Extract Flutter
Write-Host "📦 Step 2: Extracting Flutter SDK..." -ForegroundColor Blue
try {
    if (Test-Path $installPath) {
        Write-Host "   Removing existing installation..." -ForegroundColor Gray
        Remove-Item $installPath -Recurse -Force
    }
    
    Write-Host "   Extracting to: $installPath" -ForegroundColor Gray
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
    Write-Host "   ✅ Extraction completed" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Add to PATH
Write-Host "🔧 Step 3: Adding Flutter to PATH..." -ForegroundColor Blue
try {
    $flutterBinPath = "$installPath\bin"
    
    # Get current PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    
    # Check if Flutter is already in PATH
    if ($currentPath -notlike "*$flutterBinPath*") {
        # Add Flutter to user PATH
        $newPath = "$currentPath;$flutterBinPath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "   ✅ Flutter added to PATH" -ForegroundColor Green
        Write-Host "   📝 Note: You may need to restart your terminal/IDE" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Flutter is already in PATH" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Failed to add to PATH: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   📝 Please manually add $flutterBinPath to your PATH" -ForegroundColor Yellow
}

# Step 4: Run Flutter Doctor
Write-Host "🩺 Step 4: Running Flutter Doctor..." -ForegroundColor Blue
try {
    # Update PATH for current session
    $env:PATH = "$env:PATH;$installPath\bin"
    
    Write-Host "   Checking Flutter installation..." -ForegroundColor Gray
    & "$installPath\bin\flutter.bat" doctor
    Write-Host "   ✅ Flutter doctor completed" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Flutter doctor failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Accept Android Licenses (if Android SDK is available)
Write-Host "📱 Step 5: Checking Android setup..." -ForegroundColor Blue
try {
    $androidSdkPath = [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
    if ($androidSdkPath -and (Test-Path "$androidSdkPath\cmdline-tools")) {
        Write-Host "   Android SDK found, accepting licenses..." -ForegroundColor Gray
        & "$installPath\bin\flutter.bat" doctor --android-licenses
        Write-Host "   ✅ Android licenses accepted" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Android SDK not found" -ForegroundColor Yellow
        Write-Host "   📝 Install Android Studio to set up Android development" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⚠️  Could not accept Android licenses: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Cleanup
Write-Host "🧹 Cleaning up..." -ForegroundColor Blue
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "   ✅ Temporary files cleaned" -ForegroundColor Green
}

# Final verification
Write-Host "🎉 Installation Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal/command prompt" -ForegroundColor White
Write-Host "2. Run 'flutter doctor' to verify installation" -ForegroundColor White
Write-Host "3. Install Android Studio for Android development" -ForegroundColor White
Write-Host "4. Install VS Code with Flutter extension" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Useful Commands:" -ForegroundColor Yellow
Write-Host "   flutter doctor          - Check installation" -ForegroundColor White
Write-Host "   flutter create myapp    - Create new project" -ForegroundColor White
Write-Host "   flutter run             - Run your app" -ForegroundColor White
Write-Host "   flutter build apk       - Build APK" -ForegroundColor White
Write-Host ""
Write-Host "📁 Flutter installed at: $installPath" -ForegroundColor Cyan
Write-Host "🌐 Documentation: https://docs.flutter.dev" -ForegroundColor Cyan