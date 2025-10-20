# Terminal Installation Commands

## Option 1: Automated Installation (Recommended)

### Windows PowerShell (Run as Administrator)
```powershell
# Quick setup - installs everything automatically
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\quick-setup.ps1
```

### Windows Command Prompt (Run as Administrator)
```cmd
# Complete installation
install-all.bat
```

## Option 2: Using Package Managers

### Using Chocolatey (Windows)
```powershell
# Install Chocolatey first (run as Administrator)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install all required packages
choco install git androidstudio openjdk11 flutter -y
```

### Using Winget (Windows 10/11)
```cmd
# Install Git
winget install Git.Git

# Install Android Studio
winget install Google.AndroidStudio

# Install Java JDK
winget install EclipseAdoptium.Temurin.11.JDK

# Install Flutter (manual download still required)
# Flutter is not available via winget, use manual method below
```

### Using Scoop (Windows)
```powershell
# Install Scoop
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Add extras bucket
scoop bucket add extras

# Install packages
scoop install git
scoop install android-studio
scoop install openjdk11
# Note: Flutter not available via scoop, use manual method
```

## Option 3: Manual Download Commands

### Download Flutter SDK
```powershell
# PowerShell
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip" -OutFile "flutter.zip"
Expand-Archive -Path "flutter.zip" -DestinationPath "C:\"
```

```cmd
# Command Prompt (using curl)
curl -L -o flutter.zip "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip"
tar -xf flutter.zip -C C:\
```

### Download Git
```powershell
# PowerShell
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe" -OutFile "git-installer.exe"
.\git-installer.exe /SILENT
```

### Download Android Studio
```powershell
# PowerShell
Invoke-WebRequest -Uri "https://redirector.gvt1.com/edgedl/android/studio/install/2023.1.1.28/android-studio-2023.1.1.28-windows.exe" -OutFile "android-studio.exe"
.\android-studio.exe
```

## Option 4: One-Line Installation Commands

### Complete Setup (PowerShell as Administrator)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')); choco install git androidstudio openjdk11 -y; Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip" -OutFile "$env:TEMP\flutter.zip"; Expand-Archive -Path "$env:TEMP\flutter.zip" -DestinationPath "C:\" -Force; [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\flutter\bin", "Machine")
```

### Flutter Only (PowerShell)
```powershell
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip" -OutFile "$env:TEMP\flutter.zip"; Expand-Archive -Path "$env:TEMP\flutter.zip" -DestinationPath "C:\" -Force; [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\flutter\bin", "Machine")
```

## After Installation Commands

### Verify Installation
```cmd
flutter doctor
```

### Accept Android Licenses
```cmd
flutter doctor --android-licenses
```

### Setup Project
```cmd
# Navigate to project directory
cd path\to\your\project

# Get dependencies
flutter pub get

# Run the app
flutter run

# Or build APK
flutter build apk --release
```

## Environment Variables Setup

### Add Flutter to PATH (Command Prompt)
```cmd
setx PATH "%PATH%;C:\flutter\bin" /M
```

### Add Flutter to PATH (PowerShell)
```powershell
[Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\flutter\bin", "Machine")
```

## Troubleshooting Commands

### Clean Flutter Project
```cmd
flutter clean
flutter pub get
```

### Check Flutter Installation
```cmd
flutter doctor -v
```

### List Available Devices
```cmd
flutter devices
```

### Check Flutter Version
```cmd
flutter --version
```

### Update Flutter
```cmd
flutter upgrade
```

## Quick Run Commands

After everything is installed:

```cmd
# In your project directory
flutter pub get
flutter run
```

Or use the provided script:
```cmd
run-app.bat
```

## Build Commands

### Debug APK
```cmd
flutter build apk
```

### Release APK
```cmd
flutter build apk --release
```

### App Bundle (for Play Store)
```cmd
flutter build appbundle --release
```

## Notes

1. **Run as Administrator**: Most installation commands require administrator privileges
2. **Restart Terminal**: After installation, restart your terminal to refresh PATH variables
3. **Android SDK**: Make sure to install Android SDK through Android Studio
4. **Licenses**: Accept all Android licenses with `flutter doctor --android-licenses`
5. **Device Setup**: Enable USB debugging on Android devices or use an emulator