import 'package:sqflite/sqflite.dart';
import '../models/service_model.dart';
import '../models/attendee_model.dart';
import '../services/database_manager.dart';

class ServiceRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  // Create a new service session
  Future<int> createService(ServiceModel service) async {
    try {
      final db = await _databaseManager.database;
      
      final serviceId = await db.insert(
        'services',
        service.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      
      return serviceId;
    } catch (e) {
      throw ServiceRepositoryException('Failed to create service: $e');
    }
  }

  // Insert service (alias for createService for consistency)
  Future<int> insertService(ServiceModel service) async {
    return await createService(service);
  }

  // Get service by ID
  Future<ServiceModel?> getServiceById(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'services',
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );

      if (maps.isNotEmpty) {
        final service = ServiceModel.fromMap(maps.first);
        // Load attendees for this service
        final attendees = await getServiceAttendees(serviceId);
        return service.copyWith(attendees: attendees);
      }
      return null;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get service by ID: $e');
    }
  }

  // Get all services with pagination
  Future<List<ServiceModel>> getAllServices({int? limit, int? offset}) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'services',
        orderBy: 'service_date DESC',
        limit: limit,
        offset: offset,
      );

      List<ServiceModel> services = [];
      for (final map in maps) {
        final service = ServiceModel.fromMap(map);
        // Load attendees for each service
        final attendees = await getServiceAttendees(service.serviceId!);
        services.add(service.copyWith(attendees: attendees));
      }
      
      return services;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get all services: $e');
    }
  }

  // Get recent services
  Future<List<ServiceModel>> getRecentServices({int limit = 10}) async {
    try {
      return await getAllServices(limit: limit);
    } catch (e) {
      throw ServiceRepositoryException('Failed to get recent services: $e');
    }
  }

  // Get services by date range
  Future<List<ServiceModel>> getServicesByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'services',
        where: 'service_date BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'service_date DESC',
      );

      List<ServiceModel> services = [];
      for (final map in maps) {
        final service = ServiceModel.fromMap(map);
        final attendees = await getServiceAttendees(service.serviceId!);
        services.add(service.copyWith(attendees: attendees));
      }
      
      return services;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get services by date range: $e');
    }
  }

  // Update service
  Future<void> updateService(ServiceModel service) async {
    try {
      final db = await _databaseManager.database;
      
      if (service.serviceId == null) {
        throw ServiceRepositoryException('Cannot update service without ID');
      }

      final count = await db.update(
        'services',
        service.toMap(),
        where: 'service_id = ?',
        whereArgs: [service.serviceId],
      );

      if (count == 0) {
        throw ServiceRepositoryException('Service not found for update');
      }
    } catch (e) {
      throw ServiceRepositoryException('Failed to update service: $e');
    }
  }

  // Delete service
  Future<void> deleteService(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      // Delete service (cascade will handle related records)
      final count = await db.delete(
        'services',
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );

      if (count == 0) {
        throw ServiceRepositoryException('Service not found for deletion');
      }
    } catch (e) {
      throw ServiceRepositoryException('Failed to delete service: $e');
    }
  }

  // Link attendee to service
  Future<void> addAttendeeToService(int serviceId, int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      
      await db.insert(
        'service_attendees',
        {
          'service_id': serviceId,
          'attendee_id': attendeeId,
          'registered_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if already exists
      );

      // Update total attendees count in service
      await _updateServiceAttendeeCount(serviceId);
      
    } catch (e) {
      throw ServiceRepositoryException('Failed to add attendee to service: $e');
    }
  }

  // Remove attendee from service
  Future<void> removeAttendeeFromService(int serviceId, int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.delete(
        'service_attendees',
        where: 'service_id = ? AND attendee_id = ?',
        whereArgs: [serviceId, attendeeId],
      );

      if (count > 0) {
        // Update total attendees count in service
        await _updateServiceAttendeeCount(serviceId);
      }
      
    } catch (e) {
      throw ServiceRepositoryException('Failed to remove attendee from service: $e');
    }
  }

  // Get attendees for a specific service
  Future<List<AttendeeModel>> getServiceAttendees(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT a.*, sa.registered_at
        FROM attendees a
        INNER JOIN service_attendees sa ON a.id = sa.attendee_id
        WHERE sa.service_id = ?
        ORDER BY sa.registered_at ASC
      ''', [serviceId]);

      return List.generate(maps.length, (i) {
        return AttendeeModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw ServiceRepositoryException('Failed to get service attendees: $e');
    }
  }

  // Check if attendee is registered for service
  Future<bool> isAttendeeRegisteredForService(int serviceId, int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'service_attendees',
        where: 'service_id = ? AND attendee_id = ?',
        whereArgs: [serviceId, attendeeId],
      );

      return maps.isNotEmpty;
    } catch (e) {
      throw ServiceRepositoryException('Failed to check attendee registration: $e');
    }
  }

  // Get services attended by a specific attendee
  Future<List<ServiceModel>> getServicesAttendedByAttendee(int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT s.*, sa.registered_at
        FROM services s
        INNER JOIN service_attendees sa ON s.service_id = sa.service_id
        WHERE sa.attendee_id = ?
        ORDER BY s.service_date DESC
      ''', [attendeeId]);

      List<ServiceModel> services = [];
      for (final map in maps) {
        final service = ServiceModel.fromMap(map);
        services.add(service);
      }
      
      return services;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get services attended by attendee: $e');
    }
  }

  // Mark service message as sent
  Future<void> markMessageSent(int serviceId, String messageText) async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.update(
        'services',
        {
          'message_sent': 1,
          'message_text': messageText,
        },
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );

      if (count == 0) {
        throw ServiceRepositoryException('Service not found for message update');
      }
    } catch (e) {
      throw ServiceRepositoryException('Failed to mark message as sent: $e');
    }
  }

  // Get service statistics
  Future<Map<String, dynamic>> getServiceStatistics() async {
    try {
      final db = await _databaseManager.database;
      
      // Total services
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM services');
      final totalServices = totalResult.first['total'] as int;
      
      // Services with messages sent
      final sentResult = await db.rawQuery('SELECT COUNT(*) as sent FROM services WHERE message_sent = 1');
      final servicesWithMessagesSent = sentResult.first['sent'] as int;
      
      // Average attendees per service
      final avgResult = await db.rawQuery('SELECT AVG(total_attendees) as average FROM services');
      final averageAttendeesPerService = (avgResult.first['average'] as double?) ?? 0.0;
      
      // Max attendees in a single service
      final maxResult = await db.rawQuery('SELECT MAX(total_attendees) as maximum FROM services');
      final maxAttendeesInService = maxResult.first['maximum'] as int? ?? 0;
      
      // Total unique attendees across all services
      final uniqueResult = await db.rawQuery('SELECT COUNT(DISTINCT attendee_id) as unique_attendees FROM service_attendees');
      final totalUniqueAttendees = uniqueResult.first['unique_attendees'] as int? ?? 0;
      
      // Most recent service date
      final recentResult = await db.rawQuery('SELECT MAX(service_date) as recent_date FROM services');
      final mostRecentServiceDate = recentResult.first['recent_date'] as String?;

      return {
        'totalServices': totalServices,
        'servicesWithMessagesSent': servicesWithMessagesSent,
        'averageAttendeesPerService': averageAttendeesPerService,
        'maxAttendeesInService': maxAttendeesInService,
        'totalUniqueAttendees': totalUniqueAttendees,
        'mostRecentServiceDate': mostRecentServiceDate,
      };
    } catch (e) {
      throw ServiceRepositoryException('Failed to get service statistics: $e');
    }
  }

  // Get attendance history for reporting
  Future<List<Map<String, dynamic>>> getAttendanceHistory({int? limit}) async {
    try {
      final db = await _databaseManager.database;
      
      String query = '''
        SELECT 
          s.service_id,
          s.service_date,
          s.total_attendees,
          s.message_sent,
          COUNT(sa.attendee_id) as actual_attendees
        FROM services s
        LEFT JOIN service_attendees sa ON s.service_id = sa.service_id
        GROUP BY s.service_id, s.service_date, s.total_attendees, s.message_sent
        ORDER BY s.service_date DESC
      ''';
      
      if (limit != null) {
        query += ' LIMIT $limit';
      }
      
      final List<Map<String, dynamic>> maps = await db.rawQuery(query);
      return maps;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get attendance history: $e');
    }
  }

  // Get monthly attendance summary
  Future<List<Map<String, dynamic>>> getMonthlyAttendanceSummary() async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          strftime('%Y-%m', service_date) as month,
          COUNT(*) as total_services,
          SUM(total_attendees) as total_attendees,
          AVG(total_attendees) as average_attendees,
          COUNT(CASE WHEN message_sent = 1 THEN 1 END) as services_with_messages
        FROM services
        GROUP BY strftime('%Y-%m', service_date)
        ORDER BY month DESC
      ''');
      
      return maps;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get monthly attendance summary: $e');
    }
  }

  // Clear service attendees (for starting new service)
  Future<void> clearServiceAttendees(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      await db.delete(
        'service_attendees',
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );

      // Update total attendees count to 0
      await db.update(
        'services',
        {'total_attendees': 0},
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );
      
    } catch (e) {
      throw ServiceRepositoryException('Failed to clear service attendees: $e');
    }
  }

  // Get current active service (most recent service)
  Future<ServiceModel?> getCurrentActiveService() async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'services',
        orderBy: 'service_date DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final service = ServiceModel.fromMap(maps.first);
        final attendees = await getServiceAttendees(service.serviceId!);
        return service.copyWith(attendees: attendees);
      }
      return null;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get current active service: $e');
    }
  }

  // Count total services
  Future<int> getTotalServicesCount() async {
    try {
      final db = await _databaseManager.database;
      
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM services');
      return result.first['count'] as int;
    } catch (e) {
      throw ServiceRepositoryException('Failed to get total services count: $e');
    }
  }

  // Private helper method to update service attendee count
  Future<void> _updateServiceAttendeeCount(int serviceId) async {
    try {
      final db = await _databaseManager.database;
      
      // Count actual attendees and update service record
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM service_attendees WHERE service_id = ?',
        [serviceId],
      );
      
      final attendeeCount = countResult.first['count'] as int;
      
      await db.update(
        'services',
        {'total_attendees': attendeeCount},
        where: 'service_id = ?',
        whereArgs: [serviceId],
      );
    } catch (e) {
      throw ServiceRepositoryException('Failed to update service attendee count: $e');
    }
  }

  // Bulk add attendees to service
  Future<void> bulkAddAttendeesToService(int serviceId, List<int> attendeeIds) async {
    try {
      final db = await _databaseManager.database;
      
      await db.transaction((txn) async {
        for (final attendeeId in attendeeIds) {
          await txn.insert(
            'service_attendees',
            {
              'service_id': serviceId,
              'attendee_id': attendeeId,
              'registered_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

      // Update total attendees count
      await _updateServiceAttendeeCount(serviceId);
      
    } catch (e) {
      throw ServiceRepositoryException('Failed to bulk add attendees to service: $e');
    }
  }
}

// Custom exception for service repository operations
class ServiceRepositoryException implements Exception {
  final String message;
  
  ServiceRepositoryException(this.message);
  
  @override
  String toString() => 'ServiceRepositoryException: $message';
}