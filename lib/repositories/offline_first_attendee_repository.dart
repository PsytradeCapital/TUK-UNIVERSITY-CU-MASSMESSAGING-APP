import '../models/attendee_model.dart';
import 'attendee_repository.dart';
import '../services/background_sync_service.dart';

/// Offline-First Attendee Repository
/// ALWAYS loads from local SQLite database first for instant performance
/// Syncs to Firebase in background without blocking UI
class OfflineFirstAttendeeRepository {
  final AttendeeRepository _localRepo = AttendeeRepository();
  final BackgroundSyncService _syncService = BackgroundSyncService();

  /// Get all attendees - INSTANT (from local DB)
  Future<List<AttendeeModel>> getAllAttendees() async {
    // Get from local database immediately
    final attendees = await _localRepo.getAllAttendees();
    
    // Trigger background sync (don't wait)
    _syncService.syncPendingChanges();
    
    return attendees;
  }

  /// Search attendees - INSTANT (from local DB)
  Future<List<AttendeeModel>> searchAttendees(String query) async {
    return await _localRepo.searchAttendeesByName(query);
  }

  /// Get attendee by ID - INSTANT (from local DB)
  Future<AttendeeModel?> getAttendeeById(int id) async {
    return await _localRepo.getAttendeeById(id);
  }

  /// Get attendee by phone - INSTANT (from local DB)
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    return await _localRepo.getAttendeeByPhone(phoneNumber);
  }

  /// Create attendee - INSTANT (saves locally, syncs later)
  Future<int> createAttendee(AttendeeModel attendee) async {
    // Save to local database immediately
    final localId = await _localRepo.createAttendee(
      attendee.copyWith(isSynced: false),
    );
    
    // Trigger background sync (don't wait)
    _syncService.syncPendingChanges();
    
    return localId;
  }

  /// Update attendee - INSTANT (saves locally, syncs later)
  Future<void> updateAttendee(AttendeeModel attendee) async {
    // Update in local database immediately
    await _localRepo.updateAttendee(
      attendee.copyWith(isSynced: false),
    );
    
    // Trigger background sync (don't wait)
    _syncService.syncPendingChanges();
  }

  /// Delete attendee - INSTANT (deletes locally, syncs later)
  Future<void> deleteAttendee(int id) async {
    // Delete from local database immediately
    await _localRepo.deleteAttendee(id);
    
    // Trigger background sync (don't wait)
    _syncService.syncPendingChanges();
  }

  /// Get attendees with filters - INSTANT (from local DB)
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

  /// Get attendees by year - INSTANT (from local DB)
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    return await _localRepo.getAttendeesByYear(yearOfStudy);
  }

  /// Get attendees by location - INSTANT (from local DB)
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    return await _localRepo.getAttendeesByLocation(location);
  }

  /// Get attendees by category - INSTANT (from local DB)
  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    return await _localRepo.getAttendeesByCategory(category);
  }

  /// Get unique locations - INSTANT (from local DB)
  Future<List<String>> getUniqueLocations() async {
    return await _localRepo.getUniqueLocations();
  }

  /// Get total attendees count - INSTANT (from local DB)
  Future<int> getTotalAttendeesCount() async {
    return await _localRepo.getTotalAttendeesCount();
  }

  /// Get attendees with minimum attendance - INSTANT (from local DB)
  Future<List<AttendeeModel>> getAttendeesWithMinAttendance(int minAttendance) async {
    return await _localRepo.getAttendeesWithMinAttendance(minAttendance);
  }

  /// Check if phone number exists - INSTANT (from local DB)
  Future<bool> phoneNumberExists(String phoneNumber) async {
    final attendee = await getAttendeeByPhone(phoneNumber);
    return attendee != null;
  }

  /// Force sync now (manual trigger)
  Future<void> syncNow() async {
    await _syncService.syncPendingChanges();
    await _syncService.pullFromCloud();
  }

  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    return await _syncService.getSyncStatus();
  }
}
