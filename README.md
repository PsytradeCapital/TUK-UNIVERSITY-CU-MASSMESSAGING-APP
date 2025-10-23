# TUK CU Mass Messaging App
## "Raising to Serve"

A comprehensive mass messaging and attendance management application for the Technical University of Kenya Christian Union (TUK CU). Designed to streamline attendee registration and enable efficient bulk SMS communication during services and events.

## Features

### Core Functionality
- **Attendee Registration**: Quick registration with name, phone, year, and location
- **Smart Search**: Find returning attendees instantly
- **Service Management**: Start/end service sessions with attendee tracking
- **Bulk SMS Messaging**: Send personalized messages to all attendees
- **Reports & Analytics**: View attendance statistics and trends
- **Data Management**: Import/export attendee data as CSV

### Security & Privacy
- PIN-based authentication with auto-lock
- Encrypted local data storage
- Secure SMS permissions handling
- Data backup and recovery

### User Experience
- Material 3 design with consistent theming
- Full accessibility support (screen readers, high contrast)
- Responsive design for different screen sizes
- Offline functionality with sync when online
- Comprehensive error handling and recovery

## Quick Start

### Option 1: Install Pre-built APK (Easiest)
1. Download the APK from releases
2. Enable "Install from Unknown Sources" on your Android device
3. Install the APK file
4. Grant required permissions when prompted

### Option 2: Build from Source

#### Prerequisites
- Flutter SDK (>=3.10.0) - [Install Flutter](https://docs.flutter.dev/get-started/install)
- Android Studio with Android SDK
- Android device or emulator

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

3. **Get Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
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
1. Launch the app
2. Set up a 4-digit PIN for security
3. Grant SMS and storage permissions
4. Start your first service session

### Registering Attendees
1. Tap "Start Service" if no active session
2. Use the search bar to find returning attendees
3. For new attendees, fill in the registration form
4. Attendees are automatically added to the current service

### Sending Messages
1. Navigate to the Messaging tab
2. Compose your message (supports personalization)
3. Preview and send to all registered attendees
4. Monitor sending progress and delivery status

### Viewing Reports
1. Go to Reports tab
2. View attendance statistics and trends
3. Export data as CSV for external analysis
4. Generate service summaries

## Permissions Required

The app requires these Android permissions:
- **SMS Permissions**: Send bulk messages to attendees
- **Phone State**: Access telephony features
- **Storage**: Export data and backup functionality
- **Network**: Online features and updates

## Technical Details

### Architecture
- **State Management**: Provider pattern with multiple providers
- **Database**: SQLite with sqflite for local storage
- **Security**: Encrypted storage with flutter_secure_storage
- **SMS**: Native Android telephony integration
- **UI**: Material 3 design with custom theming

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (Attendee, Service, etc.)
├── screens/                  # UI screens
├── services/                 # Business logic services
├── repositories/             # Data access layer
├── providers/                # State management
├── widgets/                  # Reusable UI components
├── theme/                    # App theming and styling
└── utils/                    # Utility functions
```

### Key Dependencies
- `sqflite`: Local SQLite database
- `telephony`: SMS functionality
- `provider`: State management
- `flutter_secure_storage`: Encrypted storage
- `crypto`: Data encryption
- `csv`: Data export
- `share_plus`: File sharing

## Troubleshooting

### Common Issues
1. **Flutter not found**: Ensure Flutter is in your system PATH
2. **Build errors**: Run `flutter clean && flutter pub get`
3. **SMS not working**: Check permissions and device compatibility
4. **App crashes**: Check logs with `flutter logs`

### Getting Help
- Check the [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions
- Review Flutter documentation: https://docs.flutter.dev/
- Check Android permissions in device settings

## Development

### Running Tests
```bash
flutter test
```

### Building for Release
```bash
flutter build apk --release
```

### Code Analysis
```bash
flutter analyze
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