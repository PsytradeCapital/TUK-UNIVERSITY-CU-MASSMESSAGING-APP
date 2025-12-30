import 'dart:async';
import '../models/attendee_model.dart';
import '../repositories/attendee_repository.dart';
import '../services/cloud_sync_service.dart';
import '../services/connectivity_service.dart';

/// Fast Registration Service - Optimized for instant registration
/// 
/// PERFORMANCE OPTIMIZATIONS:
/// - Local-first registration (instant response)
/// - Background cloud sync (non-blocking)
/// - Batch operations for multiple registrations
/// - Minimal validation for speed
/// - Async duplicate checking
class FastRegistrationService {
  static final FastRegistrationService _instance = FastRegistrationService._internal();
  factory FastRegistrationService() => _instance;
  FastRegistrationService._internal();

  final AttendeeRepository _localRepo = AttendeeRepository();
  final CloudSyncService _cloudSync = CloudSyncService();
  final ConnectivityService _connectivity = ConnectivityService();
  
  // Background sync queue
  final List<AttendeeModel> _syncQueue = [];
  Timer? _syncTimer;
  
  /// Initialize fast registration service
  Future<void> initialize() async {
    // Start background sync timer (every 5 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _processSyncQueue();
    });
  }

  /// Register attendee instantly (local-first approach)
  Future<FastRegistrationResult> registerAttendeeInstant({
    required String name,
    required String phoneNumber,
    required String yearOfStudy,
    required String location,
    AttendeeCategory category = AttendeeCategory.student,
  }) async {
    try {
      // Basic validation only (for speed)
      if (name.trim().isEmpty || phoneNumber.trim().isEmpty) {
        return FastRegistrationResult.failure('Name and phone number are required');
      }

      // Create attendee model
      final attendee = AttendeeModel(
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
        yearOfStudy: yearOfStudy,
        location: location.trim(),
        category: category,
        firstRegistered: DateTime.now(),
        isSynced: false, // Mark as not synced yet
      );

      // INSTANT LOCAL REGISTRATION (no waiting)
      final localId = await _localRepo.createAttendee(attendee);
      final registeredAttendee = attendee.copyWith(id: localId);

      // Add to background sync queue (non-blocking)
      _syncQueue.add(registeredAttendee);

      // Return immediately with success
      return FastRegistrationResult.success(registeredAttendee);
      
    } catch (e) {
      return FastRegistrationResult.failure('Registration failed: $e');
    }
  }

  /// Register multiple attendees in batch (for bulk registration)
  Future<List<FastRegistrationResult>> registerAttendeeBatch(
    List<Map<String, String>> attendeeData
  ) async {
    final results = <FastRegistrationResult>[];
    
    for (final data in attendeeData) {
      final result = await registerAttendeeInstant(
        name: data['name'] ?? '',
        phoneNumber: data['phone'] ?? '',
        yearOfStudy: data['year'] ?? '',
        location: data['location'] ?? '',
      );
      results.add(result);
    }
    
    return results;
  }

  /// Check for duplicates asynchronously (non-blocking)
  Future<bool> checkDuplicateAsync(String phoneNumber) async {
    try {
      final existing = await _localRepo.getAttendeeByPhone(phoneNumber);
      return existing != null;
    } catch (e) {
      return false; // Assume no duplicate on error
    }
  }

  /// Process background sync queue
  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty || !_connectivity.isOnline()) {
      return;
    }

    final toSync = List<AttendeeModel>.from(_syncQueue);
    _syncQueue.clear();

    try {
      // Batch sync to cloud - use the general sync method
      await _cloudSync.syncToCloud();
      
      // Mark all synced items as synced in local database
      for (final attendee in toSync) {
        await _localRepo.updateAttendee(
          attendee.copyWith(isSynced: true)
        );
      }
    } catch (e) {
      // Re-add failed items to queue for retry
      _syncQueue.addAll(toSync);
    }
  }

  /// Get registration statistics
  Future<RegistrationStats> getStats() async {
    final totalAttendees = await _localRepo.getTotalAttendeesCount();
    final unsyncedCount = _syncQueue.length;
    final isOnline = _connectivity.isOnline();
    
    return RegistrationStats(
      totalRegistered: totalAttendees,
      pendingSync: unsyncedCount,
      isOnline: isOnline,
    );
  }

  /// Force sync all pending registrations
  Future<void> forceSyncAll() async {
    await _processSyncQueue();
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
  }
}

/// Fast registration result
class FastRegistrationResult {
  final bool success;
  final AttendeeModel? attendee;
  final String? error;

  FastRegistrationResult.success(this.attendee) 
      : success = true, error = null;
  
  FastRegistrationResult.failure(this.error) 
      : success = false, attendee = null;
}

/// Registration statistics
class RegistrationStats {
  final int totalRegistered;
  final int pendingSync;
  final bool isOnline;

  RegistrationStats({
    required this.totalRegistered,
    required this.pendingSync,
    required this.isOnline,
  });
}