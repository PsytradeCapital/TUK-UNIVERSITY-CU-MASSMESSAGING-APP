import 'package:sqflite/sqflite.dart';
import '../models/attendee_model.dart';
import '../services/database_manager.dart';
import '../services/encryption_service.dart';

class AttendeeRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  // Create a new attendee
  Future<int> createAttendee(AttendeeModel attendee) async {
    try {
      final db = await _databaseManager.database;
      
      // Normalize phone number before storing
      final normalizedPhone = AttendeeModel.normalizePhoneNumber(attendee.phoneNumber);
      final attendeeWithNormalizedPhone = attendee.copyWith(phoneNumber: normalizedPhone);
      
      // Encrypt sensitive data before storing
      final encryptedData = await EncryptionService.encryptAttendeeData(
        attendeeWithNormalizedPhone.toMap()
      );
      
      final id = await db.insert(
        'attendees',
        encryptedData,
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      
      return id;
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw AttendeeRepositoryException('Phone number already exists');
      }
      throw AttendeeRepositoryException('Failed to create attendee: $e');
    }
  }

  // Get attendee by ID
  Future<AttendeeModel?> getAttendeeById(int id) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        final decryptedData = await EncryptionService.decryptAttendeeData(maps.first);
        return AttendeeModel.fromMap(decryptedData);
      }
      return null;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendee by ID: $e');
    }
  }

  // Get attendee by phone number
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    try {
      final db = await _databaseManager.database;
      
      // Create searchable hash for encrypted phone lookup
      final phoneHash = await EncryptionService.createSearchablePhoneHash(phoneNumber);
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        where: 'phone_hash = ?',
        whereArgs: [phoneHash],
      );

      if (maps.isNotEmpty) {
        final decryptedData = await EncryptionService.decryptAttendeeData(maps.first);
        return AttendeeModel.fromMap(decryptedData);
      }
      return null;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendee by phone: $e');
    }
  }

  // Check if phone number already exists
  Future<bool> phoneNumberExists(String phoneNumber) async {
    try {
      final attendee = await getAttendeeByPhone(phoneNumber);
      return attendee != null;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to check phone number existence: $e');
    }
  }

  // Get all attendees
  Future<List<AttendeeModel>> getAllAttendees() async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        orderBy: 'id ASC', // Order by ID since encrypted names can't be sorted
      );

      final decryptedMaps = await EncryptionService.decryptAttendeeList(maps);
      
      return List.generate(decryptedMaps.length, (i) {
        return AttendeeModel.fromMap(decryptedMaps[i]);
      });
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get all attendees: $e');
    }
  }

  // Search attendees by name (for fuzzy search)
  Future<List<AttendeeModel>> searchAttendeesByName(String query) async {
    try {
      // Since names are encrypted, we need to get all attendees and search in memory
      final allAttendees = await getAllAttendees();
      
      // Filter attendees by name containing the query (case-insensitive)
      final filteredAttendees = allAttendees.where((attendee) {
        return attendee.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      // Sort by name
      filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
      
      return filteredAttendees;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to search attendees by name: $e');
    }
  }

  // Update attendee
  Future<void> updateAttendee(AttendeeModel attendee) async {
    try {
      final db = await _databaseManager.database;
      
      if (attendee.id == null) {
        throw AttendeeRepositoryException('Cannot update attendee without ID');
      }

      // Normalize phone number before updating
      final normalizedPhone = AttendeeModel.normalizePhoneNumber(attendee.phoneNumber);
      final attendeeWithNormalizedPhone = attendee.copyWith(
        phoneNumber: normalizedPhone,
        lastUpdated: DateTime.now(),
      );
      
      // Encrypt sensitive data before updating
      final encryptedData = await EncryptionService.encryptAttendeeData(
        attendeeWithNormalizedPhone.toMap()
      );
      
      final count = await db.update(
        'attendees',
        encryptedData,
        where: 'id = ?',
        whereArgs: [attendee.id],
      );

      if (count == 0) {
        throw AttendeeRepositoryException('Attendee not found for update');
      }
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw AttendeeRepositoryException('Phone number already exists');
      }
      throw AttendeeRepositoryException('Failed to update attendee: $e');
    }
  }

  // Update attendance count
  Future<void> updateAttendanceCount(int attendeeId, int newCount) async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.update(
        'attendees',
        {
          'attendance_count': newCount,
          'last_updated': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [attendeeId],
      );

      if (count == 0) {
        throw AttendeeRepositoryException('Attendee not found for attendance update');
      }
    } catch (e) {
      throw AttendeeRepositoryException('Failed to update attendance count: $e');
    }
  }

  // Increment attendance count
  Future<void> incrementAttendanceCount(int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      
      // Use SQL to increment directly in database for atomicity
      final count = await db.rawUpdate(
        'UPDATE attendees SET attendance_count = attendance_count + 1, last_updated = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), attendeeId],
      );

      if (count == 0) {
        throw AttendeeRepositoryException('Attendee not found for attendance increment');
      }
    } catch (e) {
      throw AttendeeRepositoryException('Failed to increment attendance count: $e');
    }
  }

  // Delete attendee
  Future<void> deleteAttendee(int id) async {
    try {
      final db = await _databaseManager.database;
      
      final count = await db.delete(
        'attendees',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw AttendeeRepositoryException('Attendee not found for deletion');
      }
    } catch (e) {
      throw AttendeeRepositoryException('Failed to delete attendee: $e');
    }
  }

  // Get attendees with high attendance (for reports)
  Future<List<AttendeeModel>> getAttendeesWithMinAttendance(int minAttendance) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        where: 'attendance_count >= ?',
        whereArgs: [minAttendance],
        orderBy: 'attendance_count DESC, name ASC',
      );

      return List.generate(maps.length, (i) {
        return AttendeeModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees with min attendance: $e');
    }
  }

  // Get attendees by year of study
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        where: 'year_of_study = ?',
        whereArgs: [yearOfStudy],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) {
        return AttendeeModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees by year: $e');
    }
  }

  // Get attendees by location
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        where: 'location = ?',
        whereArgs: [location],
        orderBy: 'name ASC',
      );

      return List.generate(maps.length, (i) {
        return AttendeeModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees by location: $e');
    }
  }

  // Get attendance statistics
  Future<Map<String, dynamic>> getAttendanceStatistics() async {
    try {
      final db = await _databaseManager.database;
      
      // Total attendees
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM attendees');
      final totalAttendees = totalResult.first['total'] as int;
      
      // Average attendance
      final avgResult = await db.rawQuery('SELECT AVG(attendance_count) as average FROM attendees');
      final averageAttendance = (avgResult.first['average'] as double?) ?? 0.0;
      
      // Max attendance
      final maxResult = await db.rawQuery('SELECT MAX(attendance_count) as maximum FROM attendees');
      final maxAttendance = maxResult.first['maximum'] as int? ?? 0;
      
      // Min attendance
      final minResult = await db.rawQuery('SELECT MIN(attendance_count) as minimum FROM attendees');
      final minAttendance = minResult.first['minimum'] as int? ?? 0;
      
      // Total attendance count (sum of all individual attendance counts)
      final sumResult = await db.rawQuery('SELECT SUM(attendance_count) as total_attendance FROM attendees');
      final totalAttendanceCount = sumResult.first['total_attendance'] as int? ?? 0;

      return {
        'totalAttendees': totalAttendees,
        'averageAttendance': averageAttendance,
        'maxAttendance': maxAttendance,
        'minAttendance': minAttendance,
        'totalAttendanceCount': totalAttendanceCount,
      };
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendance statistics: $e');
    }
  }

  // Get recently registered attendees
  Future<List<AttendeeModel>> getRecentlyRegistered({int limit = 10}) async {
    try {
      final db = await _databaseManager.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'attendees',
        orderBy: 'first_registered DESC',
        limit: limit,
      );

      return List.generate(maps.length, (i) {
        return AttendeeModel.fromMap(maps[i]);
      });
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get recently registered attendees: $e');
    }
  }

  // Bulk insert attendees (for data import)
  Future<List<int>> bulkInsertAttendees(List<AttendeeModel> attendees) async {
    try {
      final db = await _databaseManager.database;
      final List<int> insertedIds = [];
      
      await db.transaction((txn) async {
        for (final attendee in attendees) {
          // Normalize phone number before storing
          final normalizedPhone = AttendeeModel.normalizePhoneNumber(attendee.phoneNumber);
          final attendeeWithNormalizedPhone = attendee.copyWith(phoneNumber: normalizedPhone);
          
          try {
            final id = await txn.insert(
              'attendees',
              attendeeWithNormalizedPhone.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore, // Skip duplicates
            );
            if (id != 0) {
              insertedIds.add(id);
            }
          } catch (e) {
            // Continue with other attendees if one fails
            continue;
          }
        }
      });
      
      return insertedIds;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to bulk insert attendees: $e');
    }
  }

  // Count total attendees
  Future<int> getTotalAttendeesCount() async {
    try {
      final db = await _databaseManager.database;
      
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM attendees');
      return result.first['count'] as int;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get total attendees count: $e');
    }
  }
}

// Custom exception for attendee repository operations
class AttendeeRepositoryException implements Exception {
  final String message;
  
  AttendeeRepositoryException(this.message);
  
  @override
  String toString() => 'AttendeeRepositoryException: $message';
}