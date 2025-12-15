import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import '../models/service_model.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';

class DataImportService {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Import data from JSON file with batch processing
  Future<ImportResult> importFromJson(String jsonFilePath) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataImportException('User must be authenticated to import data');
      }

      // Read and validate JSON file
      final importData = await _readAndValidateJsonFile(jsonFilePath);
      
      final result = ImportResult();
      result.startedAt = DateTime.now();

      // Process import in batches to avoid Firestore limits
      await _processBatchImport(importData, user.uid, result);

      result.completedAt = DateTime.now();
      result.success = result.errors.isEmpty;

      // Verify data integrity after import
      if (result.success) {
        await _verifyImportIntegrity(result);
      }

      return result;
    } catch (e) {
      throw DataImportException('Failed to import data: $e');
    }
  }

  // Read and validate JSON file
  Future<Map<String, dynamic>> _readAndValidateJsonFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw DataImportException('Import file does not exist: $filePath');
    }

    try {
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = json.decode(jsonString);
      
      _validateImportDataStructure(data);
      return data;
    } catch (e) {
      throw DataImportException('Failed to read or parse JSON file: $e');
    }
  }

  // Validate import data structure
  void _validateImportDataStructure(Map<String, dynamic> data) {
    final requiredFields = ['exportedAt', 'exportedBy', 'version'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        throw DataImportException('Invalid import data: missing required field "$field"');
      }
    }

    // Check for at least one data collection
    final hasAttendees = data.containsKey('attendees') && data['attendees'] is List;
    final hasMessageLogs = data.containsKey('messageLogs') && data['messageLogs'] is List;
    final hasServices = data.containsKey('services') && data['services'] is List;

    if (!hasAttendees && !hasMessageLogs && !hasServices) {
      throw DataImportException('Import data must contain at least one data collection (attendees, messageLogs, or services)');
    }

    // Validate version compatibility
    final version = data['version'] as String?;
    if (version == null || !_isVersionCompatible(version)) {
      throw DataImportException('Incompatible data version: $version');
    }
  }

  // Check version compatibility
  bool _isVersionCompatible(String version) {
    // For now, accept version 1.0 and 1.x
    return version.startsWith('1.');
  }

  // Process batch import with error handling
  Future<void> _processBatchImport(
    Map<String, dynamic> importData, 
    String userId, 
    ImportResult result,
  ) async {
    const int batchSize = 500; // Firestore batch limit
    
    try {
      // Import attendees
      if (importData.containsKey('attendees')) {
        final attendeesData = importData['attendees'] as List<dynamic>;
        await _importAttendeesInBatches(attendeesData, userId, result, batchSize);
      }

      // Import message logs
      if (importData.containsKey('messageLogs')) {
        final messageLogsData = importData['messageLogs'] as List<dynamic>;
        await _importMessageLogsInBatches(messageLogsData, userId, result, batchSize);
      }

      // Import services
      if (importData.containsKey('services')) {
        final servicesData = importData['services'] as List<dynamic>;
        await _importServicesInBatches(servicesData, userId, result, batchSize);
      }
    } catch (e) {
      result.errors.add('Batch import failed: $e');
      throw DataImportException('Batch import failed: $e');
    }
  }

  // Import attendees in batches
  Future<void> _importAttendeesInBatches(
    List<dynamic> attendeesData, 
    String userId, 
    ImportResult result, 
    int batchSize,
  ) async {
    for (int i = 0; i < attendeesData.length; i += batchSize) {
      final batch = _firestore.batch();
      final endIndex = (i + batchSize < attendeesData.length) ? i + batchSize : attendeesData.length;
      
      for (int j = i; j < endIndex; j++) {
        try {
          final attendeeData = attendeesData[j] as Map<String, dynamic>;
          
          // Validate and sanitize attendee data
          final sanitizedData = await _sanitizeAttendeeData(attendeeData, userId);
          
          // Create document reference
          final docRef = _firestore.collection('attendees').doc();
          batch.set(docRef, sanitizedData);
          
          result.attendeesProcessed++;
        } catch (e) {
          result.errors.add('Failed to process attendee at index $j: $e');
          result.attendeeErrors++;
        }
      }

      try {
        await batch.commit();
        result.attendeesImported += (endIndex - i - result.attendeeErrors);
      } catch (e) {
        result.errors.add('Failed to commit attendees batch ${i ~/ batchSize + 1}: $e');
      }
    }
  }

  // Import message logs in batches
  Future<void> _importMessageLogsInBatches(
    List<dynamic> messageLogsData, 
    String userId, 
    ImportResult result, 
    int batchSize,
  ) async {
    for (int i = 0; i < messageLogsData.length; i += batchSize) {
      final batch = _firestore.batch();
      final endIndex = (i + batchSize < messageLogsData.length) ? i + batchSize : messageLogsData.length;
      
      for (int j = i; j < endIndex; j++) {
        try {
          final messageLogData = messageLogsData[j] as Map<String, dynamic>;
          
          // Validate and sanitize message log data
          final sanitizedData = await _sanitizeMessageLogData(messageLogData, userId);
          
          // Create document reference
          final docRef = _firestore.collection('messageLogs').doc();
          batch.set(docRef, sanitizedData);
          
          result.messageLogsProcessed++;
        } catch (e) {
          result.errors.add('Failed to process message log at index $j: $e');
          result.messageLogErrors++;
        }
      }

      try {
        await batch.commit();
        result.messageLogsImported += (endIndex - i - result.messageLogErrors);
      } catch (e) {
        result.errors.add('Failed to commit message logs batch ${i ~/ batchSize + 1}: $e');
      }
    }
  }

  // Import services in batches
  Future<void> _importServicesInBatches(
    List<dynamic> servicesData, 
    String userId, 
    ImportResult result, 
    int batchSize,
  ) async {
    for (int i = 0; i < servicesData.length; i += batchSize) {
      final batch = _firestore.batch();
      final endIndex = (i + batchSize < servicesData.length) ? i + batchSize : servicesData.length;
      
      for (int j = i; j < endIndex; j++) {
        try {
          final serviceData = servicesData[j] as Map<String, dynamic>;
          
          // Validate and sanitize service data
          final sanitizedData = await _sanitizeServiceData(serviceData, userId);
          
          // Create document reference
          final docRef = _firestore.collection('services').doc();
          batch.set(docRef, sanitizedData);
          
          result.servicesProcessed++;
        } catch (e) {
          result.errors.add('Failed to process service at index $j: $e');
          result.serviceErrors++;
        }
      }

      try {
        await batch.commit();
        result.servicesImported += (endIndex - i - result.serviceErrors);
      } catch (e) {
        result.errors.add('Failed to commit services batch ${i ~/ batchSize + 1}: $e');
      }
    }
  }

  // Sanitize and validate attendee data
  Future<Map<String, dynamic>> _sanitizeAttendeeData(
    Map<String, dynamic> data, 
    String userId,
  ) async {
    final now = DateTime.now();
    
    // Required fields validation
    if (data['name'] == null || (data['name'] as String).trim().isEmpty) {
      throw DataImportException('Attendee name is required');
    }
    
    if (data['phoneNumber'] == null || (data['phoneNumber'] as String).trim().isEmpty) {
      throw DataImportException('Attendee phone number is required');
    }

    // Validate phone number format
    final phoneNumber = data['phoneNumber'] as String;
    if (!AttendeeModel.isValidKenyanPhone(phoneNumber)) {
      throw DataImportException('Invalid phone number format: $phoneNumber');
    }

    // Normalize phone number
    final normalizedPhone = AttendeeModel.normalizePhoneNumber(phoneNumber);

    return {
      'name': (data['name'] as String).trim(),
      'phoneNumber': normalizedPhone,
      'yearOfStudy': data['yearOfStudy'] ?? '',
      'location': data['location'] ?? 'Unknown',
      'category': data['category'] ?? 'student',
      'attendanceCount': data['attendanceCount'] ?? 0,
      'firstRegistered': data['firstRegistered'] ?? now.toIso8601String(),
      'lastUpdated': data['lastUpdated'] ?? now.toIso8601String(),
      
      // Cloud-specific fields
      'createdBy': data['createdBy'] ?? userId,
      'createdAt': data['createdAt'] ?? now.toIso8601String(),
      'modifiedBy': userId,
      'modifiedAt': now.toIso8601String(),
      'version': data['version'] ?? 1,
      
      // Import metadata
      'importedAt': now.toIso8601String(),
      'importedBy': userId,
      'originalId': data['originalId'],
    };
  }

  // Sanitize and validate message log data
  Future<Map<String, dynamic>> _sanitizeMessageLogData(
    Map<String, dynamic> data, 
    String userId,
  ) async {
    final now = DateTime.now();
    
    // Required fields validation
    if (data['serviceId'] == null) {
      throw DataImportException('Message log service ID is required');
    }
    
    if (data['attendeeId'] == null) {
      throw DataImportException('Message log attendee ID is required');
    }
    
    if (data['messageText'] == null || (data['messageText'] as String).trim().isEmpty) {
      throw DataImportException('Message text is required');
    }

    return {
      'serviceId': data['serviceId'],
      'attendeeId': data['attendeeId'],
      'messageText': (data['messageText'] as String).trim(),
      'sendStatus': data['sendStatus'] ?? 'pending',
      'sentAt': data['sentAt'],
      'errorMessage': data['errorMessage'],
      'createdAt': data['createdAt'] ?? now.toIso8601String(),
      
      // Cloud-specific fields
      'sentBy': data['sentBy'] ?? userId,
      'cloudCreatedAt': data['cloudCreatedAt'] ?? now.toIso8601String(),
      'version': data['version'] ?? 1,
      
      // Import metadata
      'importedAt': now.toIso8601String(),
      'importedBy': userId,
      'originalMessageId': data['originalMessageId'],
    };
  }

  // Sanitize and validate service data
  Future<Map<String, dynamic>> _sanitizeServiceData(
    Map<String, dynamic> data, 
    String userId,
  ) async {
    final now = DateTime.now();
    
    // Required fields validation
    if (data['serviceDate'] == null) {
      throw DataImportException('Service date is required');
    }

    return {
      'serviceDate': data['serviceDate'],
      'totalAttendees': data['totalAttendees'] ?? 0,
      'messageSent': data['messageSent'] ?? false,
      'messageText': data['messageText'],
      'createdAt': data['createdAt'] ?? now.toIso8601String(),
      
      // Cloud-specific fields
      'createdBy': data['createdBy'] ?? userId,
      'version': data['version'] ?? 1,
      
      // Import metadata
      'importedAt': now.toIso8601String(),
      'importedBy': userId,
      'originalServiceId': data['originalServiceId'],
      'attendeeIds': data['attendeeIds'] ?? [],
    };
  }

  // Verify import integrity
  Future<void> _verifyImportIntegrity(ImportResult result) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) return;

      // Count imported documents
      final attendeesQuery = await _firestore
          .collection('attendees')
          .where('importedBy', isEqualTo: user.uid)
          .get();
      
      final messageLogsQuery = await _firestore
          .collection('messageLogs')
          .where('importedBy', isEqualTo: user.uid)
          .get();
      
      final servicesQuery = await _firestore
          .collection('services')
          .where('importedBy', isEqualTo: user.uid)
          .get();

      result.verificationResults = {
        'attendeesInFirestore': attendeesQuery.docs.length,
        'messageLogsInFirestore': messageLogsQuery.docs.length,
        'servicesInFirestore': servicesQuery.docs.length,
        'attendeesImported': result.attendeesImported,
        'messageLogsImported': result.messageLogsImported,
        'servicesImported': result.servicesImported,
      };

      // Check for discrepancies
      if (attendeesQuery.docs.length != result.attendeesImported) {
        result.warnings.add('Attendees count mismatch: expected ${result.attendeesImported}, found ${attendeesQuery.docs.length}');
      }
      
      if (messageLogsQuery.docs.length != result.messageLogsImported) {
        result.warnings.add('Message logs count mismatch: expected ${result.messageLogsImported}, found ${messageLogsQuery.docs.length}');
      }
      
      if (servicesQuery.docs.length != result.servicesImported) {
        result.warnings.add('Services count mismatch: expected ${result.servicesImported}, found ${servicesQuery.docs.length}');
      }
    } catch (e) {
      result.warnings.add('Failed to verify import integrity: $e');
    }
  }

  // Import from encrypted backup
  Future<ImportResult> importFromEncryptedBackup(String encryptedFilePath) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataImportException('User must be authenticated to import encrypted backup');
      }

      // Read encrypted file
      final file = File(encryptedFilePath);
      if (!await file.exists()) {
        throw DataImportException('Encrypted backup file does not exist: $encryptedFilePath');
      }

      final encryptedData = await file.readAsString();
      
      // Decrypt data
      final decryptedJson = await EncryptionService.decryptData(encryptedData);
      final Map<String, dynamic> importData = json.decode(decryptedJson);

      // Validate decrypted data
      _validateImportDataStructure(importData);

      // Process import
      final result = ImportResult();
      result.startedAt = DateTime.now();
      
      await _processBatchImport(importData, user.uid, result);
      
      result.completedAt = DateTime.now();
      result.success = result.errors.isEmpty;

      if (result.success) {
        await _verifyImportIntegrity(result);
      }

      return result;
    } catch (e) {
      throw DataImportException('Failed to import from encrypted backup: $e');
    }
  }

  // Handle import errors gracefully
  Future<ImportResult> importWithErrorRecovery(String jsonFilePath) async {
    try {
      return await importFromJson(jsonFilePath);
    } catch (e) {
      // Create partial result with error information
      final result = ImportResult();
      result.success = false;
      result.errors.add('Import failed: $e');
      result.startedAt = DateTime.now();
      result.completedAt = DateTime.now();
      
      return result;
    }
  }

  // Get import progress (for UI updates)
  Stream<ImportProgress> getImportProgress() {
    // This would be implemented with a StreamController
    // For now, return empty stream
    return Stream.empty();
  }
}

