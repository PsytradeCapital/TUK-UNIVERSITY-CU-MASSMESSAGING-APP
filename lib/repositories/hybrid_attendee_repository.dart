import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/attendee_model.dart';
import '../models/sync_queue_model.dart';
import 'attendee_repository.dart';
import 'firebase_attendee_repository.dart';
import 'sync_queue_repository.dart';
import '../services/auth_service.dart';

/// Hybrid Attendee Repository
/// ALL reads come from local SQLite (instant, works offline).
/// Writes go to both local and cloud (when online).
/// Cloud sync happens silently in the background — never blocks the UI.
class HybridAttendeeRepository {
  final FirebaseAttendeeRepository _cloudRepo;
  final AttendeeRepository _localRepo;
  final SyncQueueRepository _syncQueueRepo;
  final AuthService _authService;
  final Connectivity _connectivity;

  HybridAttendeeRepository({
    FirebaseAttendeeRepository? cloudRepo,
    AttendeeRepository? localRepo,
    SyncQueueRepository? syncQueueRepo,
    AuthService? authService,
    Connectivity? connectivity,
  })  : _cloudRepo = cloudRepo ?? FirebaseAttendeeRepository(),
        _localRepo = localRepo ?? AttendeeRepository(),
        _syncQueueRepo = syncQueueRepo ?? SyncQueueRepository(),
        _authService = authService ?? AuthService(),
        _connectivity = connectivity ?? Connectivity();

  Future<bool> _isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  bool _isAuthenticated() => _authService.getCurrentUser() != null;

  // ---------------------------------------------------------------------------
  // WRITES — local first, then cloud in background
  // ---------------------------------------------------------------------------

  Future<String> createAttendee(AttendeeModel attendee) async {
    try {
      // Always save locally first for instant response
      final localId = await _localRepo.createAttendee(attendee.copyWith(isSynced: false, version: 1));

      // Push to cloud in background
      Future.microtask(() async {
        try {
          if (!await _isOnline() || !_isAuthenticated()) return;
          final user = _authService.getCurrentUser()!;
          final withCloud = attendee.copyWith(
            createdBy: user.uid, createdAt: DateTime.now(),
            modifiedBy: user.uid, modifiedAt: DateTime.now(),
            isSynced: true, version: 1,
          );
          final firestoreId = await _cloudRepo.createAttendee(withCloud);
          final saved = await _localRepo.getAttendeeById(localId);
          if (saved != null) {
            await _localRepo.updateAttendee(saved.copyWith(firestoreId: firestoreId, isSynced: true));
          }
        } catch (_) {}
      });

      return localId.toString();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to create attendee: $e');
    }
  }

  Future<void> updateAttendee(AttendeeModel attendee) async {
    try {
      // Always update locally first
      await _localRepo.updateAttendee(attendee.copyWith(isSynced: false, lastUpdated: DateTime.now()));

      // Push to cloud in background
      Future.microtask(() async {
        try {
          if (!await _isOnline() || !_isAuthenticated()) return;
          final user = _authService.getCurrentUser()!;
          final withCloud = attendee.copyWith(
            modifiedBy: user.uid, modifiedAt: DateTime.now(),
            isSynced: true, version: attendee.version + 1,
          );
          if (withCloud.firestoreId != null) {
            await _cloudRepo.updateAttendee(withCloud);
          }
          if (withCloud.id != null) {
            await _localRepo.updateAttendee(withCloud);
          }
        } catch (_) {}
      });
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to update attendee: $e');
    }
  }

  Future<void> deleteAttendee(String id) async {
    try {
      final localId = int.tryParse(id);
      AttendeeModel? attendee;
      if (localId != null) attendee = await _localRepo.getAttendeeById(localId);

      if (attendee?.id != null) await _localRepo.deleteAttendee(attendee!.id!);

      Future.microtask(() async {
        try {
          if (!await _isOnline() || !_isAuthenticated()) return;
          if (attendee?.firestoreId != null) {
            await _cloudRepo.deleteAttendee(attendee!.firestoreId!);
          }
        } catch (_) {}
      });
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to delete attendee: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // READS — always local (instant)
  // ---------------------------------------------------------------------------

  Future<AttendeeModel?> getAttendeeById(String id) async {
    try {
      final localId = int.tryParse(id);
      if (localId != null) return await _localRepo.getAttendeeById(localId);
      return null;
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendee by ID: $e');
    }
  }

  Future<List<AttendeeModel>> getAllAttendees() async {
    try {
      return await _localRepo.getAllAttendees();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get all attendees: $e');
    }
  }

  Future<List<AttendeeModel>> searchAttendees(String query) async {
    try {
      return await _localRepo.searchAttendeesByName(query);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to search attendees: $e');
    }
  }

  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    try {
      return await _localRepo.getAttendeeByPhone(phoneNumber);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendee by phone: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  }) async {
    try {
      return await _localRepo.getAttendeesWithFilters(
        years: years, locations: locations, categories: categories,
      );
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees with filters: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    try {
      return await _localRepo.getAttendeesByYear(yearOfStudy);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees by year: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    try {
      return await _localRepo.getAttendeesByLocation(location);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees by location: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    try {
      return await _localRepo.getAttendeesByCategory(category);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees by category: $e');
    }
  }

  Future<List<String>> getUniqueLocations() async {
    try {
      return await _localRepo.getUniqueLocations();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get unique locations: $e');
    }
  }

  Future<int> getTotalAttendeesCount() async {
    try {
      return await _localRepo.getTotalAttendeesCount();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get total attendees count: $e');
    }
  }

  Future<bool> phoneNumberExists(String phoneNumber) async {
    try {
      return (await getAttendeeByPhone(phoneNumber)) != null;
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to check phone number existence: $e');
    }
  }

  /// Returns a one-shot stream from local DB — no Firestore dependency, never hangs
  Stream<List<AttendeeModel>> attendeesStream() {
    return Stream.fromFuture(_localRepo.getAllAttendees());
  }
}

class HybridAttendeeRepositoryException implements Exception {
  final String message;
  HybridAttendeeRepositoryException(this.message);
  @override
  String toString() => 'HybridAttendeeRepositoryException: $message';
}
