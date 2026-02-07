@echo off
echo ========================================
echo  Fix Admin User Script
echo ========================================
echo.
echo This will:
echo 1. Show your current user status
echo 2. Delete your Firestore user document
echo 3. Keep your Firebase Auth account
echo 4. Allow you to sign in (will auto-create approved admin)
echo.
pause

echo.
echo Checking Firebase project...
firebase use tuk-cu-mass-messaging

echo.
echo Opening Firebase Console...
echo Please manually:
echo 1. Go to Firestore Database
echo 2. Find the 'users' collection
echo 3. Find the document with email: martinmbugua300@gmail.com
echo 4. Delete that document
echo 5. Then try signing in again in the app
echo.

start https://console.firebase.google.com/project/tuk-cu-mass-messaging/firestore/data/~2Fusers

echo.
echo Press any key after you've deleted the user document...
pause

echo.
echo Done! Now try signing in with the app.
echo The app will auto-create your user as an approved admin.
pause
