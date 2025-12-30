import 'dart:async';
import '../../models/attendee_model.dart';

/// Mock Attendance Repository for terminal testing
/// Simulates attendance data operations without database dependency
class MockAttendanceRepository {
  // Remove singleton pattern to allow proper isolation between test iterations
  MockAttendanceRepository();

  final Map<int, AttendeeModel> _attendees = {};
  final Map<String, AttendeeModel> _phoneIndex = {};
  int _nextId = 1;
  StreamController<List<AttendeeModel>>? _attendeesStreamController;
  bool _isDisposed = false;

  /// Get or create stream controller
  StreamController<List<AttendeeModel>> get _streamController {
    _attendeesStreamController ??= StreamController<List<AttendeeModel>>.broadcast();
    return _attendeesStreamController!;
  }

  /// Safely notify listeners if not disposed
  void _notifyListeners() {
    if (!_isDisposed && _attendeesStreamController != null && !_attendeesStreamController!.isClosed) {
      _attendeesStreamController!.add(_attendees.values.toList());
    }
  }

  /// Initialize mock repository with default test data
  void initialize() {
    _isDisposed = false;
    
    // Create default test attendees
    final testAttendees = [
      AttendeeModel(
        id: _nextId++,
        name: 'John Doe',
        phoneNumber: '+1234567890',
        yearOfStudy: 'Year 1',
        location: 'Main Campus',
        category: AttendeeCategory.student,
        attendanceCount: 5,
        firstRegistered: DateTime.now().subtract(const Duration(days: 30)),
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      ),
      AttendeeModel(
        id: _nextId++,
        name: 'Jane Smith',
        phoneNumber: '+1234567891',
        yearOfStudy: 'Year 2',
        location: 'Library',
        category: AttendeeCategory.student,
        attendanceCount: 8,
        firstRegistered: DateTime.now().subtract(const Duration(days: 25)),
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AttendeeModel(
        id: _nextId++,
        name: 'Bob Johnson',
        phoneNumber: '+1234567892',
        yearOfStudy: 'Year 3',
        location: 'Main Campus',
        category: AttendeeCategory.visitor,
        attendanceCount: 3,
        firstRegistered: DateTime.now().subtract(const Duration(days: 15)),
        lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      AttendeeModel(
        id: _nextId++,
        name: 'Alice Brown',
        phoneNumber: '+1234567893',
        yearOfStudy: 'Graduate',
        location: 'Research Center',
        category: AttendeeCategory.associate,
        attendanceCount: 12,
        firstRegistered: DateTime.now().subtract(const Duration(days: 60)),
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];

    for (final attendee in testAttendees) {
      _attendees[attendee.id!] = attendee;
      _phoneIndex[attendee.phoneNumber] = attendee;
    }

    // Notify initial data
    _notifyListeners();
  }

  /// Create a new attendee
  Future<int> createAttendee(AttendeeModel attendee) async {
    // Simulate database operation delay
    await Future.delayed(const Duration(milliseconds: 50));

    // Check for duplicate phone number
    if (_phoneIndex.containsKey(attendee.phoneNumber)) {
      throw MockAttendeeRepositoryException('Phone number already exists');
    }

    // Assign ID and create attendee
    final id = _nextId++;
    final newAttendee = attendee.copyWith(
      id: id,
      firstRegistered: attendee.firstRegistered ?? DateTime.now(),
      lastUpdated: DateTime.now(),
    );

    _attendees[id] = newAttendee;
    _phoneIndex[newAttendee.phoneNumber] = newAttendee;

    // Notify listeners
    _notifyListeners();

    return id;
  }

  /// Get attendee by ID
  Future<AttendeeModel?> getAttendeeById(int id) async {
    await Future.delayed(const Duration(milliseconds: 20));
    return _attendees[id];
  }

  /// Get attendee by phone number
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 25));
    
    // Normalize phone number for lookup
    final normalizedPhone = AttendeeModel.normalizePhoneNumber(phoneNumber);
    return _phoneIndex[normalizedPhone];
  }

