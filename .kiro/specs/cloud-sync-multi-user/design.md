# Design Document: Cloud Sync & Multi-User Authentication

## Overview

This design document outlines the technical implementation for adding cloud-based database synchronization and multi-user authentication to the TUK University CU Mass Messaging App. The solution uses Firebase as the backend platform, providing real-time data sync, user authentication, and offline support.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Auth Screen  │  │ Registration │  │  Messaging   │     │
│  │  (Login/     │  │   Screen     │  │   Screen     │     │
│  │  Register)   │  │              │  │              │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                  │              │
├─────────┼─────────────────┼──────────────────┼──────────────┤
│         │                 │                  │              │
│  ┌──────▼─────────────────▼──────────────────▼───────────┐ │
│  │           Service Layer (Business Logic)              │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │ Auth Service │  │ Sync Service │  │ SMS Manager │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │ │
│  └───────────────────────────────────────────────────────┘ │
│         │                 │                  │              │
├─────────┼─────────────────┼──────────────────┼──────────────┤
│         │                 │                  │              │
│  ┌──────▼─────────────────▼──────────────────▼───────────┐ │
│  │         Repository Layer (Data Access)                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │   Firebase   │  │    Local     │  │   Hybrid    │ │ │
│  │  │  Repository  │  │  Repository  │  │  Repository │ │ │
│  │  │  (Cloud)     │  │  (SQLite)    │  │  (Both)     │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Firebase Backend                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Firebase     │  │  Cloud       │  │  Firebase    │     │
│  │ Auth         │  │  Firestore   │  │  Storage     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Frontend:**
- Flutter SDK
- Provider (State Management)
- firebase_core
- firebase_auth
- cloud_firestore
- firebase_storage

**Backend:**
- Firebase Authentication
- Cloud Firestore (NoSQL Database)
- Firebase Storage (File Storage)
- Firebase Cloud Functions (Optional - for advanced features)

**Local Storage:**
- SQLite (Offline cache)
- Shared Preferences (User session)

## Components and Interfaces

### 1. Authentication Service

**Purpose:** Manages user authentication and session management

**Interface:**
```dart
class AuthService {
  // Sign up new user
  Future<UserCredential> signUp(String email, String password, String name);
  
  // Sign in existing user
  Future<UserCredential> signIn(String email, String password);
  
  // Sign out current user
  Future<void> signOut();
  
  // Get current user
  User? getCurrentUser();
  
  // Check if user is authenticated
  bool isAuthenticated();
  
  // Reset password
  Future<void> resetPassword(String email);
  
  // Update user profile
  Future<void> updateProfile(String name, String? photoUrl);
  
  // Listen to auth state changes
  Stream<User?> authStateChanges();
}
```

### 2. Cloud Sync Service

**Purpose:** Synchronizes data between local database and cloud

**Interface:**
```dart
class CloudSyncService {
  // Sync all data to cloud
  Future<SyncResult> syncToCloud();
  
  // Sync all data from cloud
  Future<SyncResult> syncFromCloud();
  
  // Enable real-time sync
  void enableRealTimeSync();
  
  // Disable real-time sync
  void disableRealTimeSync();
  
  // Check sync status
  SyncStatus getSyncStatus();
  
  // Resolve sync conflicts
  Future<void> resolveConflicts(List<SyncConflict> conflicts);
  
  // Listen to sync events
  Stream<SyncEvent> syncEvents();
}
```

### 3. Firebase Attendee Repository

**Purpose:** Manages attendee data in Cloud Firestore

**Interface:**
```dart
class FirebaseAttendeeRepository {
  // Create attendee in cloud
  Future<String> createAttendee(AttendeeModel attendee);
  
  // Get attendee by ID
  Future<AttendeeModel?> getAttendeeById(String id);
  
  // Get all attendees
  Future<List<AttendeeModel>> getAllAttendees();
  
  // Update attendee
  Future<void> updateAttendee(AttendeeModel attendee);
  
  // Delete attendee
  Future<void> deleteAttendee(String id);
  
  // Search attendees
  Future<List<AttendeeModel>> searchAttendees(String query);
  
  // Get attendees with filters
  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  });
  
  // Listen to attendee changes (real-time)
  Stream<List<AttendeeModel>> attendeesStream();
}
```

