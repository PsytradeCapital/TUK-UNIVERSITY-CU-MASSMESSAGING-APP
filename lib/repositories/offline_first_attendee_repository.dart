import 'package:sqflite/sqflite.dart';
import '../models/attendee_model.dart';
import '../services/database_manager.dart';
import 'attendee_repository.dart';

/// Offline-First Attendee Repository
/// 100% LOCAL ONLY - No Firebase queries
/// Loads from SQLite database instantly
class OfflineFirstAttendeeRepository {
  final AttendeeRepository _localRepo = AttendeeRepository();

  /// Expose raw DB for batch operations
  Future<Database> getDatabase() async {
    return await DatabaseManager.instance.database;
  }

  /// Get all attendees - INSTANT (from local DB only)
  Future<List<AttendeeModel>> getAllAttendees() async {
    return await _localRepo.getAllAttendees();
  }

  /// Search attendees - INSTANT (from local DB only)
  Future<List<AttendeeModel>> searchAttendees(String query) async {
    return await _localRepo.searchAttendeesByName(query);
  }

  /// Get attendee by ID - INSTANT (from local DB only)
  Future<AttendeeModel?> getAttendeeById(int id) async {
    return await _localRepo.getAttendeeById(id);
  }

  /// Get attendee by phone - INSTANT (from local DB only)
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    return await _localRepo.getAttendeeByPhone(phoneNumber);
  }

  /// Create attendee - INSTANT (saves locally only)
  Future<int> createAttendee(AttendeeModel attendee) async {
    return await _localRepo.createAttendee(attendee);
  }

  /// Update attendee - INSTANT (saves locally only)
  Future<void> updateAttendee(AttendeeModel attendee) async {
    await _localRepo.updateAttendee(attendee);
  }

  /// Delete attendee - INSTANT (deletes locally only)
  Future<void> deleteAttendee(int id) async {
    await _localRepo.deleteAttendee(id);
  }

  /// Get attendees with filters - INSTANT (from local DB only)
  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  }) async {
    return await _localRepo.getAttendeesWithFilters(
      years: years,
      locations: locations,
      categories: categories,
    );
  }

  /// Get attendees by year - INSTANT (from local DB only)
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    return await _localRepo.getAttendeesByYear(yearOfStudy);
  }

  /// Get attendees by location - INSTANT (from local DB only)
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    return await _localRepo.getAttendeesByLocation(location);
  }

  /// Get attendees by category - INSTANT (from local DB only)
  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    return await _localRepo.getAttendeesByCategory(category);
  }

  /// Get unique locations - INSTANT (from local DB only)
  Future<List<String>> getUniqueLocations() async {
    return await _localRepo.getUniqueLocations();
  }

  /// Get total attendees count - INSTANT (from local DB only)
  Future<int> getTotalAttendeesCount() async {
    return await _localRepo.getTotalAttendeesCount();
  }

  /// Get attendees with minimum attendance - INSTANT (from local DB only)
  Future<List<AttendeeModel>> getAttendeesWithMinAttendance(int minAttendance) async {
    return await _localRepo.getAttendeesWithMinAttendance(minAttendance);
  }

  /// Check if phone number exists - INSTANT (from local DB only)
  Future<bool> phoneNumberExists(String phoneNumber) async {
    final attendee = await getAttendeeByPhone(phoneNumber);
    return attendee != null;
  }
}
