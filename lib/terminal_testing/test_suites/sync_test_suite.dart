import '../core/test_suite.dart';
import '../mocks/mock_environment.dart';
import '../../models/attendee_model.dart';
import '../../models/message_log_model.dart';

/// Test suite for synchronization functionality
/// Tests data synchronization operations and conflict resolution using mock environment
class SyncTestSuite extends TestSuite {
  final MockEnvironment _mockEnv;
  
  SyncTestSuite(this._mockEnv);

  @override
  String get name => 'Synchronization Tests';

  @override
  String get category => 'sync';

  @override
  Future<List<TestResult>> execute() async {
    final results = <TestResult>[];
    
    // Ensure mock environment is set up
    if (!_mockEnv.isInitialized) {
      _mockEnv.setup();
    }

    // Test basic sync operations
    results.add(await _testBasicSyncOperations());
    
    // Test sync status tracking
    results.add(await _testSyncStatusTracking());
    
    // Test version-based conflict resolution
    results.add(await _testVersionBasedConflictResolution());
    
    // Test sync queue management
    results.add(await _testSyncQueueManagement());
    
    // Test offline data handling
    results.add(await _testOfflineDataHandling());
    
    // Test sync error handling
    results.add(await _testSyncErrorHandling());
    
    // Test bulk sync operations
    results.add(await _testBulkSyncOperations());
    
    // Test sync consistency
    results.add(await _testSyncConsistency());

    return results;
  }

  /// Test basic sync operations
  Future<TestResult> _testBasicSyncOperations() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      final mockStorage = _mockEnv.storage;
      
      // Create an attendee with sync status
      final attendee = AttendeeModel(
        name: 'Sync Test Student',
        phoneNumber: '+254712345999',
        yearOfStudy: '1st Year',
        location: 'Test Campus',
        category: AttendeeCategory.student,
        isSynced: false,
        version: 1,
      );
      
      final attendeeId = await mockRepo.createAttendee(attendee);
      
      // Verify attendee is marked as unsynced
      final createdAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (createdAttendee == null) {
        throw Exception('Created attendee not found');
      }
      
      if (createdAttendee.isSynced) {
        throw Exception('New attendee should not be synced initially');
      }
      
      // Simulate sync by updating sync status
      final syncedAttendee = createdAttendee.copyWith(
        isSynced: true,
        firestoreId: 'mock-firestore-id-${DateTime.now().millisecondsSinceEpoch}',
      );
      
      await mockRepo.updateAttendee(syncedAttendee);
      
      // Verify sync status update
      final updatedAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (updatedAttendee == null) {
        throw Exception('Updated attendee not found');
      }
      
      if (!updatedAttendee.isSynced) {
        throw Exception('Attendee sync status not updated');
      }
      
      if (updatedAttendee.firestoreId == null) {
        throw Exception('Firestore ID not set after sync');
      }
      
      // Test sync metadata storage
      await mockStorage.setString('last_sync_time', DateTime.now().toIso8601String());
      await mockStorage.setInt('sync_count', 1);
      
      final lastSyncTime = await mockStorage.getString('last_sync_time');
      final syncCount = await mockStorage.getInt('sync_count');
      
      if (lastSyncTime == null) {
        throw Exception('Last sync time not stored');
      }
      
