@echo off
echo Building Offline Version - No Firebase Required
echo ===============================================
echo.

echo This will create a version that works without Firebase.
echo All core features will work: messaging, personalization, local storage.
echo.

echo [1/3] Backing up current main.dart...
copy "lib\main.dart" "lib\main.dart.backup"

echo [2/3] Creating offline version...
echo Creating offline main.dart...

echo import 'package:flutter/material.dart'; > lib\main_offline.dart
echo import 'package:provider/provider.dart'; >> lib\main_offline.dart
echo import 'screens/home_screen.dart'; >> lib\main_offline.dart
echo import 'providers/service_session_provider.dart'; >> lib\main_offline.dart
echo import 'providers/app_state_provider.dart'; >> lib\main_offline.dart
echo import 'providers/navigation_provider.dart'; >> lib\main_offline.dart
echo import 'theme/app_theme.dart'; >> lib\main_offline.dart
echo. >> lib\main_offline.dart
echo void main() { >> lib\main_offline.dart
echo   WidgetsFlutterBinding.ensureInitialized(); >> lib\main_offline.dart
echo   runApp(const TUKCUApp()); >> lib\main_offline.dart
echo } >> lib\main_offline.dart
echo. >> lib\main_offline.dart
echo class TUKCUApp extends StatelessWidget { >> lib\main_offline.dart
echo   const TUKCUApp({Key? key}) : super(key: key); >> lib\main_offline.dart
echo. >> lib\main_offline.dart
echo   @override >> lib\main_offline.dart
echo   Widget build(BuildContext context) { >> lib\main_offline.dart
echo     return MultiProvider( >> lib\main_offline.dart
echo       providers: [ >> lib\main_offline.dart
echo         ChangeNotifierProvider(create: (_) =^> ServiceSessionProvider()), >> lib\main_offline.dart
echo         ChangeNotifierProvider(create: (_) =^> AppStateProvider()), >> lib\main_offline.dart
echo         ChangeNotifierProvider(create: (_) =^> NavigationProvider()), >> lib\main_offline.dart
echo       ], >> lib\main_offline.dart
echo       child: MaterialApp( >> lib\main_offline.dart
echo         title: 'TUK CU Mass Messaging', >> lib\main_offline.dart
echo         theme: AppTheme.lightTheme, >> lib\main_offline.dart
echo         home: const HomeScreen(), >> lib\main_offline.dart
echo         debugShowCheckedModeBanner: false, >> lib\main_offline.dart
echo       ), >> lib\main_offline.dart
echo     ); >> lib\main_offline.dart
echo   } >> lib\main_offline.dart
echo } >> lib\main_offline.dart

echo [3/3] Use offline version and build...
copy "lib\main_offline.dart" "lib\main.dart"

echo Building offline APK...
flutter build apk --release

echo.
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ SUCCESS! Offline APK built successfully!
    echo.
    echo This version works without Firebase and includes:
    echo ✅ Attendee registration
    echo ✅ Mass messaging with personalization
    echo ✅ Local data storage
    echo ✅ SMS functionality
    echo.
    echo Install with: flutter install --release
) else (
    echo ❌ Build failed. Restoring original main.dart...
    copy "lib\main.dart.backup" "lib\main.dart"
)

pause