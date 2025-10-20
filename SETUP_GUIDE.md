# Christian Union Attendance App - Setup Guide

## Prerequisites

### 1. Install Flutter SDK
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your system PATH
4. Restart command prompt/PowerShell

### 2. Install Android Studio
1. Download from: https://developer.android.com/studio
2. Install with Android SDK
3. Accept Android licenses: `flutter doctor --android-licenses`

### 3. Verify Installation
Run: `flutter doctor`

All items should show checkmarks ✓

## Running the App

### Method 1: Android Emulator
1. Open Android Studio → Tools → AVD Manager
2. Create and start a virtual device
3. In project directory, run: `flutter run`

### Method 2: Physical Android Device
1. Enable Developer Options on your Android device:
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"
2. Connect device via USB
3. Run: `flutter run`

### Method 3: Build APK for Installation
1. Build release APK: `flutter build apk --release`
2. APK location: `build/app/outputs/flutter-apk/app-release.apk`
3. Transfer to Android device and install

## App Features

### Core Functionality
- **PIN Authentication**: Secure app access with PIN setup
- **Attendee Registration**: Register attendees with name, phone, year, location
- **Service Management**: Start/end service sessions
- **SMS Messaging**: Send bulk SMS to registered attendees
- **Reports**: View attendance statistics and export data
- **Data Management**: Import/export attendee data

### Security Features
- PIN-based authentication
- Auto-lock functionality
- Encrypted data storage
- Secure SMS permissions

### Accessibility Features
- Screen reader support
- High contrast themes
- Minimum touch targets
- Semantic navigation
- Haptic feedback

## Troubleshooting

### Common Issues

1. **Flutter not recognized**
   - Ensure Flutter is in your PATH
   - Restart command prompt

2. **Android licenses not accepted**
   - Run: `flutter doctor --android-licenses`
   - Accept all licenses

3. **No devices found**
   - Enable USB debugging on Android device
   - Check device connection with: `flutter devices`

4. **Build errors**
   - Run: `flutter clean`
   - Run: `flutter pub get`
   - Try building again

### Getting Dependencies
If you encounter dependency issues:
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Permissions
The app requires these Android permissions:
- SMS permissions (for sending messages)
- Storage permissions (for data export)
- Phone permissions (for SMS functionality)

## Development Commands

### Useful Flutter Commands
- `flutter run` - Run app in debug mode
- `flutter run --release` - Run app in release mode
- `flutter build apk` - Build debug APK
- `flutter build apk --release` - Build release APK
- `flutter clean` - Clean build files
- `flutter pub get` - Get dependencies
- `flutter doctor` - Check Flutter installation

### Testing
- `flutter test` - Run unit tests
- `flutter drive --target=test_driver/app.dart` - Run integration tests

## App Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── screens/                  # UI screens
├── services/                 # Business logic
├── repositories/             # Data access
├── providers/                # State management
├── widgets/                  # Reusable UI components
├── theme/                    # App theming
└── utils/                    # Utility functions
```

## Support

For issues or questions:
1. Check Flutter documentation: https://docs.flutter.dev/
2. Check Android development guide: https://developer.android.com/docs
3. Review app logs: `flutter logs`

## Version Information
- Flutter SDK: >=3.10.0
- Dart SDK: >=3.0.0
- Android: API level 21+ (Android 5.0+)