import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/attendee_repository.dart';
import '../repositories/firebase_attendee_repository.dart';
import '../repositories/sync_queue_repository.dart';
import '../models/sync_queue_model.dart';
import '../models/attendee_model.dart';
import '../services/auth_service.dart';

/// Background Sync Service
/// Automatically syncs local database changes to Firebase when online
/// Runs in background without blocking UI
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  final AttendeeRepository _localRepo = AttendeeRepository();
  final FirebaseAttendeeRepository _cloudRepo = FirebaseAttendeeRepository();
  final SyncQueueRepository _syncQueueRepo = SyncQueueRepository();
  final AuthService _authService = AuthService();
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  /// Start background sync service
  void start() {
    print('BackgroundSyncService: Starting...');
    
    // Sync every 30 seconds
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncPendingChanges();
    });

    // Listen to connectivity changes
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // Connected to internet, trigger sync
        print('BackgroundSyncService: Connectivity restored, triggering sync');
        syncPendingChanges();
      }
    });

    // Initial sync after a short delay to ensure database is ready
    // DISABLED: Causing permission errors and blocking UI
    // Future.delayed(const Duration(seconds: 2), () {
    //   print('BackgroundSyncService: Running initial sync');
    //   syncPendingChanges();
    // });
    
    print('BackgroundSyncService: Started successfully (sync disabled due to permissions)');
  }

  /// Stop background sync service
  void stop() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Sync pending changes from queue to Firebase
  Future<void> syncPendingChanges() async {
    if (_isSyncing) return; // Already syncing
    if (!await _isOnline()) return; // Not online
    if (_authService.getCurrentUser() == null) return; // Not authenticated

    _isSyncing = true;

    try {
      // Get pending sync items
      final pendingItems = await _syncQueueRepo.getPendingQueueItems();

      for (final item in pendingItems) {
        try {
          await _processSyncItem(item);
          
          // Mark as completed
          await _syncQueueRepo.updateQueueItemStatus(
            item.id!,
            SyncQueueStatus.completed,
          );
        } catch (e) {
          // Mark as failed
          await _syncQueueRepo.updateQueueItemStatus(
            item.id!,
            SyncQueueStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }
    } catch (e) {
      print('Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Process a single sync item
  Future<void> _processSyncItem(SyncQueueModel item) async {
    if (item.collection != SyncCollection.attendees) return;

    switch (item.operation) {
      case SyncOperation.create:
        await _syncCreate(item);
        break;
      case SyncOperation.update:
        await _syncUpdate(item);
        break;
      case SyncOperation.delete:
        await _syncDelete(item);
        break;
    }
  }

  /// Sync create operation
  Future<void> _syncCreate(SyncQueueModel item) async {
    // Get attendee from local DB
    if (item.documentId == null) return;
    final localId = int.tryParse(item.documentId!);
    if (localId == null) return;

    final attendee = await _localRepo.getAttendeeById(localId);
    if (attendee == null) return;

    // Create in Firebase
    final firestoreId = await _cloudRepo.createAttendee(attendee);

    // Update local record with Firestore ID
    await _localRepo.updateAttendee(
      attendee.copyWith(
        firestoreId: firestoreId,
        isSynced: true,
      ),
    );
  }

  /// Sync update operation
  Future<void> _syncUpdate(SyncQueueModel item) async {
    // Get attendee from local DB
    if (item.documentId == null) return;
    final localId = int.tryParse(item.documentId!);
    if (localId == null) return;

    final attendee = await _localRepo.getAttendeeById(localId);
    if (attendee == null) return;

    // Update in Firebase
    if (attendee.firestoreId != null) {
      await _cloudRepo.updateAttendee(attendee);
      
      // Mark as synced in local DB
      await _localRepo.updateAttendee(
        attendee.copyWith(isSynced: true),
      );
    }
  }

  /// Sync delete operation
  Future<void> _syncDelete(SyncQueueModel item) async {
    // Delete from Firebase
    if (item.documentId != null) {
      await _cloudRepo.deleteAttendee(item.documentId!);
    }
  }

  /// Pull latest data from Firebase to local DB
  Future<void> pullFromCloud() async {
    if (!await _isOnline()) return;
    if (_authService.getCurrentUser() == null) return;

    try {
      // Get all attendees from Firebase
      final cloudAttendees = await _cloudRepo.getAllAttendees();

      // Update local database
      for (final cloudAttendee in cloudAttendees) {
        if (cloudAttendee.firestoreId != null) {
          // Check if exists locally
          final localAttendees = await _localRepo.getAllAttendees();
          final existingLocal = localAttendees.firstWhere(
            (a) => a.firestoreId == cloudAttendee.firestoreId,
            orElse: () => AttendeeModel(
              name: '',
              phoneNumber: '',
              location: '',
              yearOfStudy: '',
              category: AttendeeCategory.student,
            ),
          );

          if (existingLocal.id != null) {
            // Update existing
            await _localRepo.updateAttendee(
              cloudAttendee.copyWith(
                id: existingLocal.id,
                isSynced: true,
              ),
            );
          } else {
            // Create new
            await _localRepo.createAttendee(
              cloudAttendee.copyWith(isSynced: true),
            );
          }
        }
      }
    } catch (e) {
      print('Pull from cloud error: $e');
    }
  }

  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    final pendingCount = await _syncQueueRepo.getPendingCount();
    final isOnline = await _isOnline();
    
    return SyncStatus(
      pendingChanges: pendingCount,
      isOnline: isOnline,
      isSyncing: _isSyncing,
    );
  }
}

/// Sync status model
class SyncStatus {
  final int pendingChanges;
  final bool isOnline;
  final bool isSyncing;

  SyncStatus({
    required this.pendingChanges,
    required this.isOnline,
    required this.isSyncing,
  });

  bool get hasUnsyncedChanges => pendingChanges > 0;
  bool get canSync => isOnline && !isSyncing;
}
