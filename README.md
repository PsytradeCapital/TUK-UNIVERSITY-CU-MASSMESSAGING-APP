# TUK CU Mass Messaging App
## "Raising to Serve"

A comprehensive cloud-enabled mass messaging and attendance management application for the Technical University of Kenya Christian Union (TUK CU). Features real-time multi-user collaboration, cloud synchronization, and secure data management for efficient attendee registration and bulk SMS communication during services and events.

## Features

### 🌟 New Cloud Features
- **Multi-User Collaboration**: Multiple CU leaders can access the same database from different devices
- **Real-Time Synchronization**: Live data updates across all connected devices
- **Cloud Authentication**: Secure Firebase-based user authentication with approval workflow
- **Offline-First Design**: Full functionality offline with automatic sync when connection restored
- **Data Encryption**: End-to-end encryption for sensitive attendee information
- **Analytics Dashboard**: Comprehensive system monitoring and user activity analytics
- **Error Tracking**: Automatic error reporting and crash analytics

### Core Functionality
- **Attendee Registration**: Quick registration with name, phone, year, and location
- **Smart Search**: Find returning attendees instantly with encrypted phone lookup
- **Service Management**: Start/end service sessions with attendee tracking
- **Bulk SMS Messaging**: Send personalized messages to all attendees
- **Reports & Analytics**: View attendance statistics and trends
- **Data Management**: Import/export attendee data with cloud backup

### Security & Privacy
- **Firebase Authentication**: Secure user login with admin approval workflow
- **PIN-based Security**: Local PIN authentication with auto-lock
- **End-to-End Encryption**: Sensitive data encrypted before cloud storage
- **Firestore Security Rules**: Comprehensive database access control
- **Secure SMS Handling**: Encrypted message logs and delivery tracking
- **Data Backup & Recovery**: Encrypted cloud backups with migration tools

### User Experience
- **Material 3 Design**: Consistent theming with cloud sync indicators
- **Full Accessibility**: Screen reader support and high contrast modes
- **Responsive Design**: Optimized for different screen sizes
- **Offline Functionality**: Complete offline operation with sync queue
- **Real-Time Updates**: Live notifications and data synchronization
- **Comprehensive Error Handling**: Graceful error recovery and user feedback

## Quick Start

### Option 1: Install Pre-built APK (Easiest)
1. Download the APK from releases
2. Enable "Install from Unknown Sources" on your Android device
3. Install the APK file
4. Create a user account and wait for admin approval
5. Grant required permissions when prompted

### Option 2: Build from Source

