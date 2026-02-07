import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/auth_service.dart';
import '../services/encryption_service.dart';

class DataExportService {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Export Firestore data to encrypted JSON
  Future<ExportResult> exportFirestoreDataToEncryptedJson() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to export data');
      }

      final result = ExportResult();
      result.startedAt = DateTime.now();

      // Fetch all user's data from Firestore
      final exportData = await _fetchAllUserData(user.uid, result);

      // Create export package
      final exportPackage = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': user.uid,
        'version': '1.0',
        'source': 'firestore',
        'metadata': {
          'attendeesCount': result.attendeesExported,
          'messageLogsCount': result.messageLogsExported,
          'servicesCount': result.servicesExported,
          'exportType': 'full_backup',
        },
        'attendees': exportData['attendees'],
        'messageLogs': exportData['messageLogs'],
        'services': exportData['services'],
      };

      // Convert to JSON and encrypt
      final jsonString = json.encode(exportPackage);
      final encryptedData = await EncryptionService.encryptSensitiveData(jsonString);

      // Save to local file
      final filePath = await _saveEncryptedDataToFile(encryptedData, 'firestore_backup');
      result.localFilePath = filePath;

      result.completedAt = DateTime.now();
      result.success = true;

      return result;
    } catch (e) {
      throw DataExportException('Failed to export Firestore data: $e');
    }
  }

  // Fetch all user data from Firestore
  Future<Map<String, List<Map<String, dynamic>>>> _fetchAllUserData(
    String userId, 
    ExportResult result,
  ) async {
    final exportData = <String, List<Map<String, dynamic>>>{
      'attendees': [],
      'messageLogs': [],
      'services': [],
    };

    try {
      // Fetch attendees
      final attendeesSnapshot = await _firestore
          .collection('attendees')
          .where('createdBy', isEqualTo: userId)
          .get();

      for (final doc in attendeesSnapshot.docs) {
        exportData['attendees']!.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.attendeesExported++;
      }

      // Fetch message logs
      final messageLogsSnapshot = await _firestore
          .collection('messageLogs')
          .where('sentBy', isEqualTo: userId)
          .get();

      for (final doc in messageLogsSnapshot.docs) {
        exportData['messageLogs']!.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.messageLogsExported++;
      }

      // Fetch services
      final servicesSnapshot = await _firestore
          .collection('services')
          .where('createdBy', isEqualTo: userId)
          .get();

      for (final doc in servicesSnapshot.docs) {
        exportData['services']!.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.servicesExported++;
      }

      return exportData;
    } catch (e) {
      throw DataExportException('Failed to fetch user data from Firestore: $e');
    }
  }

  // Save encrypted data to local file
  Future<String> _saveEncryptedDataToFile(String encryptedData, String filePrefix) async {
    try {
      // Create export directory
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final filename = '${filePrefix}_$timestamp.encrypted';
      final filePath = '${exportDir.path}/$filename';

      // Write encrypted data to file
      final file = File(filePath);
      await file.writeAsString(encryptedData);

      return filePath;
    } catch (e) {
      throw DataExportException('Failed to save encrypted data to file: $e');
    }
  }

  // Store backup in Firebase Storage
  Future<String> storeBackupInFirebaseStorage(String localFilePath) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to store backup');
      }

      final file = File(localFilePath);
      if (!await file.exists()) {
        throw DataExportException('Backup file does not exist: $localFilePath');
      }

      // Generate storage path
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = 'backup_${user.uid}_$timestamp.encrypted';
      final storagePath = 'backups/${user.uid}/$fileName';

      // Upload to Firebase Storage with metadata
      final storageRef = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/octet-stream',
        customMetadata: {
          'userId': user.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'type': 'encrypted_backup',
          'version': '1.0',
        },
      );

      final uploadTask = storageRef.putFile(file, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw DataExportException('Failed to store backup in Firebase Storage: $e');
    }
  }

  // Export specific data types
  Future<ExportResult> exportAttendeesOnly() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to export attendees');
      }

      final result = ExportResult();
      result.startedAt = DateTime.now();

      // Fetch only attendees
      final attendeesSnapshot = await _firestore
          .collection('attendees')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      final attendeesData = <Map<String, dynamic>>[];
      for (final doc in attendeesSnapshot.docs) {
        attendeesData.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.attendeesExported++;
      }

      // Create export package
      final exportPackage = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': user.uid,
        'version': '1.0',
        'source': 'firestore',
        'exportType': 'attendees_only',
        'attendees': attendeesData,
      };

      // Convert to JSON and encrypt
      final jsonString = json.encode(exportPackage);
      final encryptedData = await EncryptionService.encryptSensitiveData(jsonString);

      // Save to local file
      final filePath = await _saveEncryptedDataToFile(encryptedData, 'attendees_export');
      result.localFilePath = filePath;

      result.completedAt = DateTime.now();
      result.success = true;

      return result;
    } catch (e) {
      throw DataExportException('Failed to export attendees: $e');
    }
  }

  // Export message logs only
  Future<ExportResult> exportMessageLogsOnly() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to export message logs');
      }

      final result = ExportResult();
      result.startedAt = DateTime.now();

      // Fetch only message logs
      final messageLogsSnapshot = await _firestore
          .collection('messageLogs')
          .where('sentBy', isEqualTo: user.uid)
          .get();

      final messageLogsData = <Map<String, dynamic>>[];
      for (final doc in messageLogsSnapshot.docs) {
        messageLogsData.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.messageLogsExported++;
      }

      // Create export package
      final exportPackage = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': user.uid,
        'version': '1.0',
        'source': 'firestore',
        'exportType': 'message_logs_only',
        'messageLogs': messageLogsData,
      };

      // Convert to JSON and encrypt
      final jsonString = json.encode(exportPackage);
      final encryptedData = await EncryptionService.encryptSensitiveData(jsonString);

      // Save to local file
      final filePath = await _saveEncryptedDataToFile(encryptedData, 'message_logs_export');
      result.localFilePath = filePath;

      result.completedAt = DateTime.now();
      result.success = true;

      return result;
    } catch (e) {
      throw DataExportException('Failed to export message logs: $e');
    }
  }

  // Export data by date range
  Future<ExportResult> exportDataByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to export data');
      }

      final result = ExportResult();
      result.startedAt = DateTime.now();

      final exportData = <String, List<Map<String, dynamic>>>{
        'attendees': [],
        'messageLogs': [],
        'services': [],
      };

      // Fetch attendees created in date range
      final attendeesSnapshot = await _firestore
          .collection('attendees')
          .where('createdBy', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();

      for (final doc in attendeesSnapshot.docs) {
        exportData['attendees']!.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.attendeesExported++;
      }

      // Fetch message logs created in date range
      final messageLogsSnapshot = await _firestore
          .collection('messageLogs')
          .where('sentBy', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();

      for (final doc in messageLogsSnapshot.docs) {
        exportData['messageLogs']!.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.messageLogsExported++;
      }

      // Fetch services created in date range
      final servicesSnapshot = await _firestore
          .collection('services')
          .where('createdBy', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();

      for (final doc in servicesSnapshot.docs) {
        exportData['services']!.add({
          'id': doc.id,
          ...doc.data(),
        });
        result.servicesExported++;
      }

      // Create export package
      final exportPackage = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': user.uid,
        'version': '1.0',
        'source': 'firestore',
        'exportType': 'date_range',
        'dateRange': {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
        'metadata': {
          'attendeesCount': result.attendeesExported,
          'messageLogsCount': result.messageLogsExported,
          'servicesCount': result.servicesExported,
        },
        'attendees': exportData['attendees'],
        'messageLogs': exportData['messageLogs'],
        'services': exportData['services'],
      };

      // Convert to JSON and encrypt
      final jsonString = json.encode(exportPackage);
      final encryptedData = await EncryptionService.encryptSensitiveData(jsonString);

      // Save to local file
      final filePath = await _saveEncryptedDataToFile(encryptedData, 'date_range_export');
      result.localFilePath = filePath;

      result.completedAt = DateTime.now();
      result.success = true;

      return result;
    } catch (e) {
      throw DataExportException('Failed to export data by date range: $e');
    }
  }

  // Create automatic backup
  Future<String> createAutomaticBackup() async {
    try {
      // Export all data
      final exportResult = await exportFirestoreDataToEncryptedJson();
      
      if (!exportResult.success || exportResult.localFilePath == null) {
        throw DataExportException('Failed to create local backup');
      }

      // Store in Firebase Storage
      final downloadUrl = await storeBackupInFirebaseStorage(exportResult.localFilePath!);
      
      return downloadUrl;
    } catch (e) {
      throw DataExportException('Failed to create automatic backup: $e');
    }
  }

  // List available backups in Firebase Storage
  Future<List<BackupInfo>> listAvailableBackups() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to list backups');
      }

      final backups = <BackupInfo>[];
      final storageRef = _storage.ref().child('backups/${user.uid}');
      
      final listResult = await storageRef.listAll();
      
      for (final item in listResult.items) {
        try {
          final metadata = await item.getMetadata();
          final downloadUrl = await item.getDownloadURL();
          
          backups.add(BackupInfo(
            name: item.name,
            path: item.fullPath,
            downloadUrl: downloadUrl,
            createdAt: metadata.timeCreated ?? DateTime.now(),
            size: metadata.size ?? 0,
            customMetadata: metadata.customMetadata ?? {},
          ));
        } catch (e) {
          // Skip items that can't be accessed
          continue;
        }
      }

      // Sort by creation date (newest first)
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return backups;
    } catch (e) {
      throw DataExportException('Failed to list available backups: $e');
    }
  }

  // Download backup from Firebase Storage
  Future<String> downloadBackupFromStorage(String downloadUrl, String fileName) async {
    try {
      // Create downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final filePath = '${downloadsDir.path}/$fileName';
      
      // Download file using HTTP client
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final file = File(filePath);
        await response.pipe(file.openWrite());
        return filePath;
      } else {
        throw DataExportException('Failed to download backup: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw DataExportException('Failed to download backup from storage: $e');
    }
  }

  // Delete backup from Firebase Storage
  Future<void> deleteBackupFromStorage(String backupPath) async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to delete backup');
      }

      // Verify user owns this backup
      if (!backupPath.contains('backups/${user.uid}/')) {
        throw DataExportException('Cannot delete backup that does not belong to current user');
      }

      final storageRef = _storage.ref().child(backupPath);
      await storageRef.delete();
    } catch (e) {
      throw DataExportException('Failed to delete backup from storage: $e');
    }
  }

  // Get export statistics
  Future<ExportStatistics> getExportStatistics() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw DataExportException('User must be authenticated to get export statistics');
      }

      // Count user's data in Firestore
      final attendeesSnapshot = await _firestore
          .collection('attendees')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      final messageLogsSnapshot = await _firestore
          .collection('messageLogs')
          .where('sentBy', isEqualTo: user.uid)
          .get();

      final servicesSnapshot = await _firestore
          .collection('services')
          .where('createdBy', isEqualTo: user.uid)
          .get();

      // List backups
      final backups = await listAvailableBackups();

      return ExportStatistics(
        totalAttendees: attendeesSnapshot.docs.length,
        totalMessageLogs: messageLogsSnapshot.docs.length,
        totalServices: servicesSnapshot.docs.length,
        availableBackups: backups.length,
        lastBackupDate: backups.isNotEmpty ? backups.first.createdAt : null,
        totalBackupSize: backups.fold(0, (sum, backup) => sum + backup.size),
      );
    } catch (e) {
      throw DataExportException('Failed to get export statistics: $e');
    }
  }
}

