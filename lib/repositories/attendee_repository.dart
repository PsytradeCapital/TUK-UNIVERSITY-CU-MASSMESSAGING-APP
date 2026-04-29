import 'package:sqflite/sqflite.dart';
import '../models/attendee_model.dart';
import '../services/database_manager.dart';

/// Local SQLite repository — NO encryption on local storage.
/// Data is stored as plain text for instant reads.
/// Encryption only happens when syncing to Firestore (cloud).
class AttendeeRepository {
  final DatabaseManager _databaseManager = DatabaseManager.instance;

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<int> createAttendee(AttendeeModel attendee) async {
    try {
      final db = await _databaseManager.database;
      final normalised = attendee.copyWith(
        phoneNumber: AttendeeModel.normalizePhoneNumber(attendee.phoneNumber),
      );
      final id = await db.insert(
        'attendees',
        normalised.toMap(),
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

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  Future<AttendeeModel?> getAttendeeById(int id) async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query('attendees', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) return AttendeeModel.fromMap(maps.first);
      return null;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendee by ID: $e');
    }
  }

  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    try {
      final db = await _databaseManager.database;
      final normalised = AttendeeModel.normalizePhoneNumber(phoneNumber);
      final maps = await db.query(
        'attendees',
        where: 'phone_number = ?',
        whereArgs: [normalised],
      );
      if (maps.isNotEmpty) return AttendeeModel.fromMap(maps.first);
      return null;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendee by phone: $e');
    }
  }

  Future<bool> phoneNumberExists(String phoneNumber) async {
    return (await getAttendeeByPhone(phoneNumber)) != null;
  }

