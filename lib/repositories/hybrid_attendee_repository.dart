import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/attendee_model.dart';
import '../models/sync_queue_model.dart';
import 'attendee_repository.dart';
import 'firebase_attendee_repository.dart';
import 'sync_queue_repository.dart';
import '../services/auth_service.dart';

/// Hybrid Attendee Repository
/// Provides seamless offline/online data access by routing operations
/// to cloud when online and local database when offline
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

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is authenticated
  bool _isAuthenticated() {
    return _authService.getCurrentUser() != null;
  }

  /// Create attendee - routes to cloud when online, local when offline
  Future<String> createAttendee(AttendeeModel attendee) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Create in cloud and local
        try {
          final currentUser = _authService.getCurrentUser()!;
          
          // Add cloud-specific fields
          final attendeeWithCloudFields = attendee.copyWith(
            createdBy: currentUser.uid,
            createdAt: DateTime.now(),
            modifiedBy: currentUser.uid,
            modifiedAt: DateTime.now(),
            isSynced: true,
            version: 1,
          );

          // Create in Firestore
          final firestoreId = await _cloudRepo.createAttendee(attendeeWithCloudFields);

          // Create in local database with Firestore ID
          final localId = await _localRepo.createAttendee(
            attendeeWithCloudFields.copyWith(firestoreId: firestoreId),
          );

          return firestoreId;
        } catch (e) {
          // If cloud creation fails, fall back to offline mode
          return await _createAttendeeOffline(attendee);
        }
      } else {
        // Offline: Create locally and queue for sync
        return await _createAttendeeOffline(attendee);
      }
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to create attendee: $e');
    }
  }

  /// Create attendee offline and queue for sync
  Future<String> _createAttendeeOffline(AttendeeModel attendee) async {
    try {
      // Mark as not synced
      final attendeeToCreate = attendee.copyWith(
        isSynced: false,
        version: 1,
      );

      // Create in local database
      final localId = await _localRepo.createAttendee(attendeeToCreate);

      // Queue for sync when online
      await _syncQueueRepo.addToQueue(SyncQueueModel(
        userId: _authService.getCurrentUser()!.uid,
        operation: SyncOperation.create,
        collection: SyncCollection.attendees,
        documentId: localId.toString(),
        data: attendeeToCreate.toMap(),
        createdAt: DateTime.now(),
        status: SyncQueueStatus.pending,
      ));

      return localId.toString();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to create attendee offline: $e');
    }
  }

  /// Get attendee by ID - prefers cloud when online, falls back to local
  Future<AttendeeModel?> getAttendeeById(String id) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          final cloudAttendee = await _cloudRepo.getAttendeeById(id);
          
          if (cloudAttendee != null) {
            // Update local cache
            if (cloudAttendee.id != null) {
              final localAttendee = await _localRepo.getAttendeeById(cloudAttendee.id!);
              if (localAttendee != null) {
                await _localRepo.updateAttendee(cloudAttendee.copyWith(isSynced: true));
              }
            }
            return cloudAttendee;
          }
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      final localId = int.tryParse(id);
      if (localId != null) {
        return await _localRepo.getAttendeeById(localId);
      }

      return null;
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendee by ID: $e');
    }
  }

  /// Get all attendees - prefers cloud when online, falls back to local
  Future<List<AttendeeModel>> getAllAttendees() async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          final cloudAttendees = await _cloudRepo.getAllAttendees();
          
          // Update local cache with cloud data
          for (final cloudAttendee in cloudAttendees) {
            if (cloudAttendee.id != null) {
              final localAttendee = await _localRepo.getAttendeeById(cloudAttendee.id!);
              if (localAttendee != null) {
                await _localRepo.updateAttendee(cloudAttendee.copyWith(isSynced: true));
              } else {
                await _localRepo.createAttendee(cloudAttendee.copyWith(isSynced: true));
              }
            }
          }
          
          return cloudAttendees;
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAllAttendees();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get all attendees: $e');
    }
  }

  /// Update attendee - routes to cloud when online, local when offline
  Future<void> updateAttendee(AttendeeModel attendee) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Update in cloud and local
        try {
          final currentUser = _authService.getCurrentUser()!;
          
          // Add cloud-specific fields
          final attendeeWithCloudFields = attendee.copyWith(
            modifiedBy: currentUser.uid,
            modifiedAt: DateTime.now(),
            isSynced: true,
            version: attendee.version + 1,
          );

          // Update in Firestore if it has a Firestore ID
          if (attendeeWithCloudFields.firestoreId != null) {
            await _cloudRepo.updateAttendee(attendeeWithCloudFields);
          }

          // Update in local database
          if (attendeeWithCloudFields.id != null) {
            await _localRepo.updateAttendee(attendeeWithCloudFields);
          }
        } catch (e) {
          // If cloud update fails, fall back to offline mode
          await _updateAttendeeOffline(attendee);
        }
      } else {
        // Offline: Update locally and queue for sync
        await _updateAttendeeOffline(attendee);
      }
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to update attendee: $e');
    }
  }

  /// Update attendee offline and queue for sync
  Future<void> _updateAttendeeOffline(AttendeeModel attendee) async {
    try {
      if (attendee.id == null) {
        throw HybridAttendeeRepositoryException('Cannot update attendee without ID');
      }

      // Mark as not synced and increment version
      final attendeeToUpdate = attendee.copyWith(
        isSynced: false,
        version: attendee.version + 1,
        lastUpdated: DateTime.now(),
      );

      // Update in local database
      await _localRepo.updateAttendee(attendeeToUpdate);

      // Queue for sync when online
      await _syncQueueRepo.addToQueue(SyncQueueModel(
        userId: _authService.getCurrentUser()!.uid,
        operation: SyncOperation.update,
        collection: SyncCollection.attendees,
        documentId: attendee.firestoreId ?? attendee.id.toString(),
        data: attendeeToUpdate.toMap(),
        createdAt: DateTime.now(),
        status: SyncQueueStatus.pending,
      ));
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to update attendee offline: $e');
    }
  }

  /// Delete attendee - routes to cloud when online, local when offline
  Future<void> deleteAttendee(String id) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Online: Delete from cloud and local
        try {
          // Get attendee to find both IDs
          final attendee = await getAttendeeById(id);
          
          if (attendee != null) {
            // Delete from Firestore if it has a Firestore ID
            if (attendee.firestoreId != null) {
              await _cloudRepo.deleteAttendee(attendee.firestoreId!);
            }

            // Delete from local database
            if (attendee.id != null) {
              await _localRepo.deleteAttendee(attendee.id!);
            }
          }
        } catch (e) {
          // If cloud delete fails, fall back to offline mode
          await _deleteAttendeeOffline(id);
        }
      } else {
        // Offline: Delete locally and queue for sync
        await _deleteAttendeeOffline(id);
      }
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to delete attendee: $e');
    }
  }

  /// Delete attendee offline and queue for sync
  Future<void> _deleteAttendeeOffline(String id) async {
    try {
      // Get attendee before deleting
      final attendee = await getAttendeeById(id);
      
      if (attendee == null) {
        throw HybridAttendeeRepositoryException('Attendee not found for deletion');
      }

      // Delete from local database
      if (attendee.id != null) {
        await _localRepo.deleteAttendee(attendee.id!);
      }

      // Queue for sync when online (if it has a Firestore ID)
      if (attendee.firestoreId != null) {
        await _syncQueueRepo.addToQueue(SyncQueueModel(
          userId: _authService.getCurrentUser()!.uid,
          operation: SyncOperation.delete,
          collection: SyncCollection.attendees,
          documentId: attendee.firestoreId!,
          data: {},
          createdAt: DateTime.now(),
          status: SyncQueueStatus.pending,
        ));
      }
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to delete attendee offline: $e');
    }
  }

  /// Search attendees - prefers cloud when online, falls back to local
  Future<List<AttendeeModel>> searchAttendees(String query) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to search in cloud first
        try {
          return await _cloudRepo.searchAttendees(query);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Search in local database
      return await _localRepo.searchAttendeesByName(query);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to search attendees: $e');
    }
  }

  /// Get attendee by phone - prefers cloud when online, falls back to local
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getAttendeeByPhone(phoneNumber);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAttendeeByPhone(phoneNumber);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendee by phone: $e');
    }
  }

  /// Get attendees with filters - prefers cloud when online, falls back to local
  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  }) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getAttendeesWithFilters(
            years: years,
            locations: locations,
            categories: categories,
          );
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAttendeesWithFilters(
        years: years,
        locations: locations,
        categories: categories,
      );
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees with filters: $e');
    }
  }

  /// Get attendees by year - prefers cloud when online, falls back to local
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getAttendeesByYear(yearOfStudy);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAttendeesByYear(yearOfStudy);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees by year: $e');
    }
  }

  /// Get attendees by location - prefers cloud when online, falls back to local
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getAttendeesByLocation(location);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAttendeesByLocation(location);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees by location: $e');
    }
  }

  /// Get attendees by category - prefers cloud when online, falls back to local
  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getAttendeesByCategory(category);
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getAttendeesByCategory(category);
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get attendees by category: $e');
    }
  }

  /// Get unique locations - prefers cloud when online, falls back to local
  Future<List<String>> getUniqueLocations() async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getUniqueLocations();
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getUniqueLocations();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get unique locations: $e');
    }
  }

  /// Get total attendees count - prefers cloud when online, falls back to local
  Future<int> getTotalAttendeesCount() async {
    try {
      final isOnline = await _isOnline();
      final isAuthenticated = _isAuthenticated();

      if (isOnline && isAuthenticated) {
        // Try to get from cloud first
        try {
          return await _cloudRepo.getTotalAttendeesCount();
        } catch (e) {
          // Fall back to local if cloud fails
        }
      }

      // Get from local database
      return await _localRepo.getTotalAttendeesCount();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to get total attendees count: $e');
    }
  }

  /// Listen to attendee changes (real-time) - only works when online
  Stream<List<AttendeeModel>> attendeesStream() {
    try {
      return _cloudRepo.attendeesStream();
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to create attendees stream: $e');
    }
  }

  /// Check if phone number exists - prefers cloud when online, falls back to local
  Future<bool> phoneNumberExists(String phoneNumber) async {
    try {
      final attendee = await getAttendeeByPhone(phoneNumber);
      return attendee != null;
    } catch (e) {
      throw HybridAttendeeRepositoryException('Failed to check phone number existence: $e');
    }
  }
}

/// Custom exception for hybrid attendee repository operations
class HybridAttendeeRepositoryException implements Exception {
  final String message;

  HybridAttendeeRepositoryException(this.message);

  @override
  String toString() => 'HybridAttendeeRepositoryException: $message';
}