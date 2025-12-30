import '../core/test_suite.dart';
import '../mocks/mock_environment.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

/// Test suite for authentication functionality
/// Tests user registration and login flows using mock environment
class AuthTestSuite extends TestSuite {
  final MockEnvironment _mockEnv;
  
  AuthTestSuite(this._mockEnv);

  @override
  String get name => 'Authentication Tests';

  @override
  String get category => 'auth';

  @override
  Future<List<TestResult>> execute() async {
    final results = <TestResult>[];
    
    // Ensure mock environment is set up
    if (!_mockEnv.isInitialized) {
      _mockEnv.setup();
    }

    // Test user registration flow
    results.add(await _testUserRegistration());
    
    // Test user login flow
    results.add(await _testUserLogin());
    
    // Test invalid login attempts
    results.add(await _testInvalidLogin());
    
    // Test password reset functionality
    results.add(await _testPasswordReset());
    
    // Test authentication state changes
    results.add(await _testAuthStateChanges());
    
    // Test user profile updates
    results.add(await _testProfileUpdate());
    
    // Test authentication error handling
    results.add(await _testAuthErrorHandling());
    
    // Test user approval workflow
    results.add(await _testUserApprovalWorkflow());

    return results;
  }

  /// Test user registration flow
  Future<TestResult> _testUserRegistration() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // Test successful registration
      final userCredential = await mockAuth.createUserWithEmailAndPassword(
        email: 'newuser@test.com',
        password: 'TestPass123!',
      );
      
      // Verify user was created
      if (userCredential.user.email != 'newuser@test.com') {
        throw Exception('User email mismatch after registration');
      }
      
      // Verify user is now current user
      if (mockAuth.currentUser?.email != 'newuser@test.com') {
        throw Exception('Current user not set after registration');
      }
      
