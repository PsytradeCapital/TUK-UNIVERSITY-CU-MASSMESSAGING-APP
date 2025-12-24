# TUK CU Mass Messaging App

**Technical University of Kenya Christian Union - Mass Messaging Application**

*"Raising to Serve"*

## 🚀 Overview

A comprehensive Flutter mobile application designed for the Technical University of Kenya Christian Union to manage attendee registration and mass messaging with advanced personalization features.

## ✅ Key Features

### Core Functionality
- **Attendee Registration** - Quick and efficient member registration
- **Mass Messaging** - Send personalized SMS to all attendees
- **Smart Personalization** - Automatic {name} placeholder replacement
- **Cloud Sync** - Real-time data synchronization across devices
- **Offline Support** - Works without internet connection

### Advanced Features
- **Firebase Integration** - Authentication, Firestore, Analytics
- **Document Scanning** - OCR text recognition capabilities
- **Analytics Dashboard** - Comprehensive reporting and insights
- **Multi-user Support** - Secure user management system
- **Export/Backup** - CSV export and data backup functionality

## 🔧 Technical Stack

- **Framework**: Flutter 3.16.5
- **Backend**: Firebase (Firestore, Auth, Analytics, Storage)
- **Database**: SQLite (local) + Cloud Firestore
- **Authentication**: Firebase Auth with email/password
- **SMS**: Android SMS integration
- **OCR**: Google ML Kit Text Recognition
- **State Management**: Provider pattern

## 📱 Installation

### Prerequisites
- Flutter SDK 3.16.5+
- Android SDK (API level 23+)
- Firebase project configured

### Quick Setup
1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase (see setup guide)
4. Build APK: `flutter build apk --release`
5. Install on device: `flutter install`

### Build Scripts
- `build-with-multidex.bat` - Build with multidex support
- `install-apk-clean.bat` - Clean installation process
- `fix-firebase-auth.md` - Firebase authentication setup guide

## 🔐 Security Features

- **Encrypted Passwords** - Firebase Auth with scrypt hashing
- **Secure Authentication** - JWT token-based sessions
- **Data Encryption** - TLS/HTTPS for all communications
- **User Approval Workflow** - Admin verification system
- **Audit Trail** - Comprehensive logging system

## 📊 Personalization System

The app features an intelligent personalization system:

### With Placeholders
- `{name}` → Replaces with attendee's actual name
- `{Name}` → Capitalizes first letter
- `{NAME}` → Converts to uppercase
- `[name]`, `[Name]`, `[NAME]` → Alternative bracket format

### Without Placeholders
- Messages are sent exactly as typed
- No automatic greeting added (as per user requirements)

### Example Usage
```
Message: "Welcome {name} to our service!"
Result: "Welcome John Doe to our service!"

Message: "Service starts at 2 PM"
Result: "Service starts at 2 PM" (no modification)
```

## 🏗️ Architecture

### Offline-First Design
- Local SQLite database for immediate access
- Cloud sync when internet available
- Conflict resolution for data consistency
- Automatic retry mechanisms

### Service Layer
- `AuthService` - User authentication and management
- `CloudSyncService` - Firebase synchronization
- `SMSManager` - Message handling and personalization
- `ConnectivityService` - Network status monitoring

## 📋 Firebase Setup

1. Create Firebase project: `tuk-cu-mass-messaging`
2. Enable Authentication (Email/Password)
3. Set up Cloud Firestore
4. Configure Firebase Analytics
5. Add `google-services.json` to `android/app/`

See `fix-firebase-auth.md` for detailed setup instructions.

## 🚀 Production Ready

- ✅ APK built and tested (98MB)
- ✅ Firebase backend configured
- ✅ All core features functional
- ✅ Security measures implemented
- ✅ Comprehensive error handling
- ✅ Multi-device synchronization

## 📖 Documentation

- `fix-firebase-auth.md` - Firebase authentication setup
- `SETUP_GUIDE.md` - Complete installation guide
- `USER_GUIDE.md` - End-user documentation
- `TESTING_CHECKLIST.md` - Quality assurance checklist

## 🤝 Contributing

This application was developed for the Technical University of Kenya Christian Union. For contributions or support, please contact the development team.

## 📄 License

Developed for TUK Christian Union - "Raising to Serve"

---

**Built with ❤️ for the TUK CU Community**