### 4. Firebase Message Log Repository

**Purpose:** Manages message logs in Cloud Firestore

**Interface:**
```dart
class FirebaseMessageLogRepository {
  // Create message log
  Future<String> createMessageLog(MessageLogModel messageLog);
  
  // Get message logs by service
  Future<List<MessageLogModel>> getMessageLogsByService(int serviceId);
  
  // Get all message logs
  Future<List<MessageLogModel>> getAllMessageLogs();
  
  // Update message status
  Future<void> updateMessageStatus(String id, MessageStatus status);
  
  // Get message statistics
  Future<MessageStatistics> getMessageStatistics();
  
  // Listen to message log changes (real-time)
  Stream<List<MessageLogModel>> messageLogsStream();
}
```

### 5. Hybrid Repository Pattern

**Purpose:** Provides seamless offline/online data access

**Strategy:**
- **Online:** Read/write directly to Cloud Firestore
- **Offline:** Read/write to local SQLite, queue changes
- **Sync:** Automatically sync when connection restored

**Interface:**
```dart
class HybridAttendeeRepository {
  final FirebaseAttendeeRepository _cloudRepo;
  final AttendeeRepository _localRepo;
  final CloudSyncService _syncService;
  
  // Automatically routes to cloud or local based on connectivity
  Future<String> createAttendee(AttendeeModel attendee);
  Future<AttendeeModel?> getAttendeeById(String id);
  Future<List<AttendeeModel>> getAllAttendees();
  Future<void> updateAttendee(AttendeeModel attendee);
  Future<void> deleteAttendee(String id);
}
```

## Data Models

### User Model

```dart
class UserModel {
  final String uid;              // Firebase UID
  final String email;
  final String name;
  final String? photoUrl;
  final UserRole role;           // admin, leader, member
  final bool isApproved;         // Admin approval status
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  
  // Firestore document structure
  Map<String, dynamic> toFirestore();
  factory UserModel.fromFirestore(DocumentSnapshot doc);
}

enum UserRole {
  admin,    // Full access, can approve users
  leader,   // Can register and message
  member,   // Read-only access
}
```

### Enhanced Attendee Model

```dart
class AttendeeModel {
  final String id;               // Firestore document ID
  final String name;
  final String phoneNumber;
  final String location;
  final String? yearOfStudy;
  final AttendeeCategory category;
  final int serviceId;
  final DateTime registeredAt;
  
  // Cloud sync fields
  final String createdBy;        // User UID who created
  final DateTime createdAt;      // Cloud timestamp
  final String? modifiedBy;      // User UID who last modified
  final DateTime? modifiedAt;    // Last modification timestamp
  final bool isSynced;           // Sync status
  final int version;             // For conflict resolution
  
  Map<String, dynamic> toFirestore();
  factory AttendeeModel.fromFirestore(DocumentSnapshot doc);
}
```

### Enhanced Message Log Model

```dart
class MessageLogModel {
  final String id;               // Firestore document ID
  final String attendeeId;
  final String message;
  final MessageStatus status;
  final DateTime sentAt;
  final int serviceId;
  
  // Cloud sync fields
  final String sentBy;           // User UID who sent
  final DateTime createdAt;      // Cloud timestamp
  final bool isSynced;
  final int version;
  
  Map<String, dynamic> toFirestore();
  factory MessageLogModel.fromFirestore(DocumentSnapshot doc);
}
```

### Sync Models