  Future<List<AttendeeModel>> getAllAttendees() async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query('attendees', orderBy: 'name ASC');
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get all attendees: $e');
    }
  }

  Future<List<AttendeeModel>> searchAttendeesByName(String query) async {
    try {
      final db = await _databaseManager.database;
      final q = '%${query.toLowerCase()}%';
      final maps = await db.rawQuery(
        'SELECT * FROM attendees WHERE LOWER(name) LIKE ? OR phone_number LIKE ? ORDER BY name ASC',
        [q, q],
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to search attendees: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesWithMinAttendance(int min) async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query(
        'attendees',
        where: 'attendance_count >= ?',
        whereArgs: [min],
        orderBy: 'attendance_count DESC',
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees with min attendance: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query(
        'attendees',
        where: 'year_of_study = ?',
        whereArgs: [yearOfStudy],
        orderBy: 'name ASC',
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees by year: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query(
        'attendees',
        where: 'location = ?',
        whereArgs: [location],
        orderBy: 'name ASC',
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees by location: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query(
        'attendees',
        where: 'category = ?',
        whereArgs: [AttendeeModel.categoryToString(category)],
        orderBy: 'name ASC',
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees by category: $e');
    }
  }

  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  }) async {
    try {
      final db = await _databaseManager.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (years != null && years.isNotEmpty) {
        whereClauses.add('year_of_study IN (${List.filled(years.length, '?').join(',')})');
        whereArgs.addAll(years);
      }
      if (locations != null && locations.isNotEmpty) {
        whereClauses.add('location IN (${List.filled(locations.length, '?').join(',')})');
        whereArgs.addAll(locations);
      }
      if (categories != null && categories.isNotEmpty) {
        final strs = categories.map(AttendeeModel.categoryToString).toList();
        whereClauses.add('category IN (${List.filled(strs.length, '?').join(',')})');
        whereArgs.addAll(strs);
      }

      final maps = await db.query(
        'attendees',
        where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'name ASC',
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendees with filters: $e');
    }
  }

  Future<List<String>> getUniqueLocations() async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.rawQuery(
        'SELECT DISTINCT location FROM attendees WHERE location IS NOT NULL AND location != "" ORDER BY location ASC',
      );
      return maps.map((m) => m['location'] as String).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get unique locations: $e');
    }
  }

  Future<int> getTotalAttendeesCount() async {
    try {
      final db = await _databaseManager.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM attendees');
      return result.first['count'] as int;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get total attendees count: $e');
    }
  }

  Future<Map<String, dynamic>> getAttendanceStatistics() async {
    try {
      final db = await _databaseManager.database;
      final r1 = await db.rawQuery('SELECT COUNT(*) as total FROM attendees');
      final r2 = await db.rawQuery('SELECT AVG(attendance_count) as avg FROM attendees');
      final r3 = await db.rawQuery('SELECT MAX(attendance_count) as mx FROM attendees');
      final r4 = await db.rawQuery('SELECT MIN(attendance_count) as mn FROM attendees');
      final r5 = await db.rawQuery('SELECT SUM(attendance_count) as sm FROM attendees');
      return {
        'totalAttendees': r1.first['total'] as int,
        'averageAttendance': (r2.first['avg'] as double?) ?? 0.0,
        'maxAttendance': r3.first['mx'] as int? ?? 0,
        'minAttendance': r4.first['mn'] as int? ?? 0,
        'totalAttendanceCount': r5.first['sm'] as int? ?? 0,
      };
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get attendance statistics: $e');
    }
  }

  Future<List<AttendeeModel>> getRecentlyRegistered({int limit = 10}) async {
    try {
      final db = await _databaseManager.database;
      final maps = await db.query(
        'attendees',
        orderBy: 'first_registered DESC',
        limit: limit,
      );
      return maps.map((m) => AttendeeModel.fromMap(m)).toList();
    } catch (e) {
      throw AttendeeRepositoryException('Failed to get recently registered: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateAttendee(AttendeeModel attendee) async {
    try {
      if (attendee.id == null) {
        throw AttendeeRepositoryException('Cannot update attendee without ID');
      }
      final db = await _databaseManager.database;
      final normalised = attendee.copyWith(
        phoneNumber: AttendeeModel.normalizePhoneNumber(attendee.phoneNumber),
        lastUpdated: DateTime.now(),
      );
      final count = await db.update(
        'attendees',
        normalised.toMap(),
        where: 'id = ?',
        whereArgs: [attendee.id],
      );
      if (count == 0) throw AttendeeRepositoryException('Attendee not found for update');
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw AttendeeRepositoryException('Phone number already exists');
      }
      throw AttendeeRepositoryException('Failed to update attendee: $e');
    }
  }

  Future<void> updateAttendanceCount(int attendeeId, int newCount) async {
    try {
      final db = await _databaseManager.database;
      await db.update(
        'attendees',
        {'attendance_count': newCount, 'last_updated': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [attendeeId],
      );
    } catch (e) {
      throw AttendeeRepositoryException('Failed to update attendance count: $e');
    }
  }

  Future<void> incrementAttendanceCount(int attendeeId) async {
    try {
      final db = await _databaseManager.database;
      await db.rawUpdate(
        'UPDATE attendees SET attendance_count = attendance_count + 1, last_updated = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), attendeeId],
      );
    } catch (e) {
      throw AttendeeRepositoryException('Failed to increment attendance count: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteAttendee(int id) async {
    try {
      final db = await _databaseManager.database;
      final count = await db.delete('attendees', where: 'id = ?', whereArgs: [id]);
      if (count == 0) throw AttendeeRepositoryException('Attendee not found for deletion');
    } catch (e) {
      throw AttendeeRepositoryException('Failed to delete attendee: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // BULK
  // ---------------------------------------------------------------------------

  Future<List<int>> bulkInsertAttendees(List<AttendeeModel> attendees) async {
    try {
      final db = await _databaseManager.database;
      final ids = <int>[];
      await db.transaction((txn) async {
        for (final a in attendees) {
          final normalised = a.copyWith(
            phoneNumber: AttendeeModel.normalizePhoneNumber(a.phoneNumber),
          );
          final id = await txn.insert(
            'attendees',
            normalised.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (id != 0) ids.add(id);
        }
      });
      return ids;
    } catch (e) {
      throw AttendeeRepositoryException('Failed to bulk insert attendees: $e');
    }
  }
}

class AttendeeRepositoryException implements Exception {
  final String message;
  AttendeeRepositoryException(this.message);
  @override
  String toString() => 'AttendeeRepositoryException: $message';
}