// Export result class
class ExportResult {
  bool success = false;
  DateTime? startedAt;
  DateTime? completedAt;
  String? localFilePath;
  String? cloudUrl;
  
  int attendeesExported = 0;
  int messageLogsExported = 0;
  int servicesExported = 0;
  
  List<String> errors = [];
  List<String> warnings = [];

  // Get total items exported
  int get totalExported => attendeesExported + messageLogsExported + servicesExported;
  
  // Get duration
  Duration? get duration => startedAt != null && completedAt != null 
      ? completedAt!.difference(startedAt!) 
      : null;
}

// Backup info class
class BackupInfo {
  final String name;
  final String path;
  final String downloadUrl;
  final DateTime createdAt;
  final int size;
  final Map<String, String> customMetadata;

  BackupInfo({
    required this.name,
    required this.path,
    required this.downloadUrl,
    required this.createdAt,
    required this.size,
    required this.customMetadata,
  });

  // Get human-readable file size
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

// Export statistics class
class ExportStatistics {
  final int totalAttendees;
  final int totalMessageLogs;
  final int totalServices;
  final int availableBackups;
  final DateTime? lastBackupDate;
  final int totalBackupSize;

  ExportStatistics({
    required this.totalAttendees,
    required this.totalMessageLogs,
    required this.totalServices,
    required this.availableBackups,
    this.lastBackupDate,
    required this.totalBackupSize,
  });

  // Get total data items
  int get totalDataItems => totalAttendees + totalMessageLogs + totalServices;

  // Get formatted backup size
  String get formattedBackupSize {
    if (totalBackupSize < 1024) return '${totalBackupSize}B';
    if (totalBackupSize < 1024 * 1024) return '${(totalBackupSize / 1024).toStringAsFixed(1)}KB';
    if (totalBackupSize < 1024 * 1024 * 1024) return '${(totalBackupSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalBackupSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

// Custom exception for data export operations
class DataExportException implements Exception {
  final String message;
  
  DataExportException(this.message);
  
  @override
  String toString() => 'DataExportException: $message';
}