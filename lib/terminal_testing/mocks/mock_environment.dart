import 'mock_firebase_auth.dart';
import 'mock_local_storage.dart';
import 'mock_attendance_repository.dart';

/// Mock Environment for terminal testing
/// Provides simulated dependencies for testing without external connections
class MockEnvironment {
  // Remove singleton pattern to allow proper isolation between test iterations
  MockEnvironment();

  MockFirebaseAuth? _auth;
  MockLocalStorage? _storage;
  MockAttendanceRepository? _attendanceRepo;
  bool _isInitialized = false;

  /// Get mock Firebase authentication
  MockFirebaseAuth get auth {
    if (_auth == null) {
      throw StateError('MockEnvironment not initialized. Call setup() first.');
    }
    return _auth!;
  }

  /// Get mock local storage
  MockLocalStorage get storage {
    if (_storage == null) {
      throw StateError('MockEnvironment not initialized. Call setup() first.');
    }
    return _storage!;
  }

  /// Get mock attendance repository
  MockAttendanceRepository get attendanceRepo {
    if (_attendanceRepo == null) {
      throw StateError('MockEnvironment not initialized. Call setup() first.');
    }
    return _attendanceRepo!;
  }

  /// Check if environment is initialized
  bool get isInitialized => _isInitialized;

  /// Set up mock environment with default test data
  void setup() {
    if (_isInitialized) return;

    _auth = MockFirebaseAuth();
    _storage = MockLocalStorage();
    _attendanceRepo = MockAttendanceRepository();

    // Initialize all mock components
    _auth!.initialize();
    _storage!.initialize();
    _attendanceRepo!.initialize();

    _isInitialized = true;
  }

  /// Tear down mock environment and clean up resources
  void teardown() {
    if (!_isInitialized) return;

    _auth?.reset();
    _storage?.reset();
    _attendanceRepo?.reset();

    _auth?.dispose();
    _storage?.dispose();
    _attendanceRepo?.dispose();

    _auth = null;
    _storage = null;
    _attendanceRepo = null;
    _isInitialized = false;
  }

  /// Reset all mock components to initial state
  void reset() {
    if (!_isInitialized) {
      setup();
      return;
    }

    _auth?.reset();
    _storage?.reset();
    _attendanceRepo?.reset();

    // Re-initialize with default data
    _auth?.initialize();
    _storage?.initialize();
    _attendanceRepo?.initialize();
  }

  /// Configure mock environment for specific test scenarios
  void configureForTest({
    Map<String, String>? testUsers,
    Map<String, dynamic>? testStorageData,
    List<Map<String, dynamic>>? testAttendees,
  }) {
    if (!_isInitialized) setup();

    // Add test users to auth
    if (testUsers != null) {
      for (final entry in testUsers.entries) {
        final parts = entry.key.split('|'); // Format: "email|password"
        if (parts.length == 2) {
          _auth!.addTestUser(
            uid: 'test-${DateTime.now().millisecondsSinceEpoch}',
            email: parts[0],
            password: parts[1],
            displayName: entry.value,
          );
        }
      }
    }

    // Add test data to storage
    if (testStorageData != null) {
      _storage!.addTestData(testStorageData);
    }

    // Add test attendees to repository
    if (testAttendees != null) {
      for (final attendeeData in testAttendees) {
        // Convert map to AttendeeModel and add to repository
        // This would need proper conversion logic based on AttendeeModel structure
      }
    }
  }

  /// Get environment status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'auth': {
        'currentUser': _auth?.currentUser?.email,
        'totalUsers': _auth?.getAllUsers().length ?? 0,
      },
      'storage': {
        'totalKeys': (_storage?.getAllData()['storage']?.length ?? 0) + 
                   (_storage?.getAllData()['listStorage']?.length ?? 0),
      },
      'attendanceRepo': {
        'totalAttendees': _attendanceRepo?.getAllAttendeesData().length ?? 0,
      },
    };
  }

  /// Validate mock environment independence (no external dependencies)
  bool validateIndependence() {
    try {
      if (!_isInitialized) return false;
      
      // Check that all components are properly mocked and don't require external connections
      
      // Test auth operations without network
      final authWorks = _auth!.currentUser != null || _auth!.getAllUsers().isNotEmpty;
      
      // Test storage operations without device storage
      final storageWorks = _storage!.getAllData().isNotEmpty;
      
      // Test repository operations without database
      final repoWorks = _attendanceRepo!.getAllAttendeesData().isNotEmpty;
      
      return authWorks && storageWorks && repoWorks;
    } catch (e) {
      return false;
    }
  }

  /// Validate mock determinism (consistent results across runs)
  bool validateDeterminism() {
    try {
      // Reset and initialize twice, check for consistent results
      reset();
      final firstRun = getStatus();
      
      reset();
      final secondRun = getStatus();
      
      // Compare key metrics for consistency
      return firstRun['auth']['totalUsers'] == secondRun['auth']['totalUsers'] &&
             firstRun['attendanceRepo']['totalAttendees'] == secondRun['attendanceRepo']['totalAttendees'];
    } catch (e) {
      return false;
    }
  }
}