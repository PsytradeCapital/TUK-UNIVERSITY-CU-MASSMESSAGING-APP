import 'package:sqflite/sqflite.dart';
import '../models/pending_message_model.dart';
import '../services/database_manager.dart';

class PendingMessageRepository {
  static const String tableName = 'pending_messages';

  Future<Database> get _db async => await DatabaseManager.instance.database;

  /// Create pending messages table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id INTEGER NOT NULL,
        attendee_id INTEGER NOT NULL,
        phone_number TEXT NOT NULL,
        attendee_name TEXT NOT NULL,
        message_text TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_attempt_at TEXT,
        attempt_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');
  }

  /// Add a pending message
  Future<int> addPendingMessage(PendingMessageModel message) async {
    final db = await _db;
    return await db.insert(tableName, message.toMap());
  }

  /// Get all pending messages
  Future<List<PendingMessageModel>> getAllPendingMessages() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => PendingMessageModel.fromMap(maps[i]));
  }

  /// Update pending message
  Future<int> updatePendingMessage(PendingMessageModel message) async {
    final db = await _db;
    return await db.update(
      tableName,
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  /// Delete pending message
  Future<int> deletePendingMessage(int id) async {
    final db = await _db;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get pending messages count
  Future<int> getPendingCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all sent messages
  Future<int> clearSentMessages() async {
    final db = await _db;
    return await db.delete(
      tableName,
      where: 'status = ?',
      whereArgs: ['sent'],
    );
  }
}
