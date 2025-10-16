# Christian Union Attendance App

A mobile application for the Technical University of Kenya Christian Union to automate attendee registration and mass SMS messaging during services.

## Features

- Quick attendee registration with offline storage
- Smart search for returning attendees
- Bulk SMS messaging with personalization
- Attendance tracking and reporting
- Data export capabilities
- Security with PIN authentication

## Getting Started

This project is a Flutter application for Android devices.

### Prerequisites

- Flutter SDK (>=3.10.0)
- Android Studio or VS Code with Flutter extensions
- Android device or emulator for testing

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect an Android device or start an emulator
4. Run `flutter run` to launch the app

### Permissions

The app requires the following Android permissions:
- SEND_SMS: For sending bulk SMS messages
- READ_SMS: For SMS functionality
- READ_PHONE_STATE: For telephony features
- WRITE_EXTERNAL_STORAGE: For data export

## Project Structure

```
lib/
├── models/          # Data models
├── services/        # Business logic services
├── screens/         # UI screens
└── utils/           # Utility functions
```

## Dependencies

- sqflite: Local database storage
- telephony: SMS functionality
- provider: State management
- crypto: Data encryption
- path_provider: File system access
- csv: Data export functionality