      // Test duplicate email registration (should fail)
      try {
        await mockAuth.createUserWithEmailAndPassword(
          email: 'newuser@test.com',
          password: 'AnotherPass123!',
        );
        throw Exception('Duplicate email registration should have failed');
      } catch (e) {
        if (!e.toString().contains('email-already-in-use')) {
          throw Exception('Wrong error for duplicate email: $e');
        }
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'User Registration Flow',
        status: TestStatus.pass,
        message: 'User registration and duplicate prevention working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'User Registration Flow',
        status: TestStatus.fail,
        message: 'Registration test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test user login flow
  Future<TestResult> _testUserLogin() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // First ensure we have a test user (should exist from initialization)
      final testUsers = mockAuth.getAllUsers();
      if (testUsers.isEmpty) {
        throw Exception('No test users available for login test');
      }
      
      final testUser = testUsers.first;
      
      // Sign out first to test login
      await mockAuth.signOut();
      if (mockAuth.currentUser != null) {
        throw Exception('Sign out failed - user still authenticated');
      }
      
      // Test successful login
      final userCredential = await mockAuth.signInWithEmailAndPassword(
        email: testUser.email,
        password: 'TestPass123!', // Default password from mock initialization
      );
      
      // Verify login success
      if (userCredential.user.email != testUser.email) {
        throw Exception('Login user email mismatch');
      }
      
      if (mockAuth.currentUser?.email != testUser.email) {
        throw Exception('Current user not set after login');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'User Login Flow',
        status: TestStatus.pass,
        message: 'User login working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'User Login Flow',
        status: TestStatus.fail,
        message: 'Login test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test invalid login attempts
  Future<TestResult> _testInvalidLogin() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // Test login with non-existent user
      try {
        await mockAuth.signInWithEmailAndPassword(
          email: 'nonexistent@test.com',
          password: 'AnyPassword123!',
        );
        throw Exception('Login with non-existent user should have failed');
      } catch (e) {
        if (!e.toString().contains('user-not-found')) {
          throw Exception('Wrong error for non-existent user: $e');
        }
      }
      
      // Test login with wrong password
      final testUsers = mockAuth.getAllUsers();
      if (testUsers.isNotEmpty) {
        try {
          await mockAuth.signInWithEmailAndPassword(
            email: testUsers.first.email,
            password: 'WrongPassword123!',
          );
          throw Exception('Login with wrong password should have failed');
        } catch (e) {
          if (!e.toString().contains('wrong-password')) {
            throw Exception('Wrong error for incorrect password: $e');
          }
        }
      }
      
      // Test login with invalid email format
      try {
        await mockAuth.signInWithEmailAndPassword(
          email: 'invalid-email',
          password: 'AnyPassword123!',
        );
        throw Exception('Login with invalid email should have failed');
      } catch (e) {
        if (!e.toString().contains('invalid-email')) {
          throw Exception('Wrong error for invalid email: $e');
        }
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Invalid Login Attempts',
        status: TestStatus.pass,
        message: 'Invalid login attempts properly rejected',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Invalid Login Attempts',
        status: TestStatus.fail,
        message: 'Invalid login test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test password reset functionality
  Future<TestResult> _testPasswordReset() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // Test password reset for existing user
      final testUsers = mockAuth.getAllUsers();
      if (testUsers.isNotEmpty) {
        // Should not throw exception for existing user
        await mockAuth.sendPasswordResetEmail(email: testUsers.first.email);
      }
      
      // Test password reset for non-existent user
      try {
        await mockAuth.sendPasswordResetEmail(email: 'nonexistent@test.com');
        throw Exception('Password reset for non-existent user should have failed');
      } catch (e) {
        if (!e.toString().contains('user-not-found')) {
          throw Exception('Wrong error for password reset with non-existent user: $e');
        }
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Password Reset Functionality',
        status: TestStatus.pass,
        message: 'Password reset working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Password Reset Functionality',
        status: TestStatus.fail,
        message: 'Password reset test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test authentication state changes
  Future<TestResult> _testAuthStateChanges() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      bool stateChangeReceived = false;
      
      // Listen to auth state changes
      final subscription = mockAuth.authStateChanges.listen((user) {
        stateChangeReceived = true;
      });
      
      // Trigger state change by signing out
      await mockAuth.signOut();
      
      // Wait a bit for the stream to emit
      await Future.delayed(const Duration(milliseconds: 100));
      
      subscription.cancel();
      
      if (!stateChangeReceived) {
        throw Exception('Auth state change not received');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Authentication State Changes',
        status: TestStatus.pass,
        message: 'Auth state changes working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Authentication State Changes',
        status: TestStatus.fail,
        message: 'Auth state changes test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test user profile updates
  Future<TestResult> _testProfileUpdate() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // Ensure we have a logged-in user
      final testUsers = mockAuth.getAllUsers();
      if (testUsers.isEmpty) {
        throw Exception('No test users available for profile update test');
      }
      
      await mockAuth.signInWithEmailAndPassword(
        email: testUsers.first.email,
        password: 'TestPass123!',
      );
      
      // Test profile update
      await mockAuth.updateProfile(
        displayName: 'Updated Test Name',
        photoURL: 'https://example.com/photo.jpg',
      );
      
      // Verify update
      final currentUser = mockAuth.currentUser;
      if (currentUser?.displayName != 'Updated Test Name') {
        throw Exception('Display name not updated correctly');
      }
      
      if (currentUser?.photoURL != 'https://example.com/photo.jpg') {
        throw Exception('Photo URL not updated correctly');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'User Profile Updates',
        status: TestStatus.pass,
        message: 'Profile updates working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'User Profile Updates',
        status: TestStatus.fail,
        message: 'Profile update test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test authentication error handling
  Future<TestResult> _testAuthErrorHandling() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // Test weak password error
      try {
        await mockAuth.createUserWithEmailAndPassword(
          email: 'weakpass@test.com',
          password: '123', // Too weak
        );
        throw Exception('Weak password should have been rejected');
      } catch (e) {
        if (!e.toString().contains('weak-password')) {
          throw Exception('Wrong error for weak password: $e');
        }
      }
      
      // Test invalid email error
      try {
        await mockAuth.createUserWithEmailAndPassword(
          email: 'invalid-email-format',
          password: 'ValidPass123!',
        );
        throw Exception('Invalid email should have been rejected');
      } catch (e) {
        if (!e.toString().contains('invalid-email')) {
          throw Exception('Wrong error for invalid email: $e');
        }
      }
      
      // Test operations without authenticated user
      await mockAuth.signOut();
      
      try {
        await mockAuth.updateProfile(displayName: 'Should Fail');
        throw Exception('Profile update without auth should have failed');
      } catch (e) {
        if (!e.toString().contains('no-current-user')) {
          throw Exception('Wrong error for unauthenticated profile update: $e');
        }
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Authentication Error Handling',
        status: TestStatus.pass,
        message: 'Error handling working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Authentication Error Handling',
        status: TestStatus.fail,
        message: 'Error handling test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test user approval workflow
  Future<TestResult> _testUserApprovalWorkflow() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockAuth = _mockEnv.auth;
      
      // Create a new user
      final userCredential = await mockAuth.createUserWithEmailAndPassword(
        email: 'approval@test.com',
        password: 'TestPass123!',
      );
      
      // Convert to UserModel to test approval workflow
      final userModel = userCredential.user.toUserModel(
        role: UserRole.leader,
        isApproved: false, // Not approved initially
      );
      
      // Verify user is not approved
      if (userModel.isApproved) {
        throw Exception('New user should not be approved initially');
      }
      
      // Test approval
      final approvedUser = userModel.copyWith(isApproved: true);
      if (!approvedUser.isApproved) {
        throw Exception('User approval not working');
      }
      
      // Test role assignment
      if (approvedUser.role != UserRole.leader) {
        throw Exception('User role not set correctly');
      }
      
      // Test admin role
      final adminUser = userModel.copyWith(
        role: UserRole.admin,
        isApproved: true,
      );
      
      if (!adminUser.isAdmin) {
        throw Exception('Admin role check not working');
      }
      
      if (!adminUser.canApproveUsers) {
        throw Exception('Admin permissions not working');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'User Approval Workflow',
        status: TestStatus.pass,
        message: 'User approval workflow working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'User Approval Workflow',
        status: TestStatus.fail,
        message: 'User approval test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }
}