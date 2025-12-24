# Fix Firebase Authentication Error

## Problem
Getting "authentication error" when trying to register an account.

## Root Cause
Email/Password authentication is not enabled in Firebase Console.

## Solution - Enable Authentication in Firebase Console

### Step 1: Go to Firebase Console
1. Open https://console.firebase.google.com/
2. Select your project: **tuk-cu-mass-messaging**

### Step 2: Enable Authentication
1. In the left sidebar, click **"Authentication"**
2. Click **"Get started"** if you haven't set up Authentication yet
3. Go to **"Sign-in method"** tab
4. Click on **"Email/Password"**
5. **Enable** the first option (Email/Password)
6. Click **"Save"**

### Step 3: Test Registration
1. Go back to your app
2. Try registering a new account
3. Should work now!

## Alternative: Use Anonymous Authentication (Temporary)
If you want to test the app immediately without setting up email auth:

1. In Firebase Console → Authentication → Sign-in method
2. Enable **"Anonymous"** authentication
3. The app can work with anonymous users for testing

## What This Enables
✅ User registration with email/password
✅ User login/logout
✅ Cloud data sync per user
✅ Multi-user support
✅ Secure authentication

## Quick Test
After enabling authentication:
1. Register with: test@example.com / password123
2. App should create account and log you in
3. All Firebase features will work