      if (syncCount != 1) {
        throw Exception('Sync count not stored correctly');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Basic Sync Operations',
        status: TestStatus.pass,
        message: 'Basic sync operations working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Basic Sync Operations',
        status: TestStatus.fail,
        message: 'Basic sync operations test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test sync status tracking
  Future<TestResult> _testSyncStatusTracking() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      final mockStorage = _mockEnv.storage;
      
      // Create multiple attendees with different sync statuses
      final attendees = [
        AttendeeModel(
          name: 'Synced Student',
          phoneNumber: '+254712346001',
          yearOfStudy: '1st Year',
          location: 'Campus A',
          isSynced: true,
          version: 1,
        ),
        AttendeeModel(
          name: 'Unsynced Student',
          phoneNumber: '+254712346002',
          yearOfStudy: '2nd Year',
          location: 'Campus B',
          isSynced: false,
          version: 1,
        ),
      ];
      
      final attendeeIds = <int>[];
      for (final attendee in attendees) {
        final id = await mockRepo.createAttendee(attendee);
        attendeeIds.add(id);
      }
      
      // Get all attendees and check sync status
      final allAttendees = await mockRepo.getAllAttendees();
      
      int syncedCount = 0;
      int unsyncedCount = 0;
      
      for (final attendee in allAttendees) {
        if (attendee.isSynced) {
          syncedCount++;
        } else {
          unsyncedCount++;
        }
      }
      
      if (syncedCount == 0) {
        throw Exception('No synced attendees found');
      }
      
      if (unsyncedCount == 0) {
        throw Exception('No unsynced attendees found');
      }
      
      // Test sync status summary storage
      final syncSummary = {
        'total_attendees': allAttendees.length,
        'synced_count': syncedCount,
        'unsynced_count': unsyncedCount,
        'last_check': DateTime.now().toIso8601String(),
      };
      
      await mockStorage.setJson('sync_summary', syncSummary);
      
      final retrievedSummary = await mockStorage.getJson('sync_summary');
      if (retrievedSummary == null) {
        throw Exception('Sync summary not stored');
      }
      
      if (retrievedSummary['synced_count'] != syncedCount) {
        throw Exception('Synced count mismatch in summary');
      }
      
      if (retrievedSummary['unsynced_count'] != unsyncedCount) {
        throw Exception('Unsynced count mismatch in summary');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Status Tracking',
        status: TestStatus.pass,
        message: 'Sync status tracking working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Status Tracking',
        status: TestStatus.fail,
        message: 'Sync status tracking test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test version-based conflict resolution
  Future<TestResult> _testVersionBasedConflictResolution() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Create an attendee with version 1
      final originalAttendee = AttendeeModel(
        name: 'Conflict Test Student',
        phoneNumber: '+254712346003',
        yearOfStudy: '1st Year',
        location: 'Original Campus',
        version: 1,
      );
      
      final attendeeId = await mockRepo.createAttendee(originalAttendee);
      
      // Simulate local update (version 2)
      final localUpdate = originalAttendee.copyWith(
        id: attendeeId,
        name: 'Local Update Name',
        version: 2,
        lastUpdated: DateTime.now(),
      );
      
      await mockRepo.updateAttendee(localUpdate);
      
      // Simulate cloud update (version 3) - should win
      final cloudUpdate = originalAttendee.copyWith(
        id: attendeeId,
        name: 'Cloud Update Name',
        location: 'Cloud Campus',
        version: 3,
        lastUpdated: DateTime.now().add(const Duration(minutes: 1)),
      );
      
      // In a real sync scenario, we would compare versions and apply the higher version
      if (cloudUpdate.version > localUpdate.version) {
        await mockRepo.updateAttendee(cloudUpdate);
      }
      
      // Verify the cloud update won
      final finalAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (finalAttendee == null) {
        throw Exception('Final attendee not found');
      }
      
      if (finalAttendee.name != 'Cloud Update Name') {
        throw Exception('Conflict resolution failed - wrong name: ${finalAttendee.name}');
      }
      
      if (finalAttendee.version != 3) {
        throw Exception('Conflict resolution failed - wrong version: ${finalAttendee.version}');
      }
      
      if (finalAttendee.location != 'Cloud Campus') {
        throw Exception('Conflict resolution failed - wrong location: ${finalAttendee.location}');
      }
      
      // Test version increment on local changes
      final nextUpdate = finalAttendee.copyWith(
        name: 'Next Update',
        version: finalAttendee.version + 1,
      );
      
      await mockRepo.updateAttendee(nextUpdate);
      
      final versionedAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (versionedAttendee?.version != 4) {
        throw Exception('Version not incremented correctly');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Version-Based Conflict Resolution',
        status: TestStatus.pass,
        message: 'Version-based conflict resolution working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Version-Based Conflict Resolution',
        status: TestStatus.fail,
        message: 'Version-based conflict resolution test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test sync queue management
  Future<TestResult> _testSyncQueueManagement() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Simulate sync queue operations
      final syncQueue = <String>[];
      
      // Add items to sync queue
      syncQueue.add('attendee_create_1');
      syncQueue.add('attendee_update_2');
      syncQueue.add('message_send_3');
      
      await mockStorage.setStringList('sync_queue', syncQueue);
      
      // Retrieve sync queue
      final retrievedQueue = await mockStorage.getStringList('sync_queue');
      if (retrievedQueue == null) {
        throw Exception('Sync queue not stored');
      }
      
      if (retrievedQueue.length != 3) {
        throw Exception('Sync queue length mismatch');
      }
      
      if (!retrievedQueue.contains('attendee_create_1')) {
        throw Exception('Sync queue item missing');
      }
      
      // Process queue items (simulate)
      final processedItems = <String>[];
      for (final item in retrievedQueue) {
        // Simulate processing
        await Future.delayed(const Duration(milliseconds: 10));
        processedItems.add(item);
      }
      
      // Clear processed items from queue
      final remainingQueue = retrievedQueue.where((item) => !processedItems.contains(item)).toList();
      await mockStorage.setStringList('sync_queue', remainingQueue);
      
      final finalQueue = await mockStorage.getStringList('sync_queue');
      if (finalQueue == null || finalQueue.isNotEmpty) {
        throw Exception('Sync queue not cleared after processing');
      }
      
      // Test queue priority handling
      final priorityQueue = <Map<String, dynamic>>[];
      priorityQueue.add({
        'id': 'high_priority_1',
        'priority': 1,
        'timestamp': DateTime.now().toIso8601String(),
      });
      priorityQueue.add({
        'id': 'low_priority_2',
        'priority': 3,
        'timestamp': DateTime.now().toIso8601String(),
      });
      priorityQueue.add({
        'id': 'medium_priority_3',
        'priority': 2,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Sort by priority (lower number = higher priority)
      priorityQueue.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
      
      if (priorityQueue.first['id'] != 'high_priority_1') {
        throw Exception('Priority queue sorting failed');
      }
      
      if (priorityQueue.last['id'] != 'low_priority_2') {
        throw Exception('Priority queue sorting failed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Queue Management',
        status: TestStatus.pass,
        message: 'Sync queue management working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Queue Management',
        status: TestStatus.fail,
        message: 'Sync queue management test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test offline data handling
  Future<TestResult> _testOfflineDataHandling() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      final mockStorage = _mockEnv.storage;
      
      // Simulate offline mode
      await mockStorage.setBool('is_offline', true);
      
      // Create attendee while offline
      final offlineAttendee = AttendeeModel(
        name: 'Offline Student',
        phoneNumber: '+254712346004',
        yearOfStudy: '3rd Year',
        location: 'Offline Campus',
        isSynced: false, // Should be false when created offline
        version: 1,
      );
      
      final attendeeId = await mockRepo.createAttendee(offlineAttendee);
      
      // Verify attendee is marked as unsynced
      final createdAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (createdAttendee == null) {
        throw Exception('Offline attendee not created');
      }
      
      if (createdAttendee.isSynced) {
        throw Exception('Offline attendee should not be synced');
      }
      
      // Store offline changes for later sync
      final offlineChanges = await mockStorage.getStringList('offline_changes') ?? <String>[];
      offlineChanges.add('attendee_create_$attendeeId');
      await mockStorage.setStringList('offline_changes', offlineChanges);
      
      // Simulate going back online
      await mockStorage.setBool('is_offline', false);
      
      // Process offline changes
      final storedChanges = await mockStorage.getStringList('offline_changes');
      if (storedChanges == null || storedChanges.isEmpty) {
        throw Exception('Offline changes not stored');
      }
      
      if (!storedChanges.contains('attendee_create_$attendeeId')) {
        throw Exception('Offline attendee change not recorded');
      }
      
      // Simulate sync of offline changes
      for (final change in storedChanges) {
        if (change.startsWith('attendee_create_')) {
          final id = int.parse(change.split('_').last);
          final attendee = await mockRepo.getAttendeeById(id);
          if (attendee != null) {
            final syncedAttendee = attendee.copyWith(
              isSynced: true,
              firestoreId: 'offline-sync-${DateTime.now().millisecondsSinceEpoch}',
            );
            await mockRepo.updateAttendee(syncedAttendee);
          }
        }
      }
      
      // Clear offline changes after sync
      await mockStorage.setStringList('offline_changes', <String>[]);
      
      // Verify sync completed
      final syncedAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (syncedAttendee == null || !syncedAttendee.isSynced) {
        throw Exception('Offline attendee not synced after going online');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Offline Data Handling',
        status: TestStatus.pass,
        message: 'Offline data handling working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Offline Data Handling',
        status: TestStatus.fail,
        message: 'Offline data handling test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test sync error handling
  Future<TestResult> _testSyncErrorHandling() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Simulate sync errors
      final syncErrors = <Map<String, dynamic>>[];
      
      // Add various types of sync errors
      syncErrors.add({
        'type': 'network_error',
        'message': 'Connection timeout',
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
      
      syncErrors.add({
        'type': 'conflict_error',
        'message': 'Version conflict detected',
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 1,
      });
      
      syncErrors.add({
        'type': 'validation_error',
        'message': 'Invalid data format',
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 3,
      });
      
      // Store sync errors
      await mockStorage.setJson('sync_errors', {'errors': syncErrors});
      
      // Retrieve and validate sync errors
      final storedErrors = await mockStorage.getJson('sync_errors');
      if (storedErrors == null) {
        throw Exception('Sync errors not stored');
      }
      
      final errorsList = storedErrors['errors'] as List<dynamic>;
      if (errorsList.length != 3) {
        throw Exception('Sync errors count mismatch');
      }
      
      // Test error categorization
      int networkErrors = 0;
      int conflictErrors = 0;
      int validationErrors = 0;
      
      for (final error in errorsList) {
        final errorMap = error as Map<String, dynamic>;
        switch (errorMap['type']) {
          case 'network_error':
            networkErrors++;
            break;
          case 'conflict_error':
            conflictErrors++;
            break;
          case 'validation_error':
            validationErrors++;
            break;
        }
      }
      
      if (networkErrors != 1 || conflictErrors != 1 || validationErrors != 1) {
        throw Exception('Error categorization failed');
      }
      
      // Test retry logic
      final retryableErrors = errorsList.where((error) {
        final errorMap = error as Map<String, dynamic>;
        return (errorMap['retry_count'] as int) < 3;
      }).toList();
      
      if (retryableErrors.length != 2) {
        throw Exception('Retry logic filtering failed');
      }
      
      // Test error cleanup (remove old errors)
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      final recentErrors = errorsList.where((error) {
        final errorMap = error as Map<String, dynamic>;
        final timestamp = DateTime.parse(errorMap['timestamp'] as String);
        return timestamp.isAfter(cutoffTime);
      }).toList();
      
      // All our test errors should be recent
      if (recentErrors.length != errorsList.length) {
        throw Exception('Error cleanup logic failed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Error Handling',
        status: TestStatus.pass,
        message: 'Sync error handling working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Error Handling',
        status: TestStatus.fail,
        message: 'Sync error handling test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test bulk sync operations
  Future<TestResult> _testBulkSyncOperations() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      
      // Create multiple attendees for bulk operations
      final bulkAttendees = <AttendeeModel>[];
      for (int i = 0; i < 5; i++) {
        bulkAttendees.add(AttendeeModel(
          name: 'Bulk Student $i',
          phoneNumber: '+25471234${6005 + i}',
          yearOfStudy: '${(i % 4) + 1}st Year',
          location: 'Bulk Campus ${i % 2}',
          category: i % 2 == 0 ? AttendeeCategory.student : AttendeeCategory.visitor,
          isSynced: false,
          version: 1,
        ));
      }
      
      // Test bulk insert
      final insertedIds = await mockRepo.bulkInsertAttendees(bulkAttendees);
      
      if (insertedIds.length != bulkAttendees.length) {
        throw Exception('Bulk insert count mismatch: expected ${bulkAttendees.length}, got ${insertedIds.length}');
      }
      
      // Verify all attendees were inserted
      for (final id in insertedIds) {
        final attendee = await mockRepo.getAttendeeById(id);
        if (attendee == null) {
          throw Exception('Bulk inserted attendee not found: $id');
        }
        
        if (attendee.isSynced) {
          throw Exception('Bulk inserted attendee should not be synced initially');
        }
      }
      
      // Test bulk sync status update
      for (final id in insertedIds) {
        final attendee = await mockRepo.getAttendeeById(id);
        if (attendee != null) {
          final syncedAttendee = attendee.copyWith(
            isSynced: true,
            firestoreId: 'bulk-sync-$id',
            version: attendee.version + 1,
          );
          await mockRepo.updateAttendee(syncedAttendee);
        }
      }
      
      // Verify bulk sync
      int syncedCount = 0;
      for (final id in insertedIds) {
        final attendee = await mockRepo.getAttendeeById(id);
        if (attendee != null && attendee.isSynced) {
          syncedCount++;
        }
      }
      
      if (syncedCount != insertedIds.length) {
        throw Exception('Bulk sync failed: only $syncedCount of ${insertedIds.length} synced');
      }
      
      // Test bulk statistics
      final stats = await mockRepo.getAttendanceStatistics();
      if (stats['totalAttendees'] == null || (stats['totalAttendees'] as int) < insertedIds.length) {
        throw Exception('Bulk operations not reflected in statistics');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Bulk Sync Operations',
        status: TestStatus.pass,
        message: 'Bulk sync operations working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Bulk Sync Operations',
        status: TestStatus.fail,
        message: 'Bulk sync operations test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test sync consistency
  Future<TestResult> _testSyncConsistency() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockRepo = _mockEnv.attendanceRepo;
      final mockStorage = _mockEnv.storage;
      
      // Create attendee with metadata
      final attendee = AttendeeModel(
        name: 'Consistency Test Student',
        phoneNumber: '+254712346010',
        yearOfStudy: '4th Year',
        location: 'Consistency Campus',
        createdBy: 'test-user-uid',
        createdAt: DateTime.now(),
        modifiedBy: 'test-user-uid',
        modifiedAt: DateTime.now(),
        isSynced: false,
        version: 1,
      );
      
      final attendeeId = await mockRepo.createAttendee(attendee);
      
      // Test metadata consistency
      final createdAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (createdAttendee == null) {
        throw Exception('Created attendee not found');
      }
      
      if (createdAttendee.createdBy != 'test-user-uid') {
        throw Exception('Created by metadata inconsistent');
      }
      
      if (createdAttendee.createdAt == null) {
        throw Exception('Created at timestamp missing');
      }
      
      // Test update metadata consistency
      final updatedAttendee = createdAttendee.copyWith(
        name: 'Updated Consistency Student',
        modifiedBy: 'different-user-uid',
        modifiedAt: DateTime.now().add(const Duration(minutes: 1)),
        version: createdAttendee.version + 1,
      );
      
      await mockRepo.updateAttendee(updatedAttendee);
      
      final finalAttendee = await mockRepo.getAttendeeById(attendeeId);
      if (finalAttendee == null) {
        throw Exception('Updated attendee not found');
      }
      
      if (finalAttendee.modifiedBy != 'different-user-uid') {
        throw Exception('Modified by metadata inconsistent');
      }
      
      if (finalAttendee.version != 2) {
        throw Exception('Version not incremented consistently');
      }
      
      // Original creation metadata should be preserved
      if (finalAttendee.createdBy != 'test-user-uid') {
        throw Exception('Original creation metadata not preserved');
      }
      
      // Test sync timestamp consistency
      await mockStorage.setString('last_full_sync', DateTime.now().toIso8601String());
      await mockStorage.setString('last_incremental_sync', DateTime.now().toIso8601String());
      
      final fullSyncTime = await mockStorage.getString('last_full_sync');
      final incrementalSyncTime = await mockStorage.getString('last_incremental_sync');
      
      if (fullSyncTime == null || incrementalSyncTime == null) {
        throw Exception('Sync timestamps not stored consistently');
      }
      
      final fullSync = DateTime.parse(fullSyncTime);
      final incrementalSync = DateTime.parse(incrementalSyncTime);
      
      // Incremental sync should be same or after full sync
      if (incrementalSync.isBefore(fullSync)) {
        throw Exception('Sync timestamp consistency violated');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Consistency',
        status: TestStatus.pass,
        message: 'Sync consistency working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Sync Consistency',
        status: TestStatus.fail,
        message: 'Sync consistency test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }
}