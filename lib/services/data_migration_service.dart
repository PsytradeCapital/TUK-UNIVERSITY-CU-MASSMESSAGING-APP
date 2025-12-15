import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import '../models/service_model.dart';
import '../repositories/attendee_repository.dart';
import '../repositories/message_log_repository.dart';
import '../repositories/service_repository.dart';
import '../repositories/firebase_attendee_repository.dart';
import '../repositories/firebase_message_log_repository.dart';
import '../services/encryption_service.dart';
import '../services/auth_service.dart';

class DataMigrationService {
  final AttendeeRepository _localAttendeeRepo = AttendeeRepository();
  final MessageLogRepository _localMessageRepo = MessageLogRepository();
  final ServiceRepository _localServiceRepo = ServiceRepository();
  final FirebaseAttendeeRepository _firebaseAttendeeRepo = FirebaseAttendeeRepository();
  final FirebaseMessageLogRepository _firebaseMessageRepo = FirebaseMessageLogRepository();
  final AuthService _authService = AuthService();

  // Export existing SQLite data to JSON
  Future<String> exportLocalDataToJson() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataMigrationException('User must be authenticated to export data');
      }

      // Get all local data
      final attendees = await _localAttendeeRepo.getAllAttendees();
      final messageLogs = await _localMessageRepo.getAllMessageLogs();
      final services = await _localServiceRepo.getAllServices();

      // Transform data for Firestore format
      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': user.uid,
        'version': '1.0',
        'attendees': await _transformAttendeesForFirestore(attendees, user.uid),
        'messageLogs': await _transformMessageLogsForFirestore(messageLogs, user.uid),
        'services': await _transformServicesForFirestore(services, user.uid),
      };

      // Create export directory
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'data_export_$timestamp.json';
      final filePath = '${exportDir.path}/$filename';

      // Write JSON to file
      final file = File(filePath);
      await file.writeAsString(json.encode(exportData));

      return filePath;
    } catch (e) {
      throw DataMigrationException('Failed to export local data: $e');
    }
  }

  // Transform attendees for Firestore format
  Future<List<Map<String, dynamic>>> _transformAttendeesForFirestore(
    List<AttendeeModel> attendees, 
    String userId,
  ) async {
    final transformedAttendees = <Map<String, dynamic>>[];

    for (final attendee in attendees) {
      final now = DateTime.now();
      
      // Create Firestore-compatible attendee data
      final firestoreData = {
        'name': attendee.name,
        'phoneNumber': attendee.phoneNumber,
        'yearOfStudy': attendee.yearOfStudy,
        'location': attendee.location,
        'category': AttendeeModel.categoryToString(attendee.category),
        'attendanceCount': attendee.attendanceCount,
        'firstRegistered': attendee.firstRegistered.toIso8601String(),
        'lastUpdated': attendee.lastUpdated.toIso8601String(),
        
        // Add cloud-specific fields
        'createdBy': userId,
        'createdAt': attendee.createdAt?.toIso8601String() ?? now.toIso8601String(),
        'modifiedBy': userId,
        'modifiedAt': now.toIso8601String(),
        'version': attendee.version,
        
        // Migration metadata
        'migratedFrom': 'sqlite',
        'originalId': attendee.id,
        'migratedAt': now.toIso8601String(),
      };

      transformedAttendees.add(firestoreData);
    }

    return transformedAttendees;
  }

  // Transform message logs for Firestore format
  Future<List<Map<String, dynamic>>> _transformMessageLogsForFirestore(
    List<MessageLogModel> messageLogs, 
    String userId,
  ) async {
    final transformedLogs = <Map<String, dynamic>>[];

    for (final messageLog in messageLogs) {
      final now = DateTime.now();
      
      // Create Firestore-compatible message log data
      final firestoreData = {
        'serviceId': messageLog.serviceId,
        'attendeeId': messageLog.attendeeId,
        'messageText': messageLog.messageText,
        'sendStatus': MessageLogModel.statusToString(messageLog.sendStatus),
        'sentAt': messageLog.sentAt?.toIso8601String(),
        'errorMessage': messageLog.errorMessage,
        'createdAt': messageLog.createdAt.toIso8601String(),
        
        // Add cloud-specific fields
        'sentBy': userId,
        'cloudCreatedAt': messageLog.cloudCreatedAt?.toIso8601String() ?? now.toIso8601String(),
        'version': messageLog.version,
        
        // Migration metadata
        'migratedFrom': 'sqlite',
        'originalMessageId': messageLog.messageId,
        'migratedAt': now.toIso8601String(),
      };

      transformedLogs.add(firestoreData);
    }

    return transformedLogs;
  }

  // Transform services for Firestore format
  Future<List<Map<String, dynamic>>> _transformServicesForFirestore(
    List<ServiceModel> services, 
    String userId,
  ) async {
    final transformedServices = <Map<String, dynamic>>[];

    for (final service in services) {
      final now = DateTime.now();
      
      // Create Firestore-compatible service data
      final firestoreData = {
        'serviceDate': service.serviceDate.toIso8601String(),
        'totalAttendees': service.totalAttendees,
        'messageSent': service.messageSent,
        'messageText': service.messageText,
        'createdAt': service.createdAt.toIso8601String(),
        
        // Add cloud-specific fields
        'createdBy': userId,
        'version': 1,
        
        // Migration metadata
        'migratedFrom': 'sqlite',
        'originalServiceId': service.serviceId,
        'migratedAt': now.toIso8601String(),
        
        // Include attendee IDs for this service
        'attendeeIds': service.attendees.map((a) => a.id).where((id) => id != null).toList(),
      };

      transformedServices.add(firestoreData);
    }

    return transformedServices;
  }

  // Import JSON data to Firestore
  Future<MigrationResult> importDataToFirestore(String jsonFilePath) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataMigrationException('User must be authenticated to import data');
      }

      // Read and parse JSON file
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        throw DataMigrationException('Import file does not exist: $jsonFilePath');
      }

      final jsonString = await file.readAsString();
      final Map<String, dynamic> importData = json.decode(jsonString);

      // Validate import data structure
      _validateImportData(importData);

      final result = MigrationResult();
      final batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      const maxBatchSize = 500; // Firestore batch limit

      try {
        // Import attendees
        final attendeesData = importData['attendees'] as List<dynamic>;
        for (final attendeeData in attendeesData) {
          final docRef = FirebaseFirestore.instance.collection('attendees').doc();
          batch.set(docRef, attendeeData);
          batchCount++;
          result.attendeesImported++;

          // Commit batch if approaching limit
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
          }
        }

        // Import message logs
        final messageLogsData = importData['messageLogs'] as List<dynamic>;
        for (final messageLogData in messageLogsData) {
          final docRef = FirebaseFirestore.instance.collection('messageLogs').doc();
          batch.set(docRef, messageLogData);
          batchCount++;
          result.messageLogsImported++;

          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
          }
        }

        // Import services
        final servicesData = importData['services'] as List<dynamic>;
        for (final serviceData in servicesData) {
          final docRef = FirebaseFirestore.instance.collection('services').doc();
          batch.set(docRef, serviceData);
          batchCount++;
          result.servicesImported++;

          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
          }
        }

        // Commit remaining batch
        if (batchCount > 0) {
          await batch.commit();
        }

        result.success = true;
        result.importedAt = DateTime.now();

        // Verify data integrity after import
        await _verifyDataIntegrity(result);

        return result;
      } catch (e) {
        result.success = false;
        result.errorMessage = 'Failed during batch import: $e';
        throw DataMigrationException(result.errorMessage!);
      }
    } catch (e) {
      throw DataMigrationException('Failed to import data to Firestore: $e');
    }
  }

  // Validate import data structure
  void _validateImportData(Map<String, dynamic> importData) {
    final requiredFields = ['exportedAt', 'exportedBy', 'version', 'attendees', 'messageLogs', 'services'];
    
    for (final field in requiredFields) {
      if (!importData.containsKey(field)) {
        throw DataMigrationException('Invalid import data: missing field $field');
      }
    }

    // Validate data types
    if (importData['attendees'] is! List) {
      throw DataMigrationException('Invalid import data: attendees must be a list');
    }
    
    if (importData['messageLogs'] is! List) {
      throw DataMigrationException('Invalid import data: messageLogs must be a list');
    }
    
    if (importData['services'] is! List) {
      throw DataMigrationException('Invalid import data: services must be a list');
    }
  }

  // Verify data integrity after import
  Future<void> _verifyDataIntegrity(MigrationResult result) async {
    try {
      // Count documents in Firestore collections
      final attendeesSnapshot = await FirebaseFirestore.instance.collection('attendees').get();
      final messageLogsSnapshot = await FirebaseFirestore.instance.collection('messageLogs').get();
      final servicesSnapshot = await FirebaseFirestore.instance.collection('services').get();

      result.verificationResults = {
        'attendeesInFirestore': attendeesSnapshot.docs.length,
        'messageLogsInFirestore': messageLogsSnapshot.docs.length,
        'servicesInFirestore': servicesSnapshot.docs.length,
        'attendeesImported': result.attendeesImported,
        'messageLogsImported': result.messageLogsImported,
        'servicesImported': result.servicesImported,
      };

      // Check for data consistency
      if (attendeesSnapshot.docs.length < result.attendeesImported) {
        result.warnings.add('Some attendees may not have been imported correctly');
      }
      
      if (messageLogsSnapshot.docs.length < result.messageLogsImported) {
        result.warnings.add('Some message logs may not have been imported correctly');
      }
      
      if (servicesSnapshot.docs.length < result.servicesImported) {
        result.warnings.add('Some services may not have been imported correctly');
      }
    } catch (e) {
      result.warnings.add('Failed to verify data integrity: $e');
    }
  }

  // Export Firestore data to encrypted JSON
  Future<String> exportFirestoreData() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataMigrationException('User must be authenticated to export Firestore data');
      }

      // Get all Firestore data
      final attendeesSnapshot = await FirebaseFirestore.instance.collection('attendees').get();
      final messageLogsSnapshot = await FirebaseFirestore.instance.collection('messageLogs').get();
      final servicesSnapshot = await FirebaseFirestore.instance.collection('services').get();

      // Prepare export data
      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': user.uid,
        'version': '1.0',
        'source': 'firestore',
        'attendees': attendeesSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'messageLogs': messageLogsSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'services': servicesSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
      };

      // Encrypt the data
      final jsonString = json.encode(exportData);
      final encryptedData = await EncryptionService.encryptData(jsonString);

      // Create export directory
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'firestore_backup_$timestamp.encrypted';
      final filePath = '${exportDir.path}/$filename';

      // Write encrypted data to file
      final file = File(filePath);
      await file.writeAsString(encryptedData);

      return filePath;
    } catch (e) {
      throw DataMigrationException('Failed to export Firestore data: $e');
    }
  }

  // Store backup in Firebase Storage
  Future<String> storeBackupInFirebaseStorage(String localFilePath) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataMigrationException('User must be authenticated to store backup');
      }

      final file = File(localFilePath);
      if (!await file.exists()) {
        throw DataMigrationException('Backup file does not exist: $localFilePath');
      }

      // Generate storage path
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'backup_${user.uid}_$timestamp.encrypted';
      final storagePath = 'backups/$fileName';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = storageRef.putFile(file);
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw DataMigrationException('Failed to store backup in Firebase Storage: $e');
    }
  }

  // Get migration status
  Future<MigrationStatus> getMigrationStatus() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        return MigrationStatus(
          isAuthenticated: false,
          localDataExists: false,
          cloudDataExists: false,
        );
      }

      // Check local data
      final localAttendees = await _localAttendeeRepo.getTotalAttendeesCount();
      final localMessages = await _localMessageRepo.getTotalMessageLogsCount();
      final localServices = await _localServiceRepo.getTotalServicesCount();

      // Check cloud data
      final attendeesSnapshot = await FirebaseFirestore.instance
          .collection('attendees')
          .where('createdBy', isEqualTo: user.uid)
          .limit(1)
          .get();
      
      final messageLogsSnapshot = await FirebaseFirestore.instance
          .collection('messageLogs')
          .where('sentBy', isEqualTo: user.uid)
          .limit(1)
          .get();

      return MigrationStatus(
        isAuthenticated: true,
        localDataExists: localAttendees > 0 || localMessages > 0 || localServices > 0,
        cloudDataExists: attendeesSnapshot.docs.isNotEmpty || messageLogsSnapshot.docs.isNotEmpty,
        localAttendeesCount: localAttendees,
        localMessageLogsCount: localMessages,
        localServicesCount: localServices,
        cloudAttendeesCount: attendeesSnapshot.docs.length,
        cloudMessageLogsCount: messageLogsSnapshot.docs.length,
      );
    } catch (e) {
      throw DataMigrationException('Failed to get migration status: $e');
    }
  }
}

// Migration result class
class MigrationResult {
  bool success = false;
  int attendeesImported = 0;
  int messageLogsImported = 0;
  int servicesImported = 0;
  DateTime? importedAt;
  String? errorMessage;
  List<String> warnings = [];
  Map<String, dynamic>? verificationResults;
}

// Migration status class
class MigrationStatus {
  final bool isAuthenticated;
  final bool localDataExists;
  final bool cloudDataExists;
  final int localAttendeesCount;
  final int localMessageLogsCount;
  final int localServicesCount;
  final int cloudAttendeesCount;
  final int cloudMessageLogsCount;

  MigrationStatus({
    required this.isAuthenticated,
    required this.localDataExists,
    required this.cloudDataExists,
    this.localAttendeesCount = 0,
    this.localMessageLogsCount = 0,
    this.localServicesCount = 0,
    this.cloudAttendeesCount = 0,
    this.cloudMessageLogsCount = 0,
  });
}

// Custom exception for data migration operations
class DataMigrationException implements Exception {
  final String message;
  
  DataMigrationException(this.message);
  
  @override
  String toString() => 'DataMigrationException: $message';
}