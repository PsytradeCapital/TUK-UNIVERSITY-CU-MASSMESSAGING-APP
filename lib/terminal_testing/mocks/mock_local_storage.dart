import 'dart:async';
import 'dart:convert';

/// Mock Local Storage for terminal testing
/// Simulates device storage operations without device dependency
class MockLocalStorage {
  // Remove singleton pattern to allow proper isolation between test iterations
  MockLocalStorage();

  final Map<String, String> _storage = {};
  final Map<String, List<String>> _listStorage = {};
  final StreamController<StorageEvent> _storageEventController = StreamController<StorageEvent>.broadcast();

  /// Safely emit storage event
  void _emitStorageEvent(StorageEvent event) {
    if (!_storageEventController.isClosed) {
      _storageEventController.add(event);
    }
  }

  /// Initialize mock storage with default test data
  void initialize() {
    // Add some default test data
    _storage['app_version'] = '1.0.0';
    _storage['first_launch'] = 'false';
    _storage['user_preferences'] = jsonEncode({
      'theme': 'light',
      'notifications_enabled': true,
      'auto_sync': true,
    });
    
    _listStorage['recent_searches'] = ['John Doe', 'Jane Smith'];
    _listStorage['favorite_locations'] = ['Main Campus', 'Library'];
  }

  /// Get string value from storage
  Future<String?> getString(String key) async {
    // Simulate storage access delay
    await Future.delayed(const Duration(milliseconds: 10));
    
    return _storage[key];
  }

  /// Set string value in storage
  Future<bool> setString(String key, String value) async {
    // Simulate storage write delay
    await Future.delayed(const Duration(milliseconds: 15));
    
    final oldValue = _storage[key];
    _storage[key] = value;
    
    // Emit storage event
    _emitStorageEvent(StorageEvent(
      key: key,
      oldValue: oldValue,
      newValue: value,
      operation: StorageOperation.set,
    ));
    
    return true;
  }

  /// Get integer value from storage
  Future<int?> getInt(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    final stringValue = _storage[key];
    if (stringValue == null) return null;
    
    return int.tryParse(stringValue);
  }

  /// Set integer value in storage
  Future<bool> setInt(String key, int value) async {
    return await setString(key, value.toString());
  }

  /// Get double value from storage
  Future<double?> getDouble(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    final stringValue = _storage[key];
    if (stringValue == null) return null;
    
    return double.tryParse(stringValue);
  }

  /// Set double value in storage
  Future<bool> setDouble(String key, double value) async {
    return await setString(key, value.toString());
  }

  /// Get boolean value from storage
  Future<bool?> getBool(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    final stringValue = _storage[key];
    if (stringValue == null) return null;
    
    return stringValue.toLowerCase() == 'true';
  }

  /// Set boolean value in storage
  Future<bool> setBool(String key, bool value) async {
    return await setString(key, value.toString());
  }

  /// Get string list from storage
  Future<List<String>?> getStringList(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    return _listStorage[key]?.toList();
  }

  /// Set string list in storage
  Future<bool> setStringList(String key, List<String> value) async {
    await Future.delayed(const Duration(milliseconds: 15));
    
    final oldValue = _listStorage[key];
    _listStorage[key] = List<String>.from(value);
    
    // Emit storage event
    _emitStorageEvent(StorageEvent(
      key: key,
      oldValue: oldValue?.join(','),
      newValue: value.join(','),
      operation: StorageOperation.set,
    ));
    
    return true;
  }

  /// Get JSON object from storage
  Future<Map<String, dynamic>?> getJson(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    final stringValue = _storage[key];
    if (stringValue == null) return null;
    
    try {
      return jsonDecode(stringValue) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Set JSON object in storage
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      return await setString(key, jsonString);
    } catch (e) {
      return false;
    }
  }

  /// Check if key exists in storage
  Future<bool> containsKey(String key) async {
    await Future.delayed(const Duration(milliseconds: 5));
    
    return _storage.containsKey(key) || _listStorage.containsKey(key);
  }

  /// Remove key from storage
  Future<bool> remove(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    final stringValue = _storage.remove(key);
    final listValue = _listStorage.remove(key);
    
    if (stringValue != null || listValue != null) {
      // Emit storage event
      _emitStorageEvent(StorageEvent(
        key: key,
        oldValue: stringValue ?? listValue?.join(','),
        newValue: null,
        operation: StorageOperation.remove,
      ));
      return true;
    }
    
    return false;
  }

  /// Clear all storage
  Future<bool> clear() async {
    await Future.delayed(const Duration(milliseconds: 20));
    
    final hadData = _storage.isNotEmpty || _listStorage.isNotEmpty;
    
    _storage.clear();
    _listStorage.clear();
    
    if (hadData) {
      // Emit storage event
      _emitStorageEvent(StorageEvent(
        key: '*',
        oldValue: 'all_data',
        newValue: null,
        operation: StorageOperation.clear,
      ));
    }
    
    return true;
  }

  /// Get all keys in storage
  Future<Set<String>> getKeys() async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    final allKeys = <String>{};
    allKeys.addAll(_storage.keys);
    allKeys.addAll(_listStorage.keys);
    
