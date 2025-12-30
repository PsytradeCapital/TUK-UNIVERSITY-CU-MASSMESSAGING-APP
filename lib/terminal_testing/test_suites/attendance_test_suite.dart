import '../core/test_suite.dart';
import '../mocks/mock_environment.dart';
import '../../models/attendee_model.dart';

/// Test suite for attendance functionality
/// Tests attendance recording and retrieval using mock environment
class AttendanceTestSuite extends TestSuite {
  final MockEnvironment _mockEnv;
  
  AttendanceTestSuite(this._mockEnv);

  @override
  String get name => 'Attendance Tests';

  @override
  String get category => 'attendance';

  @override
  Future<List<TestResult>> execute() async {
    final results = <TestResult>[];
    
    // Ensure mock environment is set up
    if (!_mockEnv.isInitialized) {
      _mockEnv.setup();
    }

    // Test attendee creation
    results.add(await _testAttendeeCreation());
    
    // Test attendee retrieval
    results.add(await _testAttendeeRetrieval());
    
    // Test attendee updates
    results.add(await _testAttendeeUpdates());
    
    // Test attendance counting
    results.add(await _testAttendanceCounting());
    
    // Test phone number validation
    results.add(await _testPhoneNumberValidation());
    
    // Test attendee search functionality
    results.add(await _testAttendeeSearch());
    
    // Test attendee filtering
    results.add(await _testAttendeeFiltering());
    
    // Test data validation
    results.add(await _testDataValidation());

    return results;
  }

  /// Test attendee creation
  Future<TestResult> _testAttendeeCreation() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Create a new attendee
      final attendee = AttendeeModel(
        name: 'Test Student',
        phoneNumber: '+254712345678',
        yearOfStudy: '2nd Year',
        location: 'Main Campus',
        category: AttendeeCategory.student,
      );
      
      // Test creation
      final attendeeId = await mockRepo.createAttendee(attendee);
      
      if (attendeeId <= 0) {
        throw Exception('Invalid attendee ID returned: $attendeeId');
      }
      
      // Verify attendee was created
      final createdAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (createdAttendee == null) {
        throw Exception('Created attendee not found');
      }
      
      if (createdAttendee.name != 'Test Student') {
        throw Exception('Attendee name mismatch');
      }
      
      if (createdAttendee.phoneNumber != '+254712345678') {
        throw Exception('Attendee phone number mismatch');
      }
      
