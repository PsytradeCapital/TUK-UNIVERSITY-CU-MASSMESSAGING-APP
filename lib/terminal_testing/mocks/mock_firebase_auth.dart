import 'dart:async';
import '../../models/user_model.dart';

/// Mock Firebase Authentication for terminal testing
/// Simulates Firebase Auth behavior without network dependency
class MockFirebaseAuth {
  // Remove singleton pattern to allow proper isolation between test iterations
  MockFirebaseAuth();

  final Map<String, MockUser> _users = {};
  final Map<String, String> _emailToPassword = {};
  MockUser? _currentUser;
  StreamController<MockUser?>? _authStateController;

  /// Get or create stream controller
  StreamController<MockUser?> get _streamController {
    _authStateController ??= StreamController<MockUser?>.broadcast();
    return _authStateController!;
  }

  /// Safely notify auth state change
  void _notifyAuthStateChange(MockUser? user) {
    if (_authStateController != null && !_authStateController!.isClosed) {
      _authStateController!.add(user);
    }
  }

  /// Initialize mock auth with default test data
  void initialize() {
    // Create default admin user for testing
    final adminUser = MockUser(
      uid: 'mock-admin-uid',
      email: 'admin@test.com',
      displayName: 'Test Admin',
    );
    
    _users['mock-admin-uid'] = adminUser;
    _emailToPassword['admin@test.com'] = 'TestPass123!';
    
    // Create default regular user for testing
    final regularUser = MockUser(
      uid: 'mock-user-uid',
      email: 'user@test.com',
      displayName: 'Test User',
    );
    
    _users['mock-user-uid'] = regularUser;
    _emailToPassword['user@test.com'] = 'TestPass123!';
  }

  /// Get current authenticated user
  MockUser? get currentUser => _currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Stream of authentication state changes
  Stream<MockUser?> get authStateChanges => _streamController.stream;

  /// Sign up new user with email and password
  Future<MockUserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Validate email format
    if (!_isValidEmail(email)) {
      throw MockFirebaseAuthException(
        code: 'invalid-email',
        message: 'The email address is badly formatted.',
      );
    }

    // Check if user already exists
    if (_emailToPassword.containsKey(email)) {
      throw MockFirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The account already exists for that email.',
      );
    }

    // Validate password strength
    if (password.length < 6) {
      throw MockFirebaseAuthException(
        code: 'weak-password',
        message: 'Password should be at least 6 characters',
      );
    }

    // Create new user
    final uid = 'mock-${DateTime.now().millisecondsSinceEpoch}';
    final user = MockUser(
      uid: uid,
      email: email,
      displayName: null,
    );

    _users[uid] = user;
    _emailToPassword[email] = password;
    _currentUser = user;

    // Notify auth state change
    _notifyAuthStateChange(_currentUser);

    return MockUserCredential(user: user);
  }

  /// Sign in existing user with email and password
  Future<MockUserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Check if user exists
    if (!_emailToPassword.containsKey(email)) {
      throw MockFirebaseAuthException(
        code: 'user-not-found',
        message: 'There is no user record corresponding to this identifier.',
      );
    }

    // Check password
    if (_emailToPassword[email] != password) {
      throw MockFirebaseAuthException(
        code: 'wrong-password',
        message: 'The password is invalid or the user does not have a password.',
      );
    }

    // Find user by email
    final user = _users.values.firstWhere((u) => u.email == email);
    _currentUser = user;

    // Notify auth state change
    _notifyAuthStateChange(_currentUser);

    return MockUserCredential(user: user);
  }

  /// Sign out current user
  Future<void> signOut() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));

    _currentUser = null;
    _notifyAuthStateChange(null);
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Check if user exists
    if (!_emailToPassword.containsKey(email)) {
      throw MockFirebaseAuthException(
        code: 'user-not-found',
        message: 'There is no user record corresponding to this identifier.',
      );
    }

    // In mock, we just simulate success
    // In real implementation, Firebase would send an email
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    if (_currentUser == null) {
      throw MockFirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Update user profile
    final updatedUser = MockUser(
      uid: _currentUser!.uid,
      email: _currentUser!.email,
      displayName: displayName ?? _currentUser!.displayName,
      photoURL: photoURL ?? _currentUser!.photoURL,
    );

    _users[_currentUser!.uid] = updatedUser;
    _currentUser = updatedUser;

    // Notify auth state change
    _notifyAuthStateChange(_currentUser);
  }

  /// Change user password
  Future<void> updatePassword(String newPassword) async {
    if (_currentUser == null) {
      throw MockFirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }

    // Validate password strength
    if (newPassword.length < 6) {
      throw MockFirebaseAuthException(
        code: 'weak-password',
        message: 'Password should be at least 6 characters',
      );
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Update password
    _emailToPassword[_currentUser!.email] = newPassword;
  }

  /// Delete current user
  Future<void> deleteUser() async {
    if (_currentUser == null) {
      throw MockFirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    final userEmail = _currentUser!.email;
    final userUid = _currentUser!.uid;

    // Remove user data
    _users.remove(userUid);
    _emailToPassword.remove(userEmail);
    _currentUser = null;

    // Notify auth state change
    _notifyAuthStateChange(null);
  }

  /// Reload current user data
  Future<void> reload() async {
    if (_currentUser == null) return;

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));

    // In mock, user data doesn't change externally, so nothing to reload
  }

  /// Reset mock state for testing
  void reset() {
    _users.clear();
    _emailToPassword.clear();
    _currentUser = null;
    _notifyAuthStateChange(null);
  }

  /// Add predefined test user
  void addTestUser({
    required String uid,
    required String email,
    required String password,
    String? displayName,
  }) {
    final user = MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
    );
    
    _users[uid] = user;
    _emailToPassword[email] = password;
  }

  /// Get all registered users (for testing purposes)
  List<MockUser> getAllUsers() {
    return _users.values.toList();
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Dispose resources
  void dispose() {
    _authStateController?.close();
    _authStateController = null;
  }
}

/// Mock user credential returned by authentication operations
class MockUserCredential {
  final MockUser user;

  const MockUserCredential({required this.user});
}

/// Mock user representing an authenticated user
class MockUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;

  const MockUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
  });

  /// Convert to UserModel for compatibility with app code
  UserModel toUserModel({
    UserRole role = UserRole.leader,
    bool isApproved = true,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: displayName ?? 'Test User',
      role: role,
      isApproved: isApproved,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MockUser &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoURL == photoURL;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ email.hashCode ^ displayName.hashCode ^ photoURL.hashCode;
  }

  @override
  String toString() {
    return 'MockUser(uid: $uid, email: $email, displayName: $displayName)';
  }
}

/// Mock Firebase Auth exception
class MockFirebaseAuthException implements Exception {
  final String code;
  final String message;

  const MockFirebaseAuthException({
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'MockFirebaseAuthException: $message (code: $code)';
  }
}