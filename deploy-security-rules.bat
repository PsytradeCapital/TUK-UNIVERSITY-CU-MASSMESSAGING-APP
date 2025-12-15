@echo off
echo Deploying Firebase Security Rules...
echo.

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Firebase CLI is not installed or not in PATH
    echo Please install Firebase CLI: npm install -g firebase-tools
    pause
    exit /b 1
)

REM Check if user is logged in
firebase projects:list >nul 2>&1
if %errorlevel% neq 0 (
    echo You need to login to Firebase first
    firebase login
)

echo Current Firebase project:
firebase use

echo.
echo Deploying Firestore security rules...
firebase deploy --only firestore:rules

echo.
echo Deploying Firestore indexes...
firebase deploy --only firestore:indexes

echo.
echo Deploying Storage security rules...
firebase deploy --only storage

echo.
echo Security rules deployment completed!
echo.
echo You can test the rules using the Firebase Emulator:
echo firebase emulators:start --only firestore,auth,storage
echo.
pause