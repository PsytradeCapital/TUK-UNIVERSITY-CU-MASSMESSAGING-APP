import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/attendee_model.dart';
import '../repositories/attendee_repository.dart';
import '../repositories/service_repository.dart';
import '../services/database_manager.dart';

class DataManagementService {
  final AttendeeRepository _attendeeRepository = AttendeeRepository();
  final ServiceRepository _serviceRepository = ServiceRepository();
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  /// Export attendee list to CSV format
  Future<String> exportAttendeesToCSV({
    List<AttendeeModel>? attendees,
    bool includeAllAttendees = false,
    String? filename,
  }) async {
    try {
      List<AttendeeModel> dataToExport;
      
      if (attendees != null) {
        dataToExport = attendees;
      } else if (includeAllAttendees) {
        dataToExport = await _attendeeRepository.getAllAttendees();
      } else {
        throw DataManagementException('No attendees specified for export');
      }

      // Create CSV headers
      List<List<dynamic>> csvData = [
        ['Name', 'Phone Number', 'Year of Study', 'Location', 'Attendance Count', 'First Registered', 'Last Updated']
      ];

      // Add attendee data
      for (final attendee in dataToExport) {
        csvData.add([
          attendee.name,
          attendee.phoneNumber,
          attendee.yearOfStudy,
          attendee.location,
          attendee.attendanceCount,
          attendee.firstRegistered.toIso8601String(),
          attendee.lastUpdated.toIso8601String(),
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = filename ?? 'attendees_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      return file.path;
    } catch (e) {
      throw DataManagementException('Failed to export attendees to CSV: $e');
    }
  }

  /// Export service session data to CSV
  Future<String> exportServiceSessionToCSV(int serviceId, {String? filename}) async {
    try {
      final service = await _serviceRepository.getServiceById(serviceId);
      if (service == null) {
        throw DataManagementException('Service not found');
      }

      final attendees = await _serviceRepository.getServiceAttendees(serviceId);

      // Create CSV headers
      List<List<dynamic>> csvData = [
        ['Service Date', 'Service ID', 'Total Attendees', 'Message Sent', 'Message Text'],
        [
          service.serviceDate.toIso8601String(),
          service.serviceId,
          service.totalAttendees,
          service.messageSent ? 'Yes' : 'No',
          service.messageText ?? 'N/A'
        ],
        [], // Empty row
        ['Attendee Name', 'Phone Number', 'Year of Study', 'Location', 'Total Attendance Count']
      ];

      // Add attendee data
      for (final attendee in attendees) {
        csvData.add([
          attendee.name,
          attendee.phoneNumber,
          attendee.yearOfStudy,
          attendee.location,
          attendee.attendanceCount,
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = filename ?? 'service_${serviceId}_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      return file.path;
    } catch (e) {
      throw DataManagementException('Failed to export service session to CSV: $e');
    }
  }

  /// Share exported CSV file
  Future<void> shareCSVFile(String filePath, {String? subject}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw DataManagementException('Export file not found');
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject ?? 'Attendee Data Export',
        text: 'TUK CU Mass Messaging App - attendance data export',
      );
    } catch (e) {
      throw DataManagementException('Failed to share CSV file: $e');
    }
  }

  /// Clear old service data (older than specified days)
  Future<DataClearingResult> clearOldServiceData({
    required int olderThanDays,
    bool dryRun = false,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      
      // Get services to be deleted
      final oldServices = await _serviceRepository.getServicesByDateRange(
        DateTime(2000), // Very old date
        cutoffDate,
      );

      if (dryRun) {
        return DataClearingResult(
          servicesAffected: oldServices.length,
          attendeesAffected: 0,
          dryRun: true,
          details: 'Would delete ${oldServices.length} services older than $olderThanDays days',
        );
      }

      int deletedServices = 0;
      for (final service in oldServices) {
        await _serviceRepository.deleteService(service.serviceId!);
        deletedServices++;
      }

      return DataClearingResult(
        servicesAffected: deletedServices,
        attendeesAffected: 0,
        dryRun: false,
        details: 'Deleted $deletedServices services older than $olderThanDays days',
      );
    } catch (e) {
      throw DataManagementException('Failed to clear old service data: $e');
    }
  }

  /// Clear attendees with zero attendance (never attended any service)
  Future<DataClearingResult> clearInactiveAttendees({bool dryRun = false}) async {
    try {
      final allAttendees = await _attendeeRepository.getAllAttendees();
      final inactiveAttendees = allAttendees.where((a) => a.attendanceCount == 0).toList();

      if (dryRun) {
        return DataClearingResult(
          servicesAffected: 0,
          attendeesAffected: inactiveAttendees.length,
          dryRun: true,
          details: 'Would delete ${inactiveAttendees.length} attendees with zero attendance',
        );
      }

      int deletedAttendees = 0;
      for (final attendee in inactiveAttendees) {
        await _attendeeRepository.deleteAttendee(attendee.id!);
        deletedAttendees++;
      }

      return DataClearingResult(
        servicesAffected: 0,
        attendeesAffected: deletedAttendees,
        dryRun: false,
        details: 'Deleted $deletedAttendees inactive attendees',
      );
    } catch (e) {
      throw DataManagementException('Failed to clear inactive attendees: $e');
    }
  }

  /// Clear all data (nuclear option)
  Future<DataClearingResult> clearAllData({bool dryRun = false}) async {
    try {
      final allServices = await _serviceRepository.getAllServices();
      final allAttendees = await _attendeeRepository.getAllAttendees();

      if (dryRun) {
        return DataClearingResult(
          servicesAffected: allServices.length,
          attendeesAffected: allAttendees.length,
          dryRun: true,
          details: 'Would delete ALL data: ${allServices.length} services and ${allAttendees.length} attendees',
        );
      }

      // Clear all data by recreating database
      await _databaseManager.clearAllData();

      return DataClearingResult(
        servicesAffected: allServices.length,
        attendeesAffected: allAttendees.length,
        dryRun: false,
        details: 'Cleared ALL data: ${allServices.length} services and ${allAttendees.length} attendees',
      );
    } catch (e) {
      throw DataManagementException('Failed to clear all data: $e');
    }
  }

  /// Perform database maintenance tasks
  Future<MaintenanceResult> performDatabaseMaintenance() async {
    try {
      final results = <String>[];
      
      // Vacuum database to reclaim space
      await _databaseManager.vacuumDatabase();
      results.add('Database vacuumed successfully');

      // Analyze database for query optimization
      await _databaseManager.analyzeDatabase();
      results.add('Database analyzed for optimization');

      // Check database integrity
      final integrityCheck = await _databaseManager.checkDatabaseIntegrity();
      if (integrityCheck) {
        results.add('Database integrity check passed');
      } else {
        results.add('WARNING: Database integrity check failed');
      }

      // Update statistics
      final stats = await _serviceRepository.getServiceStatistics();
      results.add('Statistics updated: ${stats['totalServices']} services, ${stats['totalUniqueAttendees']} unique attendees');

      return MaintenanceResult(
        success: true,
        operations: results,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return MaintenanceResult(
        success: false,
        operations: ['Database maintenance failed: $e'],
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get database size information
  Future<DatabaseSizeInfo> getDatabaseSizeInfo() async {
    try {
      final dbPath = await _databaseManager.getDatabasePath();
      final dbFile = File(dbPath);
      
      final sizeInBytes = await dbFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      final serviceCount = await _serviceRepository.getTotalServicesCount();
      final attendeeCount = await _attendeeRepository.getTotalAttendeesCount();

      return DatabaseSizeInfo(
        sizeInBytes: sizeInBytes,
        sizeInMB: sizeInMB,
        totalServices: serviceCount,
        totalAttendees: attendeeCount,
        databasePath: dbPath,
      );
    } catch (e) {
      throw DataManagementException('Failed to get database size info: $e');
    }
  }

  /// Create database backup
  Future<String> createDatabaseBackup({String? backupName}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = backupName ?? 'cu_attendance_backup_$timestamp.db';
      
      final backupPath = await _databaseManager.createBackup(fileName);
      
      return backupPath;
    } catch (e) {
      throw DataManagementException('Failed to create database backup: $e');
    }
  }

  /// Restore database from backup
  Future<void> restoreDatabaseFromBackup(String backupPath) async {
    try {
      await _databaseManager.restoreFromBackup(backupPath);
    } catch (e) {
      throw DataManagementException('Failed to restore database from backup: $e');
    }
  }

  /// Get data export options
  List<DataExportOption> getDataExportOptions() {
    return [
      DataExportOption(
        id: 'all_attendees',
        title: 'All Attendees',
        description: 'Export complete attendee database',
        icon: 'people',
      ),
      DataExportOption(
        id: 'current_session',
        title: 'Current Session',
        description: 'Export attendees from current service session',
        icon: 'event',
      ),
      DataExportOption(
        id: 'service_history',
        title: 'Service History',
        description: 'Export all service sessions with attendee lists',
        icon: 'history',
      ),
      DataExportOption(
        id: 'attendance_summary',
        title: 'Attendance Summary',
        description: 'Export attendance statistics and summaries',
        icon: 'analytics',
      ),
    ];
  }

  /// Get data clearing options
  List<DataClearingOption> getDataClearingOptions() {
    return [
      DataClearingOption(
        id: 'old_services',
        title: 'Old Services',
        description: 'Remove service sessions older than specified days',
        icon: 'delete_sweep',
        severity: DataClearingSeverity.low,
      ),
      DataClearingOption(
        id: 'inactive_attendees',
        title: 'Inactive Attendees',
        description: 'Remove attendees who have never attended any service',
        icon: 'person_remove',
        severity: DataClearingSeverity.medium,
      ),
      DataClearingOption(
        id: 'all_data',
        title: 'All Data',
        description: 'Remove ALL attendees and services (cannot be undone)',
        icon: 'warning',
        severity: DataClearingSeverity.high,
      ),
    ];
  }
}

// Data models for management operations
class DataClearingResult {
  final int servicesAffected;
  final int attendeesAffected;
  final bool dryRun;
  final String details;

  DataClearingResult({
    required this.servicesAffected,
    required this.attendeesAffected,
    required this.dryRun,
    required this.details,
  });
}

class MaintenanceResult {
  final bool success;
  final List<String> operations;
  final DateTime timestamp;

  MaintenanceResult({
    required this.success,
    required this.operations,
    required this.timestamp,
  });
}

class DatabaseSizeInfo {
  final int sizeInBytes;
  final double sizeInMB;
  final int totalServices;
  final int totalAttendees;
  final String databasePath;

  DatabaseSizeInfo({
    required this.sizeInBytes,
    required this.sizeInMB,
    required this.totalServices,
    required this.totalAttendees,
    required this.databasePath,
  });
}

class DataExportOption {
  final String id;
  final String title;
  final String description;
  final String icon;

  DataExportOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class DataClearingOption {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DataClearingSeverity severity;

  DataClearingOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.severity,
  });
}

enum DataClearingSeverity { low, medium, high }

// Custom exception for data management operations
class DataManagementException implements Exception {
  final String message;
  
  DataManagementException(this.message);
  
  @override
  String toString() => 'DataManagementException: $message';
}