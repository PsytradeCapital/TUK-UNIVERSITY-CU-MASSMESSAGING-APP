# Firebase Configuration Issue Fix

## Problem
The app shows "No Firebase App '[DEFAULT]' has been created" error.

## Root Cause
Firebase configuration files are missing or incorrect.

## Quick Fix Options

### Option 1: Build Offline Version (Recommended)
Build a version that works without Firebase for immediate use:

```bash
build-offline-apk.bat
```

### Option 2: Fix Firebase Configuration
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` folder
3. Rebuild the app

### Option 3: Use Local-Only Mode
The app can work in offline mode with local SQLite database only.

## Features Available in Offline Mode
✅ Attendee registration (local storage)
✅ Mass messaging (SMS simulation)
✅ Personalization (works perfectly)
✅ Local data storage
✅ Export/backup to files

## Features Requiring Firebase
❌ Cloud sync
❌ Real-time collaboration
❌ Cloud backup
❌ Analytics tracking

## Immediate Solution
Run the offline version which has all core functionality you need.