#### Prerequisites
- Flutter SDK (>=3.10.0) - [Install Flutter](https://docs.flutter.dev/get-started/install)
- Android Studio with Android SDK
- Firebase project with Firestore, Auth, Analytics, and Crashlytics enabled
- Android device or emulator

#### Firebase Setup (Required)
1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use existing one
   - Enable Authentication, Firestore, Analytics, and Crashlytics

2. **Configure Android App**
   - Add Android app to Firebase project
   - Download `google-services.json`
   - Place it in `android/app/` directory

3. **Enable Authentication**
   - Go to Authentication > Sign-in method
   - Enable Email/Password authentication
   - Configure authorized domains if needed

4. **Setup Firestore Database**
   - Create Firestore database in production mode
   - Deploy security rules (see deployment section)

#### Setup Steps
1. **Install Flutter SDK**
   ```bash
   # Download from https://docs.flutter.dev/get-started/install
   # Add flutter/bin to your PATH
   ```

2. **Verify Installation**
   ```bash
   flutter doctor
   ```

3. **Clone and Setup Project**
   ```bash
   git clone <repository-url>
   cd tuk-cu-mass-messaging-app
   flutter pub get
   ```

4. **Configure Firebase**
   ```bash
   # Place google-services.json in android/app/
   # Update firebase project ID in firebase.json if needed
   ```

5. **Deploy Firestore Security Rules**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Deploy security rules
   firebase deploy --only firestore:rules
   ```

6. **Run the App**
   ```bash
   # On emulator or connected device
   flutter run
   
   # Or build APK for installation
   flutter build apk --release
   ```

## Detailed Setup Guide

For complete setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)

## App Usage

### First Time Setup
1. **Launch the app** - Initial sync will occur automatically
2. **Create Account** - Register with email and password
3. **Wait for Approval** - Admin must approve your account
4. **Set up PIN** - Configure 4-digit PIN for local security
5. **Grant Permissions** - Allow SMS, storage, and network access
6. **Initial Sync** - App will sync existing data from cloud

### User Management (Admin Only)
1. **Approve Users** - Go to User Management to approve new registrations
2. **Manage Roles** - Assign admin, leader, or member roles
3. **Revoke Access** - Disable user accounts when needed
4. **View Analytics** - Monitor system usage and performance

### Multi-User Collaboration
- **Real-Time Updates** - See changes from other users instantly
- **Conflict Resolution** - Automatic handling of simultaneous edits
- **Offline Support** - Work offline, sync when connection restored
- **Sync Status** - Monitor sync progress and connection status

### Registering Attendees
1. Tap "Start Service" if no active session
2. Use the search bar to find returning attendees (encrypted search)
3. For new attendees, fill in the registration form
4. Data is automatically encrypted and synced to cloud
5. Other users see new attendees in real-time

### Sending Messages
1. Navigate to the Messaging tab
2. Compose your message (supports personalization)
3. Preview and send to all registered attendees
4. Monitor sending progress and delivery status
5. Message logs are encrypted and synced across devices

### Viewing Reports & Analytics
1. **Reports Tab** - View attendance statistics and trends
2. **Analytics Dashboard** (Admin) - System monitoring and user activity
3. **Export Data** - Download encrypted backups
4. **Error Logs** - View system errors and performance metrics

### Data Migration
1. **Export Legacy Data** - Use migration tools to export SQLite data
2. **Import to Cloud** - Batch upload to Firestore with validation
3. **Verify Migration** - Check data integrity after import
4. **Backup Management** - Create and restore encrypted backups

## Permissions Required

The app requires these Android permissions:
- **Internet Access**: Cloud synchronization and Firebase services
- **SMS Permissions**: Send bulk messages to attendees
- **Phone State**: Access telephony features for SMS delivery
- **Storage**: Export data, backup functionality, and offline cache
- **Network State**: Monitor connectivity for sync operations
- **Wake Lock**: Maintain sync operations in background

## Technical Details

### Architecture
- **Cloud-First Design**: Firebase backend with offline-first client
- **State Management**: Provider pattern with multiple providers
- **Database**: Hybrid approach - Firestore (cloud) + SQLite (local cache)
- **Security**: End-to-end encryption with Firebase Auth
- **Real-Time Sync**: Firestore listeners with conflict resolution
- **SMS**: Native Android telephony integration
- **UI**: Material 3 design with sync status indicators

### Project Structure
```
lib/
├── main.dart                 # App entry point with Firebase initialization
├── models/                   # Data models with Firestore serialization
├── screens/                  # UI screens including auth and sync screens
├── services/                 # Business logic services
│   ├── auth_service.dart     # Firebase Authentication
│   ├── cloud_sync_service.dart # Cloud synchronization
│   ├── analytics_service.dart # Firebase Analytics & Crashlytics
│   ├── encryption_service.dart # End-to-end encryption
│   └── connectivity_service.dart # Network monitoring
├── repositories/             # Data access layer
│   ├── firebase_*_repository.dart # Cloud repositories
│   ├── hybrid_*_repository.dart   # Offline/online hybrid
│   └── local_*_repository.dart    # Local SQLite repositories
├── providers/                # State management
├── widgets/                  # Reusable UI components
├── theme/                    # App theming and styling
└── utils/                    # Utility functions
```

### Key Dependencies
#### Firebase & Cloud
- `firebase_core`: Firebase SDK initialization
- `firebase_auth`: User authentication
- `cloud_firestore`: Cloud database
- `firebase_analytics`: Usage analytics
- `firebase_crashlytics`: Error tracking
- `firebase_storage`: File storage

#### Local Storage & Sync
- `sqflite`: Local SQLite database
- `shared_preferences`: App preferences and sync state
- `connectivity_plus`: Network connectivity monitoring

#### Security & Encryption
- `flutter_secure_storage`: Encrypted local storage
- `crypto`: Data encryption and hashing
- `local_auth`: Biometric authentication

#### Communication & Data
- `telephony`: SMS functionality
- `csv`: Data export/import
- `share_plus`: File sharing

#### UI & State Management
- `provider`: State management
- `flutter/material`: Material 3 UI components

## Troubleshooting

### Common Issues

#### Firebase & Authentication
1. **Login fails**: Check Firebase Auth configuration and internet connection
2. **Account pending approval**: Contact admin to approve your account
3. **Sync not working**: Verify Firestore security rules are deployed
4. **Google services error**: Ensure `google-services.json` is in `android/app/`

#### App & Development
1. **Flutter not found**: Ensure Flutter is in your system PATH
2. **Build errors**: Run `flutter clean && flutter pub get`
3. **SMS not working**: Check permissions and device compatibility
4. **App crashes**: Check logs with `flutter logs` and Firebase Crashlytics

#### Cloud Sync Issues
1. **Data not syncing**: Check internet connection and sync status indicator
2. **Offline mode stuck**: Force refresh connectivity or restart app
3. **Sync conflicts**: App handles automatically with last-write-wins strategy
4. **Missing data**: Check if initial sync completed successfully

#### Performance Issues
1. **Slow startup**: Initial sync may take time on first login
2. **High data usage**: Sync only occurs when needed, check sync settings
3. **Battery drain**: Background sync is optimized, check device settings

### Getting Help
- Check the [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions
- Review Firebase documentation: https://firebase.google.com/docs
- Check Flutter documentation: https://docs.flutter.dev/
- Monitor Firebase Console for errors and analytics
- Check Android permissions in device settings
- View error logs in Analytics Dashboard (admin only)

## Development

### Environment Setup
1. **Firebase Project**: Create and configure Firebase project
2. **Development Config**: Use separate Firebase project for development
3. **Security Rules**: Test rules with Firebase Emulator Suite
4. **Analytics**: Monitor development metrics separately

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test files
flutter test test/services/auth_service_test.dart
flutter test test/services/encryption_service_test.dart

# Run with coverage
flutter test --coverage
```

### Firebase Emulator (Development)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Start emulators
firebase emulators:start --only auth,firestore,storage

# Run app against emulators
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

### Building for Release
```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Build with Firebase production config
flutter build apk --release --dart-define=FIREBASE_ENV=production
```

### Code Analysis & Quality
```bash
# Analyze code
flutter analyze

# Format code
flutter format .

# Check for unused dependencies
flutter pub deps
```

### Deployment
```bash
# Deploy Firestore security rules
firebase deploy --only firestore:rules

# Deploy all Firebase resources
firebase deploy

# Deploy to specific project
firebase use production
firebase deploy
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support or questions about the app:
- Create an issue in the repository
- Check the troubleshooting section above
- Review the setup guide for common solutions