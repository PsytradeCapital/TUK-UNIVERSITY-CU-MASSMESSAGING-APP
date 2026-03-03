# Build Troubleshooting Guide

## Issue: Build Taking Too Long (30+ minutes)

### What Happened
The initial build command got stuck at the Gradle compilation stage for over 30 minutes.

### Root Causes
1. Flutter lock file not released properly
2. Dependency resolution issues
3. Gradle daemon might be stuck

### Solution Applied
1. Stopped the stuck build process
2. Cleared Flutter lock files: `del /F /Q "%LOCALAPPDATA%\Temp\flutter_tools_lock*"`
3. Ran `flutter pub get` separately to resolve dependencies first
4. Started fresh build with simpler command: `flutter build apk --release`

## Build Commands Comparison

### Original Command (Stuck)
```bash
cmd /c "set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr && C:\flutter\bin\flutter.bat build apk --release --no-tree-shake-icons"
```
- Sets JAVA_HOME explicitly
- Uses --no-tree-shake-icons flag
- Got stuck at Gradle compilation

### New Command (Working)
```bash
C:\flutter\bin\flutter.bat build apk --release
```
- Simpler command
- Uses default JAVA_HOME from system
- Resolved dependencies first with `flutter pub get`

## If Build Gets Stuck Again

### Step 1: Stop the Build
- Press Ctrl+C in terminal
- Or kill the flutter process

### Step 2: Clear Lock Files
```bash
del /F /Q "%LOCALAPPDATA%\Temp\flutter_tools_lock*"
```

### Step 3: Clean Build Cache
```bash
C:\flutter\bin\flutter.bat clean
```

### Step 4: Resolve Dependencies
```bash
C:\flutter\bin\flutter.bat pub get
```

### Step 5: Try Alternative Build Methods

#### Option A: Split Per ABI (Faster)
```bash
C:\flutter\bin\flutter.bat build apk --release --split-per-abi
```
- Builds separate APKs for each architecture
- Faster build time
- Smaller APK files
- Output: `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`, `app-x86_64-release.apk`

#### Option B: Standard Build
```bash
C:\flutter\bin\flutter.bat build apk --release
```
- Builds universal APK
- Works on all devices
- Larger file size
- Output: `app-release.apk`

#### Option C: Debug Build (Fastest)
```bash
C:\flutter\bin\flutter.bat build apk --debug
```
- Much faster (1-2 minutes)
- Good for testing
- Not for production
- Output: `app-debug.apk`

## Gradle Issues

### If Gradle Daemon is Stuck
```bash
cd android
gradlew.bat --stop
cd ..
```

### If Gradle Build Fails
```bash
cd android
gradlew.bat clean
cd ..
C:\flutter\bin\flutter.bat clean
C:\flutter\bin\flutter.bat build apk --release
```

## Expected Build Times

- **First Build**: 5-10 minutes (downloads dependencies)
- **Subsequent Builds**: 2-5 minutes
- **With --split-per-abi**: 1-3 minutes
- **Debug Build**: 1-2 minutes

## Signs of a Stuck Build

1. Spinner animation stops moving
2. No new output for 5+ minutes
3. CPU usage drops to 0%
4. Build time exceeds 15 minutes

## Current Build Status

Build started with: `C:\flutter\bin\flutter.bat build apk --release`
- Dependencies resolved successfully
- Gradle compilation in progress
- Expected completion: 2-5 minutes
