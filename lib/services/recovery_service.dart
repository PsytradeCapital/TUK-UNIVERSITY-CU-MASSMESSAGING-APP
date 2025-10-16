import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/database_manager.dart';
import '../providers/service_session_provider.dart';
import '../providers/app_state_provider.dart';

/// Service for handling app recovery scenarios
class RecoveryService {
  static final RecoveryService _instance = RecoveryService._internal();
  factory RecoveryService() => _instance;
  RecoveryService._internal();

  /// Perform app recovery after crash or error
  Future<RecoveryResult> performRecovery({
    required AppStateProvider appStateProvider,
    required ServiceSessionProvider sessionProvider,
  }) async {
    debugPrint('Starting app recovery process');
    
    final recoverySteps = <RecoveryStep>[
      DatabaseRecoveryStep(),
      SessionRecoveryStep(),
      StateRecoveryStep(),
      DataIntegrityStep(),
    ];

    final results = <String, bool>{};
    final errors = <String, String>{};
    
    for (final step in recoverySteps) {
      try {
        debugPrint('Executing recovery step: ${step.name}');
        final success = await step.execute(
          appStateProvider: appStateProvider,
          sessionProvider: sessionProvider,
        );
        
        results[step.name] = success;
        
        if (!success) {
          errors[step.name] = 'Recovery step failed';
          debugPrint('Recovery step ${step.name} failed');
        } else {
          debugPrint('Recovery step ${step.name} completed successfully');
        }
      } catch (e) {
        results[step.name] = false;
        errors[step.name] = e.toString();
        debugPrint('Recovery step ${step.name} threw error: $e');
      }
    }

    final overallSuccess = results.values.every((success) => success);
    
    return RecoveryResult(
      success: overallSuccess,
      stepResults: results,
      errors: errors,
      timestamp: DateTime.now(),
    );
  }

  /// Perform quick recovery for minor issues
  Future<bool> performQuickRecovery({
    required AppStateProvider appStateProvider,
  }) async {
    try {
      debugPrint('Performing quick recovery');
      
      // Clear all errors
      appStateProvider.clearAllErrors();
      
      // Reset loading states
      appStateProvider.setGlobalLoading(false);
      
      // Validate database connection
      final dbManager = DatabaseManager.instance;
      await dbManager.database; // This will test the connection
      
      debugPrint('Quick recovery completed successfully');
      return true;
    } catch (e) {
      debugPrint('Quick recovery failed: $e');
      return false;
    }
  }

  /// Check if app needs recovery
  Future<bool> needsRecovery() async {
    try {
      // Check database integrity
      final dbManager = DatabaseManager.instance;
      final db = await dbManager.database;
      
      // Try a simple query to test database
      await db.rawQuery('SELECT COUNT(*) FROM attendees LIMIT 1');
      
      return false; // No recovery needed
    } catch (e) {
      debugPrint('Recovery check failed: $e');
      return true; // Recovery needed
    }
  }

  /// Create recovery checkpoint
  Future<void> createRecoveryCheckpoint({
    required ServiceSessionProvider sessionProvider,
  }) async {
    try {
      debugPrint('Creating recovery checkpoint');
      
      final checkpoint = RecoveryCheckpoint(
        timestamp: DateTime.now(),
        sessionState: sessionProvider.getSessionPersistenceData(),
        appVersion: '1.0.0', // Should come from package info
      );
      
      // Save checkpoint to secure storage or database
      await _saveCheckpoint(checkpoint);
      
      debugPrint('Recovery checkpoint created successfully');
    } catch (e) {
      debugPrint('Failed to create recovery checkpoint: $e');
    }
  }

  /// Restore from recovery checkpoint
  Future<bool> restoreFromCheckpoint({
    required ServiceSessionProvider sessionProvider,
  }) async {
    try {
      debugPrint('Restoring from recovery checkpoint');
      
      final checkpoint = await _loadCheckpoint();
      if (checkpoint == null) {
        debugPrint('No recovery checkpoint found');
        return false;
      }
      
      // Restore session state
      await sessionProvider.restoreSessionFromPersistence(checkpoint.sessionState);
      
      debugPrint('Successfully restored from recovery checkpoint');
      return true;
    } catch (e) {
      debugPrint('Failed to restore from checkpoint: $e');
      return false;
    }
  }

  /// Save checkpoint (placeholder implementation)
  Future<void> _saveCheckpoint(RecoveryCheckpoint checkpoint) async {
    // In a real implementation, this would save to secure storage
    debugPrint('Saving checkpoint: ${checkpoint.toJson()}');
  }

  /// Load checkpoint (placeholder implementation)
  Future<RecoveryCheckpoint?> _loadCheckpoint() async {
    // In a real implementation, this would load from secure storage
    debugPrint('Loading checkpoint');
    return null;
  }
}

/// Base class for recovery steps
abstract class RecoveryStep {
  String get name;
  
  Future<bool> execute({
    required AppStateProvider appStateProvider,
    required ServiceSessionProvider sessionProvider,
  });
}