      // Test duplicate phone number prevention
      try {
        await mockRepo.createAttendee(attendee);
        throw Exception('Duplicate phone number should have been rejected');
      } catch (e) {
        if (!e.toString().contains('Phone number already exists')) {
          throw Exception('Wrong error for duplicate phone: $e');
        }
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Creation',
        status: TestStatus.pass,
        message: 'Attendee creation and duplicate prevention working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Creation',
        status: TestStatus.fail,
        message: 'Attendee creation test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test attendee retrieval
  Future<TestResult> _testAttendeeRetrieval() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Get all attendees (should have test data from initialization)
      final allAttendees = await mockRepo.getAllAttendees();
      if (allAttendees.isEmpty) {
        throw Exception('No attendees found in mock repository');
      }
      
      // Test retrieval by ID
      final firstAttendee = allAttendees.first;
      if (firstAttendee.id == null) {
        throw Exception('Attendee ID is null');
      }
      
      final retrievedById = await mockRepo.getAttendeeById(firstAttendee.id!);
      if (retrievedById == null) {
        throw Exception('Failed to retrieve attendee by ID');
      }
      
      if (retrievedById.name != firstAttendee.name) {
        throw Exception('Retrieved attendee name mismatch');
      }
      
      // Test retrieval by phone number
      final retrievedByPhone = await mockRepo.getAttendeeByPhone(firstAttendee.phoneNumber);
      if (retrievedByPhone == null) {
        throw Exception('Failed to retrieve attendee by phone');
      }
      
      if (retrievedByPhone.id != firstAttendee.id) {
        throw Exception('Retrieved attendee ID mismatch');
      }
      
      // Test phone number existence check
      final phoneExists = await mockRepo.phoneNumberExists(firstAttendee.phoneNumber);
      if (!phoneExists) {
        throw Exception('Phone number existence check failed');
      }
      
      // Test non-existent phone number
      final nonExistentPhone = await mockRepo.phoneNumberExists('+254700000000');
      if (nonExistentPhone) {
        throw Exception('Non-existent phone number should return false');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Retrieval',
        status: TestStatus.pass,
        message: 'Attendee retrieval working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Retrieval',
        status: TestStatus.fail,
        message: 'Attendee retrieval test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test attendee updates
  Future<TestResult> _testAttendeeUpdates() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Get an existing attendee
      final allAttendees = await mockRepo.getAllAttendees();
      if (allAttendees.isEmpty) {
        throw Exception('No attendees available for update test');
      }
      
      final attendee = allAttendees.first;
      if (attendee.id == null) {
        throw Exception('Attendee ID is null');
      }
      
      // Update attendee information
      final updatedAttendee = attendee.copyWith(
        name: 'Updated Name',
        yearOfStudy: '3rd Year',
        location: 'Updated Location',
      );
      
      await mockRepo.updateAttendee(updatedAttendee);
      
      // Verify update
      final retrievedAttendee = await mockRepo.getAttendeeById(attendee.id!);
      if (retrievedAttendee == null) {
        throw Exception('Updated attendee not found');
      }
      
      if (retrievedAttendee.name != 'Updated Name') {
        throw Exception('Attendee name not updated');
      }
      
      if (retrievedAttendee.yearOfStudy != '3rd Year') {
        throw Exception('Year of study not updated');
      }
      
      if (retrievedAttendee.location != 'Updated Location') {
        throw Exception('Location not updated');
      }
      
      // Test update with invalid ID
      try {
        final invalidAttendee = attendee.copyWith(id: 99999);
        await mockRepo.updateAttendee(invalidAttendee);
        throw Exception('Update with invalid ID should have failed');
      } catch (e) {
        if (!e.toString().contains('not found')) {
          throw Exception('Wrong error for invalid ID update: $e');
        }
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Updates',
        status: TestStatus.pass,
        message: 'Attendee updates working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Updates',
        status: TestStatus.fail,
        message: 'Attendee update test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test attendance counting
  Future<TestResult> _testAttendanceCounting() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Get an existing attendee
      final allAttendees = await mockRepo.getAllAttendees();
      if (allAttendees.isEmpty) {
        throw Exception('No attendees available for attendance test');
      }
      
      final attendee = allAttendees.first;
      if (attendee.id == null) {
        throw Exception('Attendee ID is null');
      }
      
      final initialCount = attendee.attendanceCount;
      
      // Increment attendance count
      await mockRepo.incrementAttendanceCount(attendee.id!);
      
      // Verify increment
      final updatedAttendee = await mockRepo.getAttendeeById(attendee.id!);
      if (updatedAttendee == null) {
        throw Exception('Attendee not found after attendance increment');
      }
      
      if (updatedAttendee.attendanceCount != initialCount + 1) {
        throw Exception('Attendance count not incremented correctly');
      }
      
      // Test setting specific attendance count
      const newCount = 10;
      await mockRepo.updateAttendanceCount(attendee.id!, newCount);
      
      final attendeeWithNewCount = await mockRepo.getAttendeeById(attendee.id!);
      if (attendeeWithNewCount == null) {
        throw Exception('Attendee not found after setting attendance count');
      }
      
      if (attendeeWithNewCount.attendanceCount != newCount) {
        throw Exception('Attendance count not set correctly');
      }
      
      // Test attendance statistics
      final stats = await mockRepo.getAttendanceStatistics();
      if (stats['totalAttendees'] == null || stats['totalAttendees'] <= 0) {
        throw Exception('Invalid total attendees in statistics');
      }
      
      if (stats['averageAttendance'] == null) {
        throw Exception('Average attendance not calculated');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Attendance Counting',
        status: TestStatus.pass,
        message: 'Attendance counting working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Attendance Counting',
        status: TestStatus.fail,
        message: 'Attendance counting test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test phone number validation
  Future<TestResult> _testPhoneNumberValidation() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test valid Kenyan phone numbers
      final validNumbers = [
        '+254712345678',
        '+254701234567',
        '0712345678',
        '0701234567',
      ];
      
      for (final number in validNumbers) {
        if (!AttendeeModel.isValidKenyanPhone(number)) {
          throw Exception('Valid phone number rejected: $number');
        }
      }
      
      // Test invalid phone numbers
      final invalidNumbers = [
        '1234567890',      // Wrong format
        '+254612345678',   // Wrong prefix (61 instead of 7)
        '0612345678',      // Wrong prefix
        '+25471234567',    // Too short
        '+2547123456789',  // Too long
        'invalid',         // Not a number
        '',                // Empty
      ];
      
      for (final number in invalidNumbers) {
        if (AttendeeModel.isValidKenyanPhone(number)) {
          throw Exception('Invalid phone number accepted: $number');
        }
      }
      
      // Test phone number normalization
      final testCases = {
        '0712345678': '+254712345678',
        '0701234567': '+254701234567',
        '+254712345678': '+254712345678', // Already normalized
      };
      
      for (final entry in testCases.entries) {
        final normalized = AttendeeModel.normalizePhoneNumber(entry.key);
        if (normalized != entry.value) {
          throw Exception('Phone normalization failed: ${entry.key} -> $normalized (expected ${entry.value})');
        }
      }
      
      // Test phone number masking
      final maskedPhone = AttendeeModel.maskPhoneNumber('+254712345678');
      if (!maskedPhone.contains('****')) {
        throw Exception('Phone number not masked correctly: $maskedPhone');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Phone Number Validation',
        status: TestStatus.pass,
        message: 'Phone number validation working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Phone Number Validation',
        status: TestStatus.fail,
        message: 'Phone number validation test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test attendee search functionality
  Future<TestResult> _testAttendeeSearch() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Test search by name
      final searchResults = await mockRepo.searchAttendeesByName('John');
      
      // Verify search results contain only matching names
      for (final attendee in searchResults) {
        if (!attendee.name.toLowerCase().contains('john')) {
          throw Exception('Search result contains non-matching name: ${attendee.name}');
        }
      }
      
      // Test case-insensitive search
      final caseInsensitiveResults = await mockRepo.searchAttendeesByName('JOHN');
      if (caseInsensitiveResults.length != searchResults.length) {
        throw Exception('Case-insensitive search returned different results');
      }
      
      // Test empty search query
      final emptyResults = await mockRepo.searchAttendeesByName('');
      if (emptyResults.isNotEmpty) {
        throw Exception('Empty search should return no results');
      }
      
      // Test search with no matches
      final noMatchResults = await mockRepo.searchAttendeesByName('NonExistentName');
      if (noMatchResults.isNotEmpty) {
        throw Exception('Search with no matches should return empty list');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Search',
        status: TestStatus.pass,
        message: 'Attendee search working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Search',
        status: TestStatus.fail,
        message: 'Attendee search test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test attendee filtering
  Future<TestResult> _testAttendeeFiltering() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Test filtering by year of study
      final yearResults = await mockRepo.getAttendeesByYear('Year 2');
      for (final attendee in yearResults) {
        if (attendee.yearOfStudy != 'Year 2') {
          throw Exception('Year filter returned wrong year: ${attendee.yearOfStudy}');
        }
      }
      
      // Test filtering by location
      final locationResults = await mockRepo.getAttendeesByLocation('Main Campus');
      for (final attendee in locationResults) {
        if (attendee.location != 'Main Campus') {
          throw Exception('Location filter returned wrong location: ${attendee.location}');
        }
      }
      
      // Test filtering by category
      final categoryResults = await mockRepo.getAttendeesByCategory(AttendeeCategory.student);
      for (final attendee in categoryResults) {
        if (attendee.category != AttendeeCategory.student) {
          throw Exception('Category filter returned wrong category: ${attendee.category}');
        }
      }
      
      // Test filtering by minimum attendance
      const minAttendance = 5;
      final attendanceResults = await mockRepo.getAttendeesWithMinAttendance(minAttendance);
      for (final attendee in attendanceResults) {
        if (attendee.attendanceCount < minAttendance) {
          throw Exception('Attendance filter returned attendee with low attendance: ${attendee.attendanceCount}');
        }
      }
      
      // Test combined filters
      final combinedResults = await mockRepo.getAttendeesWithFilters(
        years: ['Year 1', 'Year 2'],
        locations: ['Main Campus'],
        categories: [AttendeeCategory.student],
      );
      
      for (final attendee in combinedResults) {
        if (!['Year 1', 'Year 2'].contains(attendee.yearOfStudy)) {
          throw Exception('Combined filter failed on year: ${attendee.yearOfStudy}');
        }
        if (attendee.location != 'Main Campus') {
          throw Exception('Combined filter failed on location: ${attendee.location}');
        }
        if (attendee.category != AttendeeCategory.student) {
          throw Exception('Combined filter failed on category: ${attendee.category}');
        }
      }
      
      // Test getting unique locations
      final locations = await mockRepo.getUniqueLocations();
      if (locations.isEmpty) {
        throw Exception('No unique locations returned');
      }
      
      // Verify locations are unique
      final uniqueLocations = locations.toSet();
      if (uniqueLocations.length != locations.length) {
        throw Exception('Duplicate locations in unique locations list');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Filtering',
        status: TestStatus.pass,
        message: 'Attendee filtering working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Attendee Filtering',
        status: TestStatus.fail,
        message: 'Attendee filtering test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test data validation
  Future<TestResult> _testDataValidation() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test valid attendee
      final validAttendee = AttendeeModel(
        name: 'Valid Student',
        phoneNumber: '+254712345678',
        yearOfStudy: '2nd Year',
        location: 'Main Campus',
        category: AttendeeCategory.student,
      );
      
      final validationError = validAttendee.validateFields();
      if (validationError != null) {
        throw Exception('Valid attendee failed validation: $validationError');
      }
      
      // Test invalid name (empty)
      final emptyNameAttendee = AttendeeModel(
        name: '',
        phoneNumber: '+254712345678',
        yearOfStudy: '2nd Year',
        location: 'Main Campus',
      );
      
      final emptyNameError = emptyNameAttendee.validateFields();
      if (emptyNameError == null || !emptyNameError.contains('Name cannot be empty')) {
        throw Exception('Empty name validation failed');
      }
      
      // Test invalid name (too short)
      final shortNameAttendee = AttendeeModel(
        name: 'A',
        phoneNumber: '+254712345678',
        yearOfStudy: '2nd Year',
        location: 'Main Campus',
      );
      
      final shortNameError = shortNameAttendee.validateFields();
      if (shortNameError == null || !shortNameError.contains('at least 2 characters')) {
        throw Exception('Short name validation failed');
      }
      
      // Test invalid phone number
      final invalidPhoneAttendee = AttendeeModel(
        name: 'Test Student',
        phoneNumber: '1234567890',
        yearOfStudy: '2nd Year',
        location: 'Main Campus',
      );
      
      final phoneError = invalidPhoneAttendee.validateFields();
      if (phoneError == null || !phoneError.contains('Invalid phone number')) {
        throw Exception('Invalid phone validation failed');
      }
      
      // Test missing year for student
      final missingYearAttendee = AttendeeModel(
        name: 'Test Student',
        phoneNumber: '+254712345678',
        yearOfStudy: '',
        location: 'Main Campus',
        category: AttendeeCategory.student,
      );
      
      final yearError = missingYearAttendee.validateFields();
      if (yearError == null || !yearError.contains('Year of study is required')) {
        throw Exception('Missing year validation failed');
      }
      
      // Test empty location
      final emptyLocationAttendee = AttendeeModel(
        name: 'Test Student',
        phoneNumber: '+254712345678',
        yearOfStudy: '2nd Year',
        location: '',
      );
      
      final locationError = emptyLocationAttendee.validateFields();
      if (locationError == null || !locationError.contains('Location is required')) {
        throw Exception('Empty location validation failed');
      }
      
      // Test category conversion
      final categoryString = AttendeeModel.categoryToString(AttendeeCategory.student);
      if (categoryString != 'student') {
        throw Exception('Category to string conversion failed');
      }
      
      final categoryEnum = AttendeeModel.categoryFromString('student');
      if (categoryEnum != AttendeeCategory.student) {
        throw Exception('String to category conversion failed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Data Validation',
        status: TestStatus.pass,
        message: 'Data validation working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Data Validation',
        status: TestStatus.fail,
        message: 'Data validation test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }
}