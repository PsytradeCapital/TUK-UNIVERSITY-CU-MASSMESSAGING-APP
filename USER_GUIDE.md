# TUK CU Mass Messaging App - User Guide
## "Raising to Serve"

Welcome to the TUK CU Mass Messaging App! This comprehensive guide will help you get started with the cloud-enabled features and make the most of the multi-user collaboration capabilities.

## Table of Contents
1. [Getting Started](#getting-started)
2. [User Registration and Login](#user-registration-and-login)
3. [Understanding User Roles](#understanding-user-roles)
4. [Multi-User Collaboration](#multi-user-collaboration)
5. [Attendee Management](#attendee-management)
6. [Service Management](#service-management)
7. [Messaging System](#messaging-system)
8. [Reports and Analytics](#reports-and-analytics)
9. [Data Management](#data-management)
10. [Offline Mode](#offline-mode)
11. [Security Features](#security-features)
12. [Troubleshooting](#troubleshooting)

---

## Getting Started

### First Launch
When you first open the app, you'll see the initial sync screen. This process:
- Downloads existing data from the cloud
- Sets up your local database
- Configures encryption keys
- Prepares the app for offline use

**Note**: Initial sync may take a few minutes depending on your internet connection and the amount of existing data.

### System Requirements
- Android 6.0 (API level 23) or higher
- Internet connection for cloud features
- SMS permissions for messaging functionality
- At least 100MB free storage space

---

## User Registration and Login

### Creating Your Account

1. **Open the App**: Launch the TUK CU Mass Messaging App
2. **Registration Screen**: Tap "Don't have an account? Register"
3. **Fill Details**:
   - **Full Name**: Your complete name as it should appear to other users
   - **Email Address**: Valid email for account recovery and notifications
   - **Password**: Strong password (minimum 6 characters, include uppercase, lowercase, numbers, and special characters)
   - **Confirm Password**: Re-enter your password
4. **Submit Registration**: Tap "Register"
5. **Pending Approval**: You'll see a "Pending Approval" screen

### Account Approval Process

After registration, your account needs approval from an administrator:
- **Automatic Notification**: Admins are notified of new registrations
- **Approval Time**: Usually within 24 hours during business days
- **Status Check**: You can check your approval status by trying to log in
- **Contact Admin**: If delayed, contact your CU leadership

### Logging In

1. **Email and Password**: Enter your registered credentials
2. **Remember Me**: Optional - keeps you logged in (secure on personal devices only)
3. **Forgot Password**: Use this if you can't remember your password
4. **PIN Setup**: After first successful login, you'll set up a 4-digit PIN

---

## Understanding User Roles

The app has three user roles with different permissions:

### 👑 Admin
**Full system access including:**
- Approve/reject new user registrations
- Manage user roles and permissions
- Access analytics dashboard and system monitoring
- Delete attendees and message logs
- Export/import data and manage backups
- Deploy system updates and configuration changes

### 👥 Leader
**Standard operational access:**
- Register and manage attendees
- Start/end service sessions
- Send messages to attendees
- View reports and attendance statistics
- Export attendee data
- Manage their own profile

### 👤 Member
**Read-only access:**
- View attendee lists (names only, no phone numbers)
- View service statistics
- View message history (content only, no phone numbers)
- Cannot register attendees or send messages

---

## Multi-User Collaboration

### Real-Time Synchronization

The app supports multiple users working simultaneously:

#### **Live Updates**
- See new attendees registered by other users instantly
- View message sending progress from all users
- Real-time service session updates
- Automatic conflict resolution for simultaneous edits

#### **Sync Status Indicators**
- **Green Circle**: Connected and synced
- **Yellow Circle**: Syncing in progress
- **Red Circle**: Offline or sync error
- **Gray Circle**: No internet connection

#### **Collaboration Best Practices**
1. **Coordinate Service Sessions**: Only one person should start/end services
2. **Communicate Changes**: Let team know about major data updates
3. **Check Sync Status**: Ensure you're synced before important operations
4. **Resolve Conflicts**: App handles conflicts automatically, but communicate with team

### Working with Multiple Devices

#### **Device Registration**
- Each device needs its own user account
- Same user can log in on multiple devices
- Data syncs across all logged-in devices

#### **Switching Devices**
1. Log out from old device (optional but recommended)
2. Log in on new device
3. Wait for initial sync to complete
4. Set up PIN on new device

---

## Attendee Management

### Registering New Attendees

#### **Quick Registration**
1. **Start Service**: Ensure a service session is active
2. **Search First**: Always search for existing attendees to avoid duplicates
3. **New Registration**: If not found, tap "Register New Attendee"
4. **Fill Form**:
   - **Full Name**: Complete name (required)
   - **Phone Number**: Include country code (+254 for Kenya)
   - **Location**: City or area (required)
   - **Year of Study**: Academic year (optional)
   - **Category**: Student, Staff, Visitor, etc.
5. **Save**: Tap "Register Attendee"

#### **Data Encryption**
- Names, phone numbers, and locations are automatically encrypted
- Only authorized users can view sensitive information
- Search works on encrypted data for privacy

### Finding Existing Attendees

#### **Smart Search**
- **Name Search**: Type any part of the name
- **Phone Search**: Enter phone number (with or without country code)
- **Location Filter**: Filter by city or area
- **Recent Attendees**: Quick access to recently registered attendees

#### **Search Tips**
- Use partial names for faster results
- Phone search works with encrypted data
- Search is case-insensitive
- Use location filters to narrow results

### Managing Attendee Data

#### **Editing Attendees**
1. Find the attendee using search
2. Tap on their name to open details
3. Tap "Edit" (Leaders and Admins only)
4. Make changes and save
5. Changes sync automatically to all devices

#### **Viewing Attendee History**
- See which services they attended
- View message history for this attendee
- Check registration date and last update
- See who registered or last modified the attendee

---

## Service Management

### Starting a Service Session

#### **New Service**
1. **Navigate**: Go to Home screen
2. **Start Service**: Tap "Start New Service"
3. **Service Details**:
   - **Date**: Automatically set to today (can be changed)
   - **Service Type**: Regular, Special Event, Conference, etc.
   - **Location**: Where the service is held
   - **Notes**: Optional description
4. **Begin**: Tap "Start Service"

#### **Active Service Indicators**
- Green banner showing "Service Active"
- Attendee counter updates in real-time
- All team members see the same active service

### Managing Active Services

#### **During Service**
- **Register Attendees**: Add new attendees to current service
- **View Count**: See real-time attendee count
- **Send Messages**: Communicate with all attendees
- **Monitor Team**: See who else is registering attendees

#### **Service Statistics**
- Total attendees registered
- New vs returning attendees
- Registration timeline
- Messages sent during service

### Ending a Service Session

1. **Complete Registration**: Ensure all attendees are registered
2. **Final Count**: Verify attendee numbers
3. **End Service**: Tap "End Service"
4. **Service Summary**: Review final statistics
5. **Generate Report**: Optional - create service report

---

## Messaging System

### Composing Messages

#### **Message Types**
- **Welcome Messages**: For new attendees
- **Announcements**: General information
- **Reminders**: Follow-up messages
- **Custom Messages**: Personalized content

#### **Creating Messages**
1. **Navigate**: Go to Messaging tab
2. **New Message**: Tap "Compose Message"
3. **Select Recipients**:
   - All attendees from current service
   - All attendees from specific date range
   - Custom selection
4. **Message Content**:
   - **Subject**: Brief description (for your reference)
   - **Message**: SMS content (160 characters recommended)
   - **Personalization**: Use {name} for attendee names
5. **Preview**: Review message with sample data

#### **Message Personalization**
- `{name}`: Attendee's full name
- `{location}`: Attendee's location
- `{service_date}`: Date of service attendance

**Example**: "Hello {name}, thank you for joining us at TUK CU service. Blessings from {location}!"

### Sending Messages

#### **Pre-Send Checklist**
1. **Review Recipients**: Confirm correct attendee list
2. **Check Message**: Verify content and personalization
3. **Test Message**: Send to yourself first (recommended)
4. **Confirm Send**: Final confirmation before bulk send

#### **Sending Process**
1. **Initiate Send**: Tap "Send Messages"
2. **Progress Monitor**: Watch sending progress
3. **Delivery Status**: See delivery confirmations
4. **Error Handling**: Failed messages are retried automatically

#### **Message Status Indicators**
- **Queued**: Message prepared for sending
- **Sending**: Currently being sent
- **Delivered**: Successfully delivered
- **Failed**: Delivery failed (will retry)
- **Blocked**: Number blocked or invalid

### Message History

#### **Viewing History**
- **All Messages**: Complete message log
- **Filter by Date**: Messages from specific time periods
- **Filter by Service**: Messages sent during specific services
- **Search Messages**: Find messages by content or recipient

#### **Message Details**
- Who sent the message
- When it was sent
- Delivery status for each recipient
- Message content (encrypted)
- Service association

---

## Reports and Analytics

### Attendance Reports

#### **Service Reports**
- **Individual Service**: Detailed report for specific service
- **Date Range**: Attendance trends over time
- **Comparison**: Compare different services or periods
- **Growth Metrics**: New vs returning attendees

#### **Attendee Analytics**
- **Total Registrations**: All-time attendee count
- **Active Attendees**: Recent service participation
- **Location Distribution**: Where attendees come from
- **Category Breakdown**: Students, staff, visitors, etc.

### Message Analytics

#### **Messaging Statistics**
- **Total Messages Sent**: All-time message count
- **Delivery Rates**: Success/failure percentages
- **Response Metrics**: Engagement tracking
- **Popular Message Types**: Most used templates

#### **Performance Metrics**
- **Sending Speed**: Messages per minute
- **Error Rates**: Failed delivery analysis
- **Peak Usage**: Busiest messaging times
- **Cost Analysis**: SMS usage and costs

### Admin Analytics Dashboard

*Available to Admins only*

#### **System Monitoring**
- **User Activity**: Login patterns and usage
- **Sync Performance**: Data synchronization metrics
- **Error Tracking**: System errors and crashes
- **Performance Metrics**: App speed and responsiveness

#### **Usage Analytics**
- **Feature Usage**: Most/least used features
- **Device Analytics**: Device types and OS versions
- **Network Usage**: Data consumption patterns
- **Storage Usage**: Database size and growth

---

## Data Management

### Exporting Data

#### **CSV Export**
1. **Navigate**: Go to Reports tab
2. **Export Options**: Choose data type
   - All attendees
   - Service-specific attendees
   - Message history
   - Service reports
3. **Date Range**: Select time period
4. **Export Format**: CSV (Excel-compatible)
5. **Download**: File saved to device storage

#### **Encrypted Backup**
*Admin feature*
1. **Full Backup**: Complete database export
2. **Encryption**: Data encrypted before export
3. **Cloud Storage**: Backup saved to Firebase Storage
4. **Download**: Local copy for safekeeping

### Importing Data

#### **CSV Import**
1. **Prepare File**: Format CSV with required columns
2. **Import Tool**: Use Data Migration screen
3. **Validation**: System checks data format
4. **Preview**: Review data before import
5. **Import**: Add data to database

#### **Legacy Data Migration**
*For upgrading from older versions*
1. **Export Old Data**: From previous app version
2. **Migration Tool**: Built-in conversion utility
3. **Data Transformation**: Automatic format conversion
4. **Validation**: Integrity checks
5. **Cloud Upload**: Migrate to new cloud system

### Data Backup and Recovery

#### **Automatic Backups**
- **Daily Backups**: Automatic encrypted backups
- **Cloud Storage**: Stored in Firebase Storage
- **Retention**: 30 days of backup history
- **Verification**: Automatic integrity checks

#### **Manual Backup**
1. **Settings**: Go to Data Management
2. **Create Backup**: Tap "Create Backup"
3. **Encryption**: Data encrypted automatically
4. **Storage**: Choose local or cloud storage
5. **Verification**: Confirm backup success

#### **Data Recovery**
1. **Select Backup**: Choose backup date
2. **Preview**: Review backup contents
3. **Recovery Options**: Full or partial restore
4. **Confirmation**: Confirm data replacement
5. **Sync**: Updated data syncs to all devices

---

## Offline Mode

### Understanding Offline Functionality

#### **What Works Offline**
- View existing attendees and their information
- Register new attendees (saved locally)
- Compose messages (sent when online)
- View reports and statistics
- Search existing data
- Navigate all app screens

#### **What Requires Internet**
- Initial app setup and login
- Real-time sync with other users
- Sending SMS messages
- Downloading latest data updates
- User authentication and approval
- Analytics and error reporting

### Working Offline

#### **Offline Indicators**
- **Status Bar**: Shows "Offline Mode" when disconnected
- **Sync Icon**: Gray icon indicates no connection
- **Pending Actions**: Counter shows queued operations

#### **Offline Best Practices**
1. **Sync Before Going Offline**: Ensure latest data is downloaded
2. **Register Attendees**: Continue normal operations
3. **Compose Messages**: Prepare messages for later sending
4. **Monitor Storage**: Offline data uses device storage
5. **Reconnect Regularly**: Sync changes when possible

### Sync When Reconnected

#### **Automatic Sync**
- **Connection Detection**: App automatically detects internet
- **Queue Processing**: Pending operations sync automatically
- **Conflict Resolution**: Handles simultaneous changes
- **Progress Indicator**: Shows sync progress

#### **Manual Sync**
1. **Pull to Refresh**: Swipe down on main screens
2. **Sync Button**: Tap sync icon in status bar
3. **Force Sync**: Settings > Sync > Force Sync
4. **Verify Sync**: Check sync status indicator

---

## Security Features

### Authentication Security

#### **Account Security**
- **Strong Passwords**: Enforced password requirements
- **Account Approval**: Admin approval prevents unauthorized access
- **Session Management**: Automatic logout after inactivity
- **Multi-Device**: Secure login across multiple devices

#### **PIN Protection**
- **4-Digit PIN**: Quick access security
- **Auto-Lock**: Configurable timeout (1-30 minutes)
- **Biometric**: Fingerprint/face unlock (if supported)
- **PIN Change**: Regular PIN updates recommended

### Data Encryption

#### **End-to-End Encryption**
- **Sensitive Data**: Names, phone numbers, locations encrypted
- **Message Content**: SMS content encrypted in storage
- **Local Storage**: Device database encrypted
- **Cloud Storage**: Firestore data encrypted

#### **Encryption Details**
- **Algorithm**: AES-256 encryption
- **Key Management**: Secure key generation and storage
- **Search Capability**: Encrypted search functionality
- **Performance**: Minimal impact on app speed

### Privacy Protection

#### **Data Minimization**
- **Role-Based Access**: Users see only necessary data
- **Phone Number Masking**: Partial numbers shown to members
- **Audit Logs**: Track who accessed what data
- **Data Retention**: Automatic cleanup of old data

#### **Compliance Features**
- **Data Export**: Users can export their data
- **Data Deletion**: Admins can delete user data
- **Consent Management**: Clear privacy policies
- **Access Controls**: Granular permission system

---

## Troubleshooting

### Common Issues and Solutions

#### **Login Problems**

**Issue**: Can't log in with correct credentials
**Solutions**:
1. Check internet connection
2. Verify email and password spelling
3. Try "Forgot Password" if unsure
4. Contact admin if account not approved
5. Clear app cache and try again

**Issue**: "Account Pending Approval" message
**Solutions**:
1. Wait for admin approval (usually 24 hours)
2. Contact CU leadership to expedite
3. Verify you used correct email during registration
4. Check if you already have an approved account

#### **Sync Issues**

**Issue**: Data not syncing between devices
**Solutions**:
1. Check internet connection on both devices
2. Force refresh by pulling down on main screen
3. Log out and log back in
4. Check sync status indicator
5. Restart app if sync appears stuck

**Issue**: "Sync Failed" error message
**Solutions**:
1. Verify internet connection stability
2. Check if you have sufficient storage space
3. Try syncing during off-peak hours
4. Contact admin if error persists
5. Check Firebase service status

#### **Messaging Problems**

**Issue**: SMS messages not sending
**Solutions**:
1. Check SMS permissions in device settings
2. Verify phone has SMS capability
3. Check network signal strength
4. Try sending a test message manually
5. Restart app and try again

**Issue**: Messages marked as "Failed"
**Solutions**:
1. Check recipient phone numbers for accuracy
2. Verify numbers include correct country code
3. Check if numbers are blocked or invalid
4. Try sending to a smaller group first
5. Contact mobile network provider

#### **Performance Issues**

**Issue**: App running slowly
**Solutions**:
1. Close other apps to free memory
2. Clear app cache in device settings
3. Restart device
4. Check available storage space
5. Update app to latest version

**Issue**: High data usage
**Solutions**:
1. Use Wi-Fi when available for sync
2. Adjust sync frequency in settings
3. Avoid unnecessary data exports
4. Monitor background data usage
5. Use offline mode when possible

### Getting Additional Help

#### **In-App Support**
- **Help Section**: Built-in help and tutorials
- **Error Reporting**: Automatic error logs sent to developers
- **Feedback**: Send feedback through app settings
- **Version Info**: Check app version and build info

#### **External Support**
- **CU Leadership**: Contact your local CU leaders
- **Technical Support**: Email technical issues to support team
- **User Community**: Connect with other users for tips
- **Documentation**: Refer to README and setup guides

#### **Emergency Procedures**
- **Data Loss**: Contact admin immediately for data recovery
- **Security Breach**: Change password and notify admin
- **App Crashes**: Force close and restart, report if persistent
- **Sync Conflicts**: Let app resolve automatically, contact admin if issues persist

---

## Tips for Best Experience

### Optimization Tips
1. **Regular Sync**: Connect to Wi-Fi regularly for sync
2. **Battery Optimization**: Exclude app from battery optimization
3. **Storage Management**: Regularly export and archive old data
4. **Network Usage**: Use Wi-Fi for large operations
5. **Security Updates**: Keep app updated for security patches

### Collaboration Tips
1. **Communication**: Coordinate with team members
2. **Role Clarity**: Understand your role and permissions
3. **Data Quality**: Maintain accurate attendee information
4. **Backup Strategy**: Regular backups prevent data loss
5. **Training**: Ensure all users understand the system

### Efficiency Tips
1. **Keyboard Shortcuts**: Learn quick navigation
2. **Search Effectively**: Use filters and partial searches
3. **Batch Operations**: Group similar tasks together
4. **Template Messages**: Create reusable message templates
5. **Regular Maintenance**: Clean up old data periodically

---

## Conclusion

The TUK CU Mass Messaging App is designed to make attendee management and communication efficient and secure. With cloud synchronization and multi-user support, your entire CU team can collaborate effectively while maintaining data security and privacy.

For additional support or questions not covered in this guide, please contact your CU leadership or the technical support team.

**"Raising to Serve"** - May this tool help you serve your community more effectively!

---

*Last Updated: December 2024*
*Version: 2.0 (Cloud-Enabled)*