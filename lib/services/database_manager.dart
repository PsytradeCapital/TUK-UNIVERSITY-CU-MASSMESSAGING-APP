import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseManager {
  static const String _databaseName = 'christian_union_attendance.db';
  static const int _databaseVersion = 6;
  
  static Database? _database;
  static DatabaseManager? _instance;

  // Singleton pattern
  DatabaseManager._internal();
  
  static DatabaseManager get instance {
    _instance ??= DatabaseManager._internal();
    return _instance!;
  }

  // Get database instance
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initializeDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createTables,
        onUpgrade: _migrateSchema,
        onOpen: (db) async {
          // Enable foreign key constraints
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      throw DatabaseException('Failed to initialize database: $e');
    }
  }

  // Create all tables
  Future<void> _createTables(Database db, int version) async {
    try {
      // Create attendees table
      await db.execute('''
        CREATE TABLE attendees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone_number TEXT UNIQUE NOT NULL,
          phone_hash TEXT,
          year_of_study TEXT,
          location TEXT NOT NULL,
          category TEXT DEFAULT 'student',
          attendance_count INTEGER DEFAULT 0,
          first_registered TEXT NOT NULL,
          last_updated TEXT NOT NULL,
          firestore_id TEXT,
          created_by TEXT,
          created_at TEXT,
          modified_by TEXT,
          modified_at TEXT,
          is_synced INTEGER DEFAULT 0,
          version INTEGER DEFAULT 1
        )
      ''');

      // Create services table
      await db.execute('''
        CREATE TABLE services (
          service_id INTEGER PRIMARY KEY AUTOINCREMENT,
          service_date TEXT NOT NULL,
          total_attendees INTEGER DEFAULT 0,
          message_sent INTEGER DEFAULT 0,
          message_text TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // Create service_attendees junction table (many-to-many)
      await db.execute('''
        CREATE TABLE service_attendees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          service_id INTEGER NOT NULL,
          attendee_id INTEGER NOT NULL,
          registered_at TEXT NOT NULL,
          FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE CASCADE,
          FOREIGN KEY (attendee_id) REFERENCES attendees(id) ON DELETE CASCADE,
          UNIQUE(service_id, attendee_id)
        )
      ''');

      // Create message_log table
      await db.execute('''
        CREATE TABLE message_log (
          message_id INTEGER PRIMARY KEY AUTOINCREMENT,
          service_id INTEGER NOT NULL,
          attendee_id INTEGER NOT NULL,
          message_text TEXT NOT NULL,
          send_status TEXT DEFAULT 'pending',
          sent_at TEXT,
          error_message TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE CASCADE,
          FOREIGN KEY (attendee_id) REFERENCES attendees(id) ON DELETE CASCADE
        )
      ''');

      // Create pending_messages table for retry logic
      await db.execute('''
        CREATE TABLE pending_messages (
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

      // Create sync_queue table for offline change tracking
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          collection TEXT NOT NULL,
          document_id TEXT,
          local_id INTEGER,
          data TEXT NOT NULL,
          created_at TEXT NOT NULL,
          processed_at TEXT,
          status TEXT NOT NULL,
          error_message TEXT,
          attempt_count INTEGER DEFAULT 0
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_attendees_phone ON attendees(phone_number)');
      await db.execute('CREATE INDEX idx_attendees_phone_hash ON attendees(phone_hash)');
      await db.execute('CREATE INDEX idx_attendees_name ON attendees(name)');
      await db.execute('CREATE INDEX idx_attendees_category ON attendees(category)');
      await db.execute('CREATE INDEX idx_service_attendees_service ON service_attendees(service_id)');
      await db.execute('CREATE INDEX idx_service_attendees_attendee ON service_attendees(attendee_id)');
      await db.execute('CREATE INDEX idx_message_log_service ON message_log(service_id)');
      await db.execute('CREATE INDEX idx_message_log_status ON message_log(send_status)');
      await db.execute('CREATE INDEX idx_pending_messages_status ON pending_messages(status)');
      await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
      await db.execute('CREATE INDEX idx_sync_queue_user ON sync_queue(user_id)');

    } catch (e) {
      throw DatabaseException('Failed to create tables: $e');
    }
  }

  // Handle database schema migrations
  Future<void> _migrateSchema(Database db, int oldVersion, int newVersion) async {
    try {
      // Migration from version 1 to 2: Add phone_hash column for encrypted search
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE attendees ADD COLUMN phone_hash TEXT');
        await db.execute('CREATE INDEX idx_attendees_phone_hash ON attendees(phone_hash)');
      }
      
      // Migration from version 2 to 3: Add pending_messages table
      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_messages (
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
        await db.execute('CREATE INDEX idx_pending_messages_status ON pending_messages(status)');
      }
      
      // Migration from version 3 to 4: Add category column and make year_of_study optional
      if (oldVersion < 4) {
        await db.execute('ALTER TABLE attendees ADD COLUMN category TEXT DEFAULT "student"');
        // Note: SQLite doesn't support modifying column constraints, so year_of_study remains NOT NULL
        // but we handle empty values in the application layer for associates/visitors
      }
      
      // Migration from version 4 to 5: Add sync_queue table for offline change tracking
      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            collection TEXT NOT NULL,
            document_id TEXT,
            local_id INTEGER,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            processed_at TEXT,
            status TEXT NOT NULL,
            error_message TEXT,
            attempt_count INTEGER DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
        await db.execute('CREATE INDEX idx_sync_queue_user ON sync_queue(user_id)');
      }
      
      // Migration from version 5 to 6: Add Firestore sync columns to attendees table
      if (oldVersion < 6) {
        await db.execute('ALTER TABLE attendees ADD COLUMN firestore_id TEXT');
        await db.execute('ALTER TABLE attendees ADD COLUMN created_by TEXT');
        await db.execute('ALTER TABLE attendees ADD COLUMN created_at TEXT');
        await db.execute('ALTER TABLE attendees ADD COLUMN modified_by TEXT');
        await db.execute('ALTER TABLE attendees ADD COLUMN modified_at TEXT');
        await db.execute('ALTER TABLE attendees ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE attendees ADD COLUMN version INTEGER DEFAULT 1');
        await db.execute('CREATE INDEX idx_attendees_firestore_id ON attendees(firestore_id)');
        await db.execute('CREATE INDEX idx_attendees_is_synced ON attendees(is_synced)');
      }
      
      // Add more migration logic as needed for future versions
    } catch (e) {
      throw DatabaseException('Failed to migrate database schema: $e');
    }
  }

  // Backup database to external storage
  Future<String> backupDatabase() async {
    try {
      Database db = await database;
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = db.path;
      
      // Create backup directory
      Directory backupDir = Directory(join(documentsDirectory.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      // Generate backup filename with timestamp
      String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      String backupPath = join(backupDir.path, 'backup_$timestamp.db');
      
      // Copy database file
      File dbFile = File(dbPath);
      await dbFile.copy(backupPath);
      
      return backupPath;
    } catch (e) {
      throw DatabaseException('Failed to backup database: $e');
    }
  }

  // Restore database from backup
  Future<void> restoreDatabase(String backupPath) async {
    try {
      File backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw DatabaseException('Backup file does not exist: $backupPath');
      }
      
      // Close current database connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Get current database path
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, _databaseName);
      
      // Replace current database with backup
      await backupFile.copy(dbPath);
      
      // Reinitialize database
      _database = await _initializeDatabase();
      
    } catch (e) {
      throw DatabaseException('Failed to restore database: $e');
    }
  }

  // Get database file size
  Future<int> getDatabaseSize() async {
    try {
      Database db = await database;
      File dbFile = File(db.path);
      return await dbFile.length();
    } catch (e) {
      throw DatabaseException('Failed to get database size: $e');
    }
  }

  // Vacuum database to reclaim space
  Future<void> vacuumDatabase() async {
    try {
      Database db = await database;
      await db.execute('VACUUM');
    } catch (e) {
      throw DatabaseException('Failed to vacuum database: $e');
    }
  }

  // Check database integrity
  Future<bool> checkIntegrity() async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> result = await db.rawQuery('PRAGMA integrity_check');
      return result.isNotEmpty && result.first.values.first == 'ok';
    } catch (e) {
      throw DatabaseException('Failed to check database integrity: $e');
    }
  }

  // Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      Database db = await database;
      
      Map<String, int> stats = {};
      
      // Count records in each table
      List<Map<String, dynamic>> attendeesCount = await db.rawQuery('SELECT COUNT(*) as count FROM attendees');
      stats['attendees'] = attendeesCount.first['count'];
      
      List<Map<String, dynamic>> servicesCount = await db.rawQuery('SELECT COUNT(*) as count FROM services');
      stats['services'] = servicesCount.first['count'];
      
      List<Map<String, dynamic>> serviceAttendeesCount = await db.rawQuery('SELECT COUNT(*) as count FROM service_attendees');
      stats['service_attendees'] = serviceAttendeesCount.first['count'];
      
      List<Map<String, dynamic>> messageLogCount = await db.rawQuery('SELECT COUNT(*) as count FROM message_log');
      stats['message_log'] = messageLogCount.first['count'];
      
      return stats;
    } catch (e) {
      throw DatabaseException('Failed to get database statistics: $e');
    }
  }

  // Clear all data (for testing or reset purposes)
  Future<void> clearAllData() async {
    try {
      Database db = await database;
      
      // Delete in reverse order of dependencies
      await db.delete('message_log');
      await db.delete('service_attendees');
      await db.delete('services');
      await db.delete('attendees');
      
    } catch (e) {
      throw DatabaseException('Failed to clear all data: $e');
    }
  }

  // Close database connection
  Future<void> closeDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
    } catch (e) {
      throw DatabaseException('Failed to close database: $e');
    }
  }

  // Delete database file (for complete reset)
  Future<void> deleteDatabase() async {
    try {
      await closeDatabase();
      
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      File dbFile = File(path);
      
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    } catch (e) {
      throw DatabaseException('Failed to delete database: $e');
    }
  }

  // Execute raw SQL query (for advanced operations)
  Future<List<Map<String, dynamic>>> executeQuery(String sql, [List<dynamic>? arguments]) async {
    try {
      Database db = await database;
      return await db.rawQuery(sql, arguments);
    } catch (e) {
      throw DatabaseException('Failed to execute query: $e');
    }
  }

  // Execute raw SQL command (for advanced operations)
  Future<void> executeCommand(String sql, [List<dynamic>? arguments]) async {
    try {
      Database db = await database;
      await db.rawQuery(sql, arguments);
    } catch (e) {
      throw DatabaseException('Failed to execute command: $e');
    }
  }

  // Get database path
  Future<String> getDatabasePath() async {
    Database db = await database;
    return db.path;
  }

  // Analyze database for query optimization
  Future<void> analyzeDatabase() async {
    try {
      Database db = await database;
      await db.execute('ANALYZE');
    } catch (e) {
      throw DatabaseException('Failed to analyze database: $e');
    }
  }

  // Check database integrity (alias for checkIntegrity)
  Future<bool> checkDatabaseIntegrity() async {
    return await checkIntegrity();
  }

  // Create backup with custom name
  Future<String> createBackup(String fileName) async {
    try {
      Database db = await database;
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = db.path;
      
      // Create backup directory
      Directory backupDir = Directory(join(documentsDirectory.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      String backupPath = join(backupDir.path, fileName);
      
      // Copy database file
      File dbFile = File(dbPath);
      await dbFile.copy(backupPath);
      
      return backupPath;
    } catch (e) {
      throw DatabaseException('Failed to create backup: $e');
    }
  }

  // Restore from backup with custom path
  Future<void> restoreFromBackup(String backupPath) async {
    await restoreDatabase(backupPath);
  }
}

// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  
  DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
}