    return allKeys;
  }

  /// Get storage size (number of keys)
  Future<int> getSize() async {
    await Future.delayed(const Duration(milliseconds: 5));
    
    return _storage.length + _listStorage.length;
  }

  /// Get storage usage in bytes (approximate)
  Future<int> getStorageUsage() async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    int totalBytes = 0;
    
    // Calculate string storage usage
    for (final entry in _storage.entries) {
      totalBytes += entry.key.length * 2; // UTF-16 encoding
      totalBytes += entry.value.length * 2;
    }
    
    // Calculate list storage usage
    for (final entry in _listStorage.entries) {
      totalBytes += entry.key.length * 2;
      for (final item in entry.value) {
        totalBytes += item.length * 2;
      }
    }
    
    return totalBytes;
  }

  /// Stream of storage events
  Stream<StorageEvent> get storageEvents => _storageEventController.stream;

  /// Backup storage to JSON string
  Future<String> backup() async {
    await Future.delayed(const Duration(milliseconds: 20));
    
    final backupData = {
      'storage': _storage,
      'listStorage': _listStorage,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    return jsonEncode(backupData);
  }

  /// Restore storage from JSON string
  Future<bool> restore(String backupJson) async {
    try {
      await Future.delayed(const Duration(milliseconds: 30));
      
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
      
      // Clear existing data
      _storage.clear();
      _listStorage.clear();
      
      // Restore string storage
      if (backupData['storage'] != null) {
        final storageData = backupData['storage'] as Map<String, dynamic>;
        for (final entry in storageData.entries) {
          _storage[entry.key] = entry.value.toString();
        }
      }
      
      // Restore list storage
      if (backupData['listStorage'] != null) {
        final listStorageData = backupData['listStorage'] as Map<String, dynamic>;
        for (final entry in listStorageData.entries) {
          final list = entry.value as List<dynamic>;
          _listStorage[entry.key] = list.map((e) => e.toString()).toList();
        }
      }
      
      // Emit restore event
      _emitStorageEvent(StorageEvent(
        key: '*',
        oldValue: null,
        newValue: 'restored',
        operation: StorageOperation.restore,
      ));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reset mock storage to initial state
  void reset() {
    _storage.clear();
    _listStorage.clear();
    initialize();
  }

  /// Add test data for specific scenarios
  void addTestData(Map<String, dynamic> testData) {
    for (final entry in testData.entries) {
      if (entry.value is String) {
        _storage[entry.key] = entry.value as String;
      } else if (entry.value is List<String>) {
        _listStorage[entry.key] = List<String>.from(entry.value as List<String>);
      } else {
        // Convert other types to JSON string
        _storage[entry.key] = jsonEncode(entry.value);
      }
    }
  }

  /// Get all storage data (for testing purposes)
  Map<String, dynamic> getAllData() {
    return {
      'storage': Map<String, String>.from(_storage),
      'listStorage': Map<String, List<String>>.from(_listStorage),
    };
  }

  /// Simulate storage error for testing error handling
  void simulateError(String key, {Duration? delay}) {
    // This could be used in tests to simulate storage failures
    // For now, it's a placeholder for future error simulation features
  }

  /// Dispose resources
  void dispose() {
    _storageEventController.close();
  }
}

/// Storage event for monitoring changes
class StorageEvent {
  final String key;
  final String? oldValue;
  final String? newValue;
  final StorageOperation operation;
  final DateTime timestamp;

  StorageEvent({
    required this.key,
    this.oldValue,
    this.newValue,
    required this.operation,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'StorageEvent(key: $key, operation: $operation, timestamp: $timestamp)';
  }
}

/// Storage operation types
enum StorageOperation {
  set,
  remove,
  clear,
  restore,
}

/// Mock shared preferences implementation
class MockSharedPreferences {
  final MockLocalStorage _storage = MockLocalStorage();

  /// Get instance (singleton pattern)
  static MockSharedPreferences? _instance;
  static Future<MockSharedPreferences> getInstance() async {
    _instance ??= MockSharedPreferences();
    return _instance!;
  }

  /// Get string value
  String? getString(String key) {
    // Note: This is synchronous unlike the async version in MockLocalStorage
    // This matches the SharedPreferences API
    return _storage._storage[key];
  }

  /// Set string value
  Future<bool> setString(String key, String value) {
    return _storage.setString(key, value);
  }

  /// Get int value
  int? getInt(String key) {
    final stringValue = _storage._storage[key];
    return stringValue != null ? int.tryParse(stringValue) : null;
  }

  /// Set int value
  Future<bool> setInt(String key, int value) {
    return _storage.setInt(key, value);
  }

  /// Get double value
  double? getDouble(String key) {
    final stringValue = _storage._storage[key];
    return stringValue != null ? double.tryParse(stringValue) : null;
  }

  /// Set double value
  Future<bool> setDouble(String key, double value) {
    return _storage.setDouble(key, value);
  }

  /// Get bool value
  bool? getBool(String key) {
    final stringValue = _storage._storage[key];
    return stringValue != null ? stringValue.toLowerCase() == 'true' : null;
  }

  /// Set bool value
  Future<bool> setBool(String key, bool value) {
    return _storage.setBool(key, value);
  }

  /// Get string list
  List<String>? getStringList(String key) {
    return _storage._listStorage[key]?.toList();
  }

  /// Set string list
  Future<bool> setStringList(String key, List<String> value) {
    return _storage.setStringList(key, value);
  }

  /// Check if key exists
  bool containsKey(String key) {
    return _storage._storage.containsKey(key) || _storage._listStorage.containsKey(key);
  }

  /// Remove key
  Future<bool> remove(String key) {
    return _storage.remove(key);
  }

  /// Clear all data
  Future<bool> clear() {
    return _storage.clear();
  }

  /// Get all keys
  Set<String> getKeys() {
    final allKeys = <String>{};
    allKeys.addAll(_storage._storage.keys);
    allKeys.addAll(_storage._listStorage.keys);
    return allKeys;
  }

  /// Reset to initial state
  void reset() {
    _storage.reset();
  }
}