  /// Check if phone number already exists
  Future<bool> phoneNumberExists(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 15));
    
    final normalizedPhone = AttendeeModel.normalizePhoneNumber(phoneNumber);
    return _phoneIndex.containsKey(normalizedPhone);
  }

  /// Get all attendees
  Future<List<AttendeeModel>> getAllAttendees() async {
    await Future.delayed(const Duration(milliseconds: 30));
    
    final attendees = _attendees.values.toList();
    attendees.sort((a, b) => a.name.compareTo(b.name));
    return attendees;
  }

  /// Search attendees by name
  Future<List<AttendeeModel>> searchAttendeesByName(String query) async {
    await Future.delayed(const Duration(milliseconds: 25));
    
    final filteredAttendees = _attendees.values.where((attendee) {
      return attendee.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    
    filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
    return filteredAttendees;
  }

  /// Update attendee
  Future<void> updateAttendee(AttendeeModel attendee) async {
    await Future.delayed(const Duration(milliseconds: 40));

    if (attendee.id == null || !_attendees.containsKey(attendee.id)) {
      throw MockAttendeeRepositoryException('Attendee not found for update');
    }

    // Check for phone number conflicts (excluding current attendee)
    final existingAttendeeWithPhone = _phoneIndex[attendee.phoneNumber];
    if (existingAttendeeWithPhone != null && existingAttendeeWithPhone.id != attendee.id) {
      throw MockAttendeeRepositoryException('Phone number already exists');
    }

    // Remove old phone index entry
    final oldAttendee = _attendees[attendee.id!]!;
    _phoneIndex.remove(oldAttendee.phoneNumber);

    // Update attendee with new timestamp
    final updatedAttendee = attendee.copyWith(lastUpdated: DateTime.now());
    _attendees[attendee.id!] = updatedAttendee;
    _phoneIndex[updatedAttendee.phoneNumber] = updatedAttendee;

    // Notify listeners
    _notifyListeners();
  }

  /// Update attendance count
  Future<void> updateAttendanceCount(int attendeeId, int newCount) async {
    await Future.delayed(const Duration(milliseconds: 30));

    final attendee = _attendees[attendeeId];
    if (attendee == null) {
      throw MockAttendeeRepositoryException('Attendee not found for attendance update');
    }

    final updatedAttendee = attendee.copyWith(
      attendanceCount: newCount,
      lastUpdated: DateTime.now(),
    );

    _attendees[attendeeId] = updatedAttendee;
    _phoneIndex[updatedAttendee.phoneNumber] = updatedAttendee;

    // Notify listeners
    _notifyListeners();
  }

  /// Increment attendance count
  Future<void> incrementAttendanceCount(int attendeeId) async {
    await Future.delayed(const Duration(milliseconds: 25));

    final attendee = _attendees[attendeeId];
    if (attendee == null) {
      throw MockAttendeeRepositoryException('Attendee not found for attendance increment');
    }

    final updatedAttendee = attendee.copyWith(
      attendanceCount: attendee.attendanceCount + 1,
      lastUpdated: DateTime.now(),
    );

    _attendees[attendeeId] = updatedAttendee;
    _phoneIndex[updatedAttendee.phoneNumber] = updatedAttendee;

    // Notify listeners
    _notifyListeners();
  }

  /// Delete attendee
  Future<void> deleteAttendee(int id) async {
    await Future.delayed(const Duration(milliseconds: 35));

    final attendee = _attendees[id];
    if (attendee == null) {
      throw MockAttendeeRepositoryException('Attendee not found for deletion');
    }

    _attendees.remove(id);
    _phoneIndex.remove(attendee.phoneNumber);

    // Notify listeners
    _notifyListeners();
  }

  /// Get attendees with minimum attendance
  Future<List<AttendeeModel>> getAttendeesWithMinAttendance(int minAttendance) async {
    await Future.delayed(const Duration(milliseconds: 30));

    final filteredAttendees = _attendees.values
        .where((attendee) => attendee.attendanceCount >= minAttendance)
        .toList();

    filteredAttendees.sort((a, b) => b.attendanceCount.compareTo(a.attendanceCount));
    return filteredAttendees;
  }

  /// Get attendees by year of study
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    await Future.delayed(const Duration(milliseconds: 25));

    final filteredAttendees = _attendees.values
        .where((attendee) => attendee.yearOfStudy == yearOfStudy)
        .toList();

    filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
    return filteredAttendees;
  }

  /// Get attendees by location
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    await Future.delayed(const Duration(milliseconds: 25));

    final filteredAttendees = _attendees.values
        .where((attendee) => attendee.location == location)
        .toList();

    filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
    return filteredAttendees;
  }

  /// Get unique locations
  Future<List<String>> getUniqueLocations() async {
    await Future.delayed(const Duration(milliseconds: 20));

    final locations = _attendees.values
        .map((attendee) => attendee.location)
        .toSet()
        .toList();

    locations.sort();
    return locations;
  }

  /// Get attendees by category
  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    await Future.delayed(const Duration(milliseconds: 25));

    final filteredAttendees = _attendees.values
        .where((attendee) => attendee.category == category)
        .toList();

    filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
    return filteredAttendees;
  }

  /// Get attendees with filters
  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  }) async {
    await Future.delayed(const Duration(milliseconds: 35));

    var filteredAttendees = _attendees.values.toList();

    if (years != null && years.isNotEmpty) {
      filteredAttendees = filteredAttendees
          .where((attendee) => years.contains(attendee.yearOfStudy))
          .toList();
    }

    if (locations != null && locations.isNotEmpty) {
      filteredAttendees = filteredAttendees
          .where((attendee) => locations.contains(attendee.location))
          .toList();
    }

    if (categories != null && categories.isNotEmpty) {
      filteredAttendees = filteredAttendees
          .where((attendee) => categories.contains(attendee.category))
          .toList();
    }

    filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
    return filteredAttendees;
  }

  /// Get attendance statistics
  Future<Map<String, dynamic>> getAttendanceStatistics() async {
    await Future.delayed(const Duration(milliseconds: 40));

    if (_attendees.isEmpty) {
      return {
        'totalAttendees': 0,
        'averageAttendance': 0.0,
        'maxAttendance': 0,
        'minAttendance': 0,
        'totalAttendanceCount': 0,
      };
    }

    final attendanceCounts = _attendees.values.map((a) => a.attendanceCount).toList();
    final totalAttendanceCount = attendanceCounts.fold(0, (sum, count) => sum + count);
    final averageAttendance = totalAttendanceCount / _attendees.length;

    return {
      'totalAttendees': _attendees.length,
      'averageAttendance': averageAttendance,
      'maxAttendance': attendanceCounts.reduce((a, b) => a > b ? a : b),
      'minAttendance': attendanceCounts.reduce((a, b) => a < b ? a : b),
      'totalAttendanceCount': totalAttendanceCount,
    };
  }

  /// Get recently registered attendees
  Future<List<AttendeeModel>> getRecentlyRegistered({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 25));

    final attendees = _attendees.values.toList();
    attendees.sort((a, b) => b.firstRegistered.compareTo(a.firstRegistered));
    
    return attendees.take(limit).toList();
  }

  /// Bulk insert attendees
  Future<List<int>> bulkInsertAttendees(List<AttendeeModel> attendees) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final insertedIds = <int>[];

    for (final attendee in attendees) {
      // Skip duplicates
      if (_phoneIndex.containsKey(attendee.phoneNumber)) {
        continue;
      }

      final id = _nextId++;
      final newAttendee = attendee.copyWith(
        id: id,
        firstRegistered: attendee.firstRegistered ?? DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      _attendees[id] = newAttendee;
      _phoneIndex[newAttendee.phoneNumber] = newAttendee;
      insertedIds.add(id);
    }

    // Notify listeners
    _notifyListeners();

    return insertedIds;
  }

  /// Get total attendees count
  Future<int> getTotalAttendeesCount() async {
    await Future.delayed(const Duration(milliseconds: 10));
    return _attendees.length;
  }

  /// Stream of attendees (for real-time updates)
  Stream<List<AttendeeModel>> get attendeesStream => _streamController.stream;

  /// Reset mock repository to initial state
  void reset() {
    _attendees.clear();
    _phoneIndex.clear();
    _nextId = 1;
    _isDisposed = false;
    initialize();
  }

  /// Add test attendee for specific scenarios
  void addTestAttendee(AttendeeModel attendee) {
    final id = attendee.id ?? _nextId++;
    final testAttendee = attendee.copyWith(
      id: id,
      firstRegistered: attendee.firstRegistered ?? DateTime.now(),
      lastUpdated: attendee.lastUpdated ?? DateTime.now(),
    );

    _attendees[id] = testAttendee;
    _phoneIndex[testAttendee.phoneNumber] = testAttendee;
    
    if (id >= _nextId) {
      _nextId = id + 1;
    }

    // Notify listeners
    _notifyListeners();
  }

  /// Get all attendees data (for testing purposes)
  Map<int, AttendeeModel> getAllAttendeesData() {
    return Map<int, AttendeeModel>.from(_attendees);
  }

  /// Simulate repository error for testing error handling
  void simulateError(String operation, {Duration? delay}) {
    // This could be used in tests to simulate repository failures
    // For now, it's a placeholder for future error simulation features
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _attendeesStreamController?.close();
    _attendeesStreamController = null;
  }
}

/// Mock attendee repository exception
class MockAttendeeRepositoryException implements Exception {
  final String message;

  const MockAttendeeRepositoryException(this.message);

  @override
  String toString() {
    return 'MockAttendeeRepositoryException: $message';
  }
}