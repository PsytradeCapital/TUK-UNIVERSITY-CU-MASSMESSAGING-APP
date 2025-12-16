# TUK CU Mass Messaging App - Release Build Script
# PowerShell version for better error handling and cross-platform support

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TUK CU Mass Messaging App - Release Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check command existence
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Check Flutter installation
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
if (-not (Test-Command "flutter")) {
    Write-Host "ERROR: Flutter not found. Please install Flutter and add to PATH." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

flutter doctor --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter doctor failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check Firebase configuration
Write-Host ""
Write-Host "Checking Firebase configuration..." -ForegroundColor Yellow
if (-not (Test-Path "android/app/google-services.json")) {
    Write-Host "ERROR: google-services.json not found in android/app/" -ForegroundColor Red
    Write-Host "Please download from Firebase Console and place in android/app/" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check pubspec.yaml for required dependencies
Write-Host "Checking dependencies..." -ForegroundColor Yellow
$pubspec = Get-Content "pubspec.yaml" -Raw
$requiredDeps = @("firebase_core", "firebase_auth", "cloud_firestore", "firebase_analytics", "firebase_crashlytics")
foreach ($dep in $requiredDeps) {
    if ($pubspec -notmatch $dep) {
        Write-Host "WARNING: $dep not found in pubspec.yaml" -ForegroundColor Yellow
    }
}

# Clean previous builds
Write-Host ""
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter clean failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Get dependencies
Write-Host ""
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Run code analysis
Write-Host ""
Write-Host "Running code analysis..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Code analysis found issues." -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Build cancelled by user" -ForegroundColor Red
        exit 1
    }
}

# Build release APK
Write-Host ""
Write-Host "Building release APK..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray

$buildStart = Get-Date
flutter build apk --release --verbose
$buildEnd = Get-Date
$buildDuration = $buildEnd - $buildStart

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: APK build failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Build success
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# APK information
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (Test-Path $apkPath) {
    $apkSize = (Get-Item $apkPath).Length
    $apkSizeMB = [math]::Round($apkSize / 1MB, 2)
    
    Write-Host "APK Location: $apkPath" -ForegroundColor Green
    Write-Host "APK Size: $apkSizeMB MB ($apkSize bytes)" -ForegroundColor Green
    Write-Host "Build Duration: $($buildDuration.Minutes)m $($buildDuration.Seconds)s" -ForegroundColor Green
} else {
    Write-Host "WARNING: APK file not found at expected location" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Test APK on multiple devices" -ForegroundColor White
Write-Host "2. Verify Firebase connectivity" -ForegroundColor White
Write-Host "3. Test offline/online sync" -ForegroundColor White
Write-Host "4. Verify SMS functionality" -ForegroundColor White
Write-Host "5. Test user registration and approval" -ForegroundColor White
Write-Host "6. Test multi-user collaboration" -ForegroundColor White
Write-Host "7. Verify data encryption" -ForegroundColor White
Write-Host "8. Test analytics and error tracking" -ForegroundColor White

Write-Host ""
Write-Host "Testing Checklist:" -ForegroundColor Cyan
Write-Host "□ Install APK on test device" -ForegroundColor White
Write-Host "□ Create new user account" -ForegroundColor White
Write-Host "□ Test admin approval workflow" -ForegroundColor White
Write-Host "□ Register test attendees" -ForegroundColor White
Write-Host "□ Send test messages" -ForegroundColor White
Write-Host "□ Test offline mode" -ForegroundColor White
Write-Host "□ Test sync between devices" -ForegroundColor White
Write-Host "□ Verify data encryption" -ForegroundColor White
Write-Host "□ Test analytics dashboard" -ForegroundColor White
Write-Host "□ Test error handling" -ForegroundColor White

# Open APK location
Write-Host ""
Write-Host "Opening APK location..." -ForegroundColor Yellow
if ($IsWindows) {
    Start-Process "explorer" -ArgumentList "build\app\outputs\flutter-apk\"
} elseif ($IsMacOS) {
    Start-Process "open" -ArgumentList "build/app/outputs/flutter-apk/"
} elseif ($IsLinux) {
    Start-Process "xdg-open" -ArgumentList "build/app/outputs/flutter-apk/"
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"