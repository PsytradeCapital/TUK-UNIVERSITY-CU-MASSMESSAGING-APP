#!/usr/bin/env pwsh

Write-Host "Deploying Firebase Security Rules..." -ForegroundColor Green
Write-Host ""

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version 2>$null
    Write-Host "Firebase CLI version: $firebaseVersion" -ForegroundColor Blue
} catch {
    Write-Host "Error: Firebase CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Firebase CLI: npm install -g firebase-tools" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if user is logged in
try {
    firebase projects:list 2>$null | Out-Null
} catch {
    Write-Host "You need to login to Firebase first" -ForegroundColor Yellow
    firebase login
}

Write-Host "Current Firebase project:" -ForegroundColor Blue
firebase use

Write-Host ""
Write-Host "Deploying Firestore security rules..." -ForegroundColor Yellow
firebase deploy --only firestore:rules

Write-Host ""
Write-Host "Deploying Firestore indexes..." -ForegroundColor Yellow
firebase deploy --only firestore:indexes

Write-Host ""
Write-Host "Deploying Storage security rules..." -ForegroundColor Yellow
firebase deploy --only storage

Write-Host ""
Write-Host "Security rules deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "You can test the rules using the Firebase Emulator:" -ForegroundColor Blue
Write-Host "firebase emulators:start --only firestore,auth,storage" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to continue"