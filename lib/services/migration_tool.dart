import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import 'data_migration_service.dart';
import 'data_import_service.dart';
import 'data_export_service.dart';
import '../services/auth_service.dart';

/// Unified migration tool that provides a simple interface for all migration operations
class MigrationTool {
  final DataMigrationService _migrationService = DataMigrationService();
  final DataImportService _importService = DataImportService();
  final DataExportService _exportService = DataExportService();
  final AuthService _authService = AuthService();

  // Check if user is authenticated
  bool get isAuthenticated => _authService.getCurrentUser() != null;

  // Get current user
  User? get currentUser => _authService.getCurrentUser();

  /// Export local SQLite data to JSON format for migration
  Future<String> exportLocalData() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to export data');
    }
    
    return await _migrationService.exportLocalDataToJson();
  }

  /// Import JSON data to Firestore
  Future<MigrationResult> importToFirestore(String jsonFilePath) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to import data');
    }

    return await _migrationService.importDataToFirestore(jsonFilePath);
  }

  /// Complete migration from local SQLite to Firestore
  Future<CompleteMigrationResult> performCompleteMigration() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to perform migration');
    }

    final result = CompleteMigrationResult();
    result.startedAt = DateTime.now();

    try {
      // Step 1: Export local data
      result.exportFilePath = await exportLocalData();
      result.exportCompleted = true;

      // Step 2: Import to Firestore
      final importResult = await importToFirestore(result.exportFilePath!);
      result.importResult = importResult;
      result.importCompleted = importResult.success;

      // Step 3: Create backup in Firebase Storage (optional)
      if (result.importCompleted) {
        try {
          final backupResult = await _exportService.exportFirestoreDataToEncryptedJson();
          if (backupResult.success && backupResult.localFilePath != null) {
            result.backupUrl = await _exportService.storeBackupInFirebaseStorage(backupResult.localFilePath!);
            result.backupCompleted = true;
          }
        } catch (e) {
          result.warnings.add('Failed to create backup: $e');
        }
      }

      result.completedAt = DateTime.now();
      result.success = result.exportCompleted && result.importCompleted;

      return result;
    } catch (e) {
      result.completedAt = DateTime.now();
      result.success = false;
      result.errorMessage = e.toString();
      throw MigrationToolException('Complete migration failed: $e');
    }
  }

  /// Import data from JSON file with error handling
  Future<ImportResult> importFromJson(String jsonFilePath) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to import data');
    }

    return await _importService.importFromJson(jsonFilePath);
  }

  /// Import data from encrypted backup
  Future<ImportResult> importFromEncryptedBackup(String encryptedFilePath) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to import encrypted backup');
    }

    return await _importService.importFromEncryptedBackup(encryptedFilePath);
  }

  /// Export all Firestore data to encrypted backup
  Future<ExportResult> createFullBackup() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to create backup');
    }

    return await _exportService.exportFirestoreDataToEncryptedJson();
  }

  /// Export only attendees data
  Future<ExportResult> exportAttendees() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to export attendees');
    }

    return await _exportService.exportAttendeesOnly();
  }

  /// Export only message logs data
  Future<ExportResult> exportMessageLogs() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to export message logs');
    }

    return await _exportService.exportMessageLogsOnly();
  }

  /// Export data by date range
  Future<ExportResult> exportByDateRange(DateTime startDate, DateTime endDate) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to export data by date range');
    }

    return await _exportService.exportDataByDateRange(startDate, endDate);
  }

  /// Store backup in Firebase Storage
  Future<String> storeBackupInCloud(String localFilePath) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to store backup in cloud');
    }

    return await _exportService.storeBackupInFirebaseStorage(localFilePath);
  }

  /// List available backups in Firebase Storage
  Future<List<BackupInfo>> listCloudBackups() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to list cloud backups');
    }

    return await _exportService.listAvailableBackups();
  }

  /// Download backup from Firebase Storage
  Future<String> downloadBackup(String downloadUrl, String fileName) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to download backup');
    }

    return await _exportService.downloadBackupFromStorage(downloadUrl, fileName);
  }

  /// Delete backup from Firebase Storage
  Future<void> deleteCloudBackup(String backupPath) async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to delete cloud backup');
    }

    await _exportService.deleteBackupFromStorage(backupPath);
  }

  /// Get migration status
  Future<MigrationStatus> getMigrationStatus() async {
    return await _migrationService.getMigrationStatus();
  }

  /// Get export statistics
  Future<ExportStatistics> getExportStatistics() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to get export statistics');
    }

    return await _exportService.getExportStatistics();
  }

  /// Validate JSON file before import
  Future<ValidationResult> validateImportFile(String jsonFilePath) async {
    try {
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'File does not exist: $jsonFilePath',
        );
      }

      // Try to read and parse the file
      final jsonString = await file.readAsString();
      final data = json.decode(jsonString);

      // Basic validation
      if (data is! Map<String, dynamic>) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Invalid JSON format: root must be an object',
        );
      }

      // Check required fields
      final requiredFields = ['exportedAt', 'exportedBy', 'version'];
      for (final field in requiredFields) {
        if (!data.containsKey(field)) {
          return ValidationResult(
            isValid: false,
            errorMessage: 'Missing required field: $field',
          );
        }
      }

      // Count data items
      int attendeesCount = 0;
      int messageLogsCount = 0;
      int servicesCount = 0;

      if (data.containsKey('attendees') && data['attendees'] is List) {
        attendeesCount = (data['attendees'] as List).length;
      }

      if (data.containsKey('messageLogs') && data['messageLogs'] is List) {
        messageLogsCount = (data['messageLogs'] as List).length;
      }

      if (data.containsKey('services') && data['services'] is List) {
        servicesCount = (data['services'] as List).length;
      }

      return ValidationResult(
        isValid: true,
        attendeesCount: attendeesCount,
        messageLogsCount: messageLogsCount,
        servicesCount: servicesCount,
        exportedAt: data['exportedAt'] as String?,
        exportedBy: data['exportedBy'] as String?,
        version: data['version'] as String?,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Failed to validate file: $e',
      );
    }
  }

  /// Create automatic scheduled backup
  Future<String> createScheduledBackup() async {
    if (!isAuthenticated) {
      throw MigrationToolException('User must be authenticated to create scheduled backup');
    }

    return await _exportService.createAutomaticBackup();
  }

  /// Clean up old local export files
  Future<int> cleanupOldExports({int daysOld = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/exports');
      
      if (!await exportDir.exists()) {
        return 0;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;

      await for (final entity in exportDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      return deletedCount;
    } catch (e) {
      throw MigrationToolException('Failed to cleanup old exports: $e');
    }
  }
}

/// Complete migration result
class CompleteMigrationResult {
  bool success = false;
  DateTime? startedAt;
  DateTime? completedAt;
  String? errorMessage;
  List<String> warnings = [];

  // Export phase
  bool exportCompleted = false;
  String? exportFilePath;

  // Import phase
  bool importCompleted = false;
  MigrationResult? importResult;

  // Backup phase
  bool backupCompleted = false;
  String? backupUrl;

  /// Get total duration
  Duration? get duration => startedAt != null && completedAt != null 
      ? completedAt!.difference(startedAt!) 
      : null;

  /// Get summary of results
  Map<String, dynamic> get summary => {
    'success': success,
    'duration': duration?.inSeconds,
    'exportCompleted': exportCompleted,
    'importCompleted': importCompleted,
    'backupCompleted': backupCompleted,
    'attendeesImported': importResult?.attendeesImported ?? 0,
    'messageLogsImported': importResult?.messageLogsImported ?? 0,
    'servicesImported': importResult?.servicesImported ?? 0,
    'warnings': warnings,
    'errorMessage': errorMessage,
  };
}

/// Validation result for import files
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int attendeesCount;
  final int messageLogsCount;
  final int servicesCount;
  final String? exportedAt;
  final String? exportedBy;
  final String? version;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.attendeesCount = 0,
    this.messageLogsCount = 0,
    this.servicesCount = 0,
    this.exportedAt,
    this.exportedBy,
    this.version,
  });

  /// Get total items count
  int get totalItems => attendeesCount + messageLogsCount + servicesCount;

  /// Get validation summary
  Map<String, dynamic> get summary => {
    'isValid': isValid,
    'errorMessage': errorMessage,
    'totalItems': totalItems,
    'attendeesCount': attendeesCount,
    'messageLogsCount': messageLogsCount,
    'servicesCount': servicesCount,
    'exportedAt': exportedAt,
    'exportedBy': exportedBy,
    'version': version,
  };
}

/// Custom exception for migration tool operations
class MigrationToolException implements Exception {
  final String message;
  
  MigrationToolException(this.message);
  
  @override
  String toString() => 'MigrationToolException: $message';
}