```dart
class SyncResult {
  final bool success;
  final int itemsSynced;
  final List<SyncError> errors;
  final DateTime syncedAt;
}

class SyncStatus {
  final bool isSyncing;
  final bool isOnline;
  final DateTime? lastSyncAt;
  final int pendingChanges;
}

class SyncConflict {
  final String id;
  final dynamic localData;
  final dynamic cloudData;
  final ConflictType type;
}

enum ConflictType {
  localNewer,
  cloudNewer,
  bothModified,
}
```

## Firestore Database Structure

```
/users/{userId}
  - email: string
  - name: string
  - photoUrl: string?
  - role: string
  - isApproved: boolean
  - createdAt: timestamp
  - lastLoginAt: timestamp?

/attendees/{attendeeId}
  - name: string (encrypted)
  - phoneNumber: string (encrypted)
  - location: string
  - yearOfStudy: string?
  - category: string
  - serviceId: number
  - registeredAt: timestamp
  - createdBy: string (userId)
  - createdAt: timestamp
  - modifiedBy: string?
  - modifiedAt: timestamp?
  - version: number

/messageLogs/{messageLogId}
  - attendeeId: string
  - message: string
  - status: string
  - sentAt: timestamp
  - serviceId: number
  - sentBy: string (userId)
  - createdAt: timestamp
  - version: number

/services/{serviceId}
  - date: timestamp
  - attendeeCount: number
  - messagesSent: boolean
  - createdBy: string (userId)
  - createdAt: timestamp

/syncQueue/{queueId}
  - userId: string
  - operation: string (create/update/delete)
  - collection: string
  - documentId: string
  - data: map
  - createdAt: timestamp
  - status: string (pending/completed/failed)
```

## Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isApproved() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isApproved == true;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (request.auth.uid == userId || isAdmin());
      allow delete: if isAdmin();
    }
    
    // Attendees collection
    match /attendees/{attendeeId} {
      allow read: if isApproved();
      allow create: if isApproved();
      allow update: if isApproved();
      allow delete: if isApproved();
    }
    
    // Message logs collection
    match /messageLogs/{messageLogId} {
      allow read: if isApproved();
      allow create: if isApproved();
      allow update: if isApproved();
      allow delete: if isAdmin();
    }
    
    // Services collection
    match /services/{serviceId} {
      allow read: if isApproved();
      allow create: if isApproved();
      allow update: if isApproved();
      allow delete: if isAdmin();
    }
    
    // Sync queue collection
    match /syncQueue/{queueId} {
      allow read, write: if isAuthenticated() && request.auth.uid == resource.data.userId;
    }
  }
}
```

## Error Handling

### Authentication Errors

```dart
class AuthException implements Exception {
  final String code;
  final String message;
  
  static String getUserFriendlyMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'account-not-approved':
        return 'Your account is pending admin approval';
      default:
        return 'Authentication error: $code';
    }
  }
}
```

### Sync Errors

```dart
class SyncException implements Exception {
  final String code;
  final String message;
  final List<SyncError> errors;
  
  static String getUserFriendlyMessage(String code) {
    switch (code) {
      case 'no-internet':
        return 'No internet connection. Changes will sync when online.';
      case 'permission-denied':
        return 'You don\'t have permission to sync this data';
      case 'conflict':
        return 'Data conflict detected. Please resolve conflicts.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please contact admin.';
      default:
        return 'Sync error: $code';
    }
  }
}
```

## Testing Strategy

### Unit Tests

1. **Authentication Service Tests**
   - Test sign up with valid/invalid credentials
   - Test sign in with correct/incorrect password
   - Test sign out functionality
   - Test password reset
   - Test auth state changes

2. **Cloud Sync Service Tests**
   - Test sync to cloud with valid data
   - Test sync from cloud
   - Test conflict resolution strategies
   - Test offline queue management
   - Test real-time sync listeners

3. **Repository Tests**
   - Test CRUD operations on Firebase
   - Test offline fallback to SQLite
   - Test data encryption/decryption
   - Test query filters
   - Test real-time updates

### Integration Tests

1. **Multi-Device Sync Test**
   - Register attendee on Device A
   - Verify it appears on Device B
   - Update on Device B
   - Verify update on Device A

2. **Offline Mode Test**
   - Disconnect internet
   - Register attendees offline
   - Reconnect internet
   - Verify data syncs to cloud

3. **Conflict Resolution Test**
   - Modify same attendee on two devices offline
   - Reconnect both devices
   - Verify conflict resolution

### Property-Based Tests

Property 1: Authentication round-trip
*For any* valid email and password, signing up then signing in should succeed and return the same user
**Validates: Requirements 1.2, 1.3**

Property 2: Data sync consistency
*For any* attendee created on one device, it should appear on all other authenticated devices within sync interval
**Validates: Requirements 2.1, 2.5**

Property 3: Offline-online round-trip
*For any* data modification made offline, syncing when online should result in the same data in cloud
**Validates: Requirements 4.2, 4.3**

Property 4: Encryption round-trip
*For any* sensitive data, encrypting then decrypting should return the original value
**Validates: Requirements 6.1, 6.2**

Property 5: Conflict resolution determinism
*For any* sync conflict, applying the same resolution strategy should always produce the same result
**Validates: Requirements 4.4**

## Implementation Phases

### Phase 1: Firebase Setup & Authentication (Priority: High)
- Set up Firebase project
- Add Firebase dependencies
- Implement AuthService
- Create login/registration screens
- Implement user session management
- Add user approval workflow

### Phase 2: Cloud Database Migration (Priority: High)
- Create Firestore data models
- Implement Firebase repositories
- Set up security rules
- Migrate existing SQLite data to Firestore
- Implement hybrid repository pattern

### Phase 3: Real-Time Sync (Priority: Medium)
- Implement CloudSyncService
- Add real-time listeners
- Implement sync status indicators
- Add sync conflict resolution
- Test multi-device sync

### Phase 4: Offline Support (Priority: Medium)
- Implement offline queue
- Add connectivity monitoring
- Implement auto-sync on reconnect
- Add offline indicators
- Test offline functionality

### Phase 5: Advanced Features (Priority: Low)
- User management dashboard
- Data export/import
- Analytics integration
- Error tracking
- Performance monitoring

## Migration Strategy

### Existing Data Migration

1. **Export existing SQLite data**
   - Create export script
   - Generate JSON backup

2. **Transform data for Firestore**
   - Add cloud-specific fields (createdBy, version, etc.)
   - Generate Firestore document IDs

3. **Import to Firestore**
   - Batch upload to Firestore
   - Verify data integrity

4. **Gradual rollout**
   - Keep SQLite as fallback
   - Test with small user group
   - Full migration after validation

### User Onboarding

1. **First-time users**
   - Show registration screen
   - Explain approval process
   - Guide through first login

2. **Existing users**
   - Prompt to create account
   - Link existing data to account
   - Migrate local data to cloud

## Performance Considerations

1. **Pagination**
   - Load attendees in batches (50-100 at a time)
   - Implement infinite scroll

2. **Caching**
   - Cache frequently accessed data locally
   - Use Firestore offline persistence

3. **Indexing**
   - Create Firestore indexes for common queries
   - Index on: serviceId, createdBy, createdAt

4. **Bandwidth Optimization**
   - Only sync changed fields
   - Compress large data before upload
   - Use delta sync for updates

## Cost Estimation (Firebase Free Tier)

**Free Tier Limits:**
- 1 GB storage
- 50,000 reads/day
- 20,000 writes/day
- 20,000 deletes/day
- 10 GB/month bandwidth

**Estimated Usage (100 active users):**
- Storage: ~100 MB (well within limit)
- Reads: ~5,000/day (10% of limit)
- Writes: ~1,000/day (5% of limit)

**Conclusion:** Free tier is sufficient for TUK CU use case