// Import result class
class ImportResult {
  bool success = false;
  DateTime? startedAt;
  DateTime? completedAt;
  
  int attendeesProcessed = 0;
  int attendeesImported = 0;
  int attendeeErrors = 0;
  
  int messageLogsProcessed = 0;
  int messageLogsImported = 0;
  int messageLogErrors = 0;
  
  int servicesProcessed = 0;
  int servicesImported = 0;
  int serviceErrors = 0;
  
  List<String> errors = [];
  List<String> warnings = [];
  Map<String, dynamic>? verificationResults;

  // Get total items processed
  int get totalProcessed => attendeesProcessed + messageLogsProcessed + servicesProcessed;
  
  // Get total items imported successfully
  int get totalImported => attendeesImported + messageLogsImported + servicesImported;
  
  // Get total errors
  int get totalErrors => attendeeErrors + messageLogErrors + serviceErrors;
  
  // Get success rate
  double get successRate => totalProcessed > 0 ? (totalImported / totalProcessed) * 100 : 0.0;
  
  // Get duration
  Duration? get duration => startedAt != null && completedAt != null 
      ? completedAt!.difference(startedAt!) 
      : null;
}

// Import progress class (for real-time updates)
class ImportProgress {
  final int totalItems;
  final int processedItems;
  final int importedItems;
  final int errorCount;
  final String currentOperation;
  
  ImportProgress({
    required this.totalItems,
    required this.processedItems,
    required this.importedItems,
    required this.errorCount,
    required this.currentOperation,
  });
  
  double get progressPercentage => totalItems > 0 ? (processedItems / totalItems) * 100 : 0.0;
}

// Custom exception for data import operations
class DataImportException implements Exception {
  final String message;
  
  DataImportException(this.message);
  
  @override
  String toString() => 'DataImportException: $message';
}