/// Database recovery step
class DatabaseRecoveryStep extends RecoveryStep {
  @override
  String get name => 'Database Recovery';

  @override
  Future<bool> execute({
    required AppStateProvider appStateProvider,
    required ServiceSessionProvider sessionProvider,
  }) async {
    try {
      final dbManager = DatabaseManager.instance;
      
      // Test database connection
      final db = await dbManager.database;
      
      // Verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      
      final expectedTables = ['attendees', 'services', 'service_attendees', 'message_log'];
      final existingTables = tables.map((t) => t['name'] as String).toSet();
      
      for (final table in expectedTables) {
        if (!existingTables.contains(table)) {
          debugPrint('Missing table: $table');
          return false;
        }
      }
      
      // Test basic operations
      await db.rawQuery('SELECT COUNT(*) FROM attendees LIMIT 1');
      
      return true;
    } catch (e) {
      debugPrint('Database recovery failed: $e');
      return false;
    }
  }
}

/// Session recovery step
class SessionRecoveryStep extends RecoveryStep {
  @override
  String get name => 'Session Recovery';

  @override
  Future<bool> execute({
    required AppStateProvider appStateProvider,
    required ServiceSessionProvider sessionProvider,
  }) async {
    try {
      // Validate session state
      final isValid = await sessionProvider.validateSessionState();
      
      if (!isValid) {
        // Try to recover session
        await sessionProvider.loadActiveService();
      }
      
      return true;
    } catch (e) {
      debugPrint('Session recovery failed: $e');
      return false;
    }
  }
}

/// State recovery step
class StateRecoveryStep extends RecoveryStep {
  @override
  String get name => 'State Recovery';

  @override
  Future<bool> execute({
    required AppStateProvider appStateProvider,
    required ServiceSessionProvider sessionProvider,
  }) async {
    try {
      // Clear any error states
      appStateProvider.clearAllErrors();
      
      // Reset loading states
      appStateProvider.setGlobalLoading(false);
      
      // Validate app state
      final appStateSummary = appStateProvider.getAppStateSummary();
      debugPrint('App state after recovery: $appStateSummary');
      
      return true;
    } catch (e) {
      debugPrint('State recovery failed: $e');
      return false;
    }
  }
}

/// Data integrity recovery step
class DataIntegrityStep extends RecoveryStep {
  @override
  String get name => 'Data Integrity Check';

  @override
  Future<bool> execute({
    required AppStateProvider appStateProvider,
    required ServiceSessionProvider sessionProvider,
  }) async {
    try {
      final dbManager = DatabaseManager.instance;
      final db = await dbManager.database;
      
      // Check for orphaned records
      final orphanedServiceAttendees = await db.rawQuery('''
        SELECT COUNT(*) as count FROM service_attendees sa
        LEFT JOIN services s ON sa.service_id = s.service_id
        LEFT JOIN attendees a ON sa.attendee_id = a.id
        WHERE s.service_id IS NULL OR a.id IS NULL
      ''');
      
      final orphanedCount = orphanedServiceAttendees.first['count'] as int;
      if (orphanedCount > 0) {
        debugPrint('Found $orphanedCount orphaned service_attendees records');
        
        // Clean up orphaned records
        await db.execute('''
          DELETE FROM service_attendees 
          WHERE service_id NOT IN (SELECT service_id FROM services)
          OR attendee_id NOT IN (SELECT id FROM attendees)
        ''');
        
        debugPrint('Cleaned up orphaned records');
      }
      
      // Check for duplicate attendees
      final duplicates = await db.rawQuery('''
        SELECT phone_number, COUNT(*) as count 
        FROM attendees 
        GROUP BY phone_number 
        HAVING COUNT(*) > 1
      ''');
      
      if (duplicates.isNotEmpty) {
        debugPrint('Found ${duplicates.length} duplicate phone numbers');
        // Could implement duplicate resolution logic here
      }
      
      return true;
    } catch (e) {
      debugPrint('Data integrity check failed: $e');
      return false;
    }
  }
}

/// Recovery result model
class RecoveryResult {
  final bool success;
  final Map<String, bool> stepResults;
  final Map<String, String> errors;
  final DateTime timestamp;

  RecoveryResult({
    required this.success,
    required this.stepResults,
    required this.errors,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'stepResults': stepResults,
      'errors': errors,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'RecoveryResult(success: $success, steps: ${stepResults.length}, errors: ${errors.length})';
  }
}

/// Recovery checkpoint model
class RecoveryCheckpoint {
  final DateTime timestamp;
  final Map<String, dynamic> sessionState;
  final String appVersion;

  RecoveryCheckpoint({
    required this.timestamp,
    required this.sessionState,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'sessionState': sessionState,
      'appVersion': appVersion,
    };
  }

  factory RecoveryCheckpoint.fromJson(Map<String, dynamic> json) {
    return RecoveryCheckpoint(
      timestamp: DateTime.parse(json['timestamp']),
      sessionState: json['sessionState'],
      appVersion: json['appVersion'],
    );
  }
}