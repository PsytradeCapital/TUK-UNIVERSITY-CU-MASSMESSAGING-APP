# Flutter Installation Script for Windows
# Run this script as Administrator in PowerShell

param(
    [string]$InstallPath = "C:\flutter",
    [switch]$SkipAndroidStudio
)

Write-Host "TUK CU Mass Messaging App - Flutter Installation Script" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Function to add to PATH
function Add-ToPath {
    param([string]$PathToAdd)
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*$PathToAdd*") {
        Write-Host "Adding $PathToAdd to system PATH..." -ForegroundColor Yellow
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$PathToAdd", "Machine")
        $env:PATH = "$env:PATH;$PathToAdd"
        Write-Host "Added to PATH successfully" -ForegroundColor Green
    } else {
        Write-Host "$PathToAdd already in PATH" -ForegroundColor Green
    }
}

# Function to download file
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-Host "Downloading from $Url..." -ForegroundColor Yellow
    try {
        # Use System.Net.WebClient for better compatibility
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Host "Download completed: $OutputPath" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to extract ZIP file
function Extract-ZipFile {
    param(
        [string]$ZipPath,
        [string]$ExtractPath
    )
    
    Write-Host "Extracting $ZipPath to $ExtractPath..." -ForegroundColor Yellow
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
        Write-Host "Extraction completed" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check if Flutter is already installed
Write-Host "Checking for existing Flutter installation..." -ForegroundColor Cyan
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Flutter is already installed:" -ForegroundColor Green
        Write-Host $flutterVersion -ForegroundColor White
        $continue = Read-Host "Do you want to reinstall Flutter? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Skipping Flutter installation" -ForegroundColor Yellow
            $skipFlutter = $true
        }
    }
} catch {
    Write-Host "Flutter not found, proceeding with installation..." -ForegroundColor Yellow
}

if (-not $skipFlutter) {
    # Create installation directory
    Write-Host "Creating installation directory: $InstallPath" -ForegroundColor Cyan
    if (Test-Path $InstallPath) {
        Write-Host "Directory already exists, removing old installation..." -ForegroundColor Yellow
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    # Download Flutter SDK
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip"
    $flutterZip = "$env:TEMP\flutter_windows.zip"
    
    Write-Host "Downloading Flutter SDK..." -ForegroundColor Cyan
    if (-not (Download-File -Url $flutterUrl -OutputPath $flutterZip)) {
        Write-Host "Failed to download Flutter SDK" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Extract Flutter SDK
    Write-Host "Extracting Flutter SDK..." -ForegroundColor Cyan
    $extractPath = Split-Path $InstallPath -Parent
    if (-not (Extract-ZipFile -ZipPath $flutterZip -ExtractPath $extractPath)) {
        Write-Host "Failed to extract Flutter SDK" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Add Flutter to PATH
    $flutterBinPath = "$InstallPath\bin"
    Add-ToPath -PathToAdd $flutterBinPath

    # Clean up
    Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue

    Write-Host "Flutter SDK installed successfully!" -ForegroundColor Green
}

# Install Git if not present
Write-Host "Checking for Git..." -ForegroundColor Cyan
try {
    git --version | Out-Null
    Write-Host "Git is already installed" -ForegroundColor Green
} catch {
    Write-Host "Installing Git..." -ForegroundColor Yellow
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"
    
    if (Download-File -Url $gitUrl -OutputPath $gitInstaller) {
        Write-Host "Running Git installer..." -ForegroundColor Yellow
        Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT" -Wait
        Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "Git installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to download Git installer" -ForegroundColor Red
    }
}

# Install Android Studio if not skipped
if (-not $SkipAndroidStudio) {
    Write-Host "Checking for Android Studio..." -ForegroundColor Cyan
    $androidStudioPath = "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe"
    if (Test-Path $androidStudioPath) {
        Write-Host "Android Studio is already installed" -ForegroundColor Green
    } else {
        Write-Host "Downloading Android Studio..." -ForegroundColor Yellow
        $androidStudioUrl = "https://redirector.gvt1.com/edgedl/android/studio/install/2023.1.1.28/android-studio-2023.1.1.28-windows.exe"
        $androidStudioInstaller = "$env:TEMP\android-studio-installer.exe"
        
        if (Download-File -Url $androidStudioUrl -OutputPath $androidStudioInstaller) {
            Write-Host "Running Android Studio installer..." -ForegroundColor Yellow
            Write-Host "Please follow the installation wizard and install Android SDK" -ForegroundColor Cyan
            Start-Process -FilePath $androidStudioInstaller -Wait
            Remove-Item $androidStudioInstaller -Force -ErrorAction SilentlyContinue
            Write-Host "Android Studio installation completed!" -ForegroundColor Green
        } else {
            Write-Host "Failed to download Android Studio installer" -ForegroundColor Red
        }
    }
}

# Refresh environment variables
Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

# Run Flutter Doctor
Write-Host "Running Flutter Doctor..." -ForegroundColor Cyan
Write-Host "This will check your Flutter installation and show any remaining setup steps" -ForegroundColor Yellow
Write-Host ""

try {
    flutter doctor
} catch {
    Write-Host "Flutter command not found. Please restart your terminal and run 'flutter doctor'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart your terminal/PowerShell" -ForegroundColor White
Write-Host "2. Run 'flutter doctor' to verify installation" -ForegroundColor White
Write-Host "3. Run 'flutter doctor --android-licenses' to accept Android licenses" -ForegroundColor White
Write-Host "4. Navigate to your project directory and run 'flutter pub get'" -ForegroundColor White
Write-Host "5. Run 'flutter run' to start the app" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"