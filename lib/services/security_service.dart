import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static const String _pinKey = 'user_pin_hash';
  static const String _saltKey = 'pin_salt';
  static const String _lockTimeoutKey = 'auto_lock_timeout';
  static const String _lastActiveKey = 'last_active_time';
  static const String _encryptionKeyKey = 'encryption_key';
  
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );
  
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // PIN Management
  static Future<bool> isPinSet() async {
    final pinHash = await _secureStorage.read(key: _pinKey);
    return pinHash != null;
  }

  static Future<void> setPIN(String pin) async {
    final salt = _generateSalt();
    final hashedPin = _hashPin(pin, salt);
    
    await _secureStorage.write(key: _pinKey, value: hashedPin);
    await _secureStorage.write(key: _saltKey, value: salt);
    
    // Generate encryption key if not exists
    await _ensureEncryptionKey();
  }

  static Future<bool> validatePIN(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinKey);
    final salt = await _secureStorage.read(key: _saltKey);
    
    if (storedHash == null || salt == null) return false;
    
    final hashedPin = _hashPin(pin, salt);
    return hashedPin == storedHash;
  }

  static Future<void> changePIN(String oldPin, String newPin) async {
    if (!await validatePIN(oldPin)) {
      throw Exception('Invalid current PIN');
    }
    await setPIN(newPin);
  }

  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  static String _hashPin(String pin, String salt) {
    final saltBytes = base64Decode(salt);
    final pinBytes = utf8.encode(pin);
    final combined = [...pinBytes, ...saltBytes];
    
    var digest = sha256.convert(combined);
    // Additional rounds for security
    for (int i = 0; i < 10000; i++) {
      digest = sha256.convert([...digest.bytes, ...saltBytes]);
    }
    
    return base64Encode(digest.bytes);
  }

  // Auto-lock functionality
  static Future<void> setAutoLockTimeout(int minutes) async {
    await _secureStorage.write(key: _lockTimeoutKey, value: minutes.toString());
  }

  static Future<int> getAutoLockTimeout() async {
    final timeout = await _secureStorage.read(key: _lockTimeoutKey);
    return int.tryParse(timeout ?? '5') ?? 5; // Default 5 minutes
  }

  static Future<void> updateLastActiveTime() async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(key: _lastActiveKey, value: now);
  }

  static Future<bool> shouldAutoLock() async {
    final lastActiveStr = await _secureStorage.read(key: _lastActiveKey);
    if (lastActiveStr == null) return true;
    
    final lastActive = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(lastActiveStr) ?? 0
    );
    final timeout = await getAutoLockTimeout();
    final lockTime = lastActive.add(Duration(minutes: timeout));
    
    return DateTime.now().isAfter(lockTime);
  }

  // Biometric authentication
  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // Data encryption
  static Future<void> _ensureEncryptionKey() async {
    final existingKey = await _secureStorage.read(key: _encryptionKeyKey);
    if (existingKey == null) {
      final key = _generateEncryptionKey();
      await _secureStorage.write(key: _encryptionKeyKey, value: key);
    }
  }

  static String _generateEncryptionKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(keyBytes);
  }

  static Future<String> getEncryptionKey() async {
    await _ensureEncryptionKey();
    return await _secureStorage.read(key: _encryptionKeyKey) ?? '';
  }

  static String encryptData(String data, String key) {
    final keyBytes = base64Decode(key);
    final dataBytes = utf8.encode(data);
    
    // Simple XOR encryption (for demo - in production use AES)
    final encrypted = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64Encode(encrypted);
  }

  static String decryptData(String encryptedData, String key) {
    final keyBytes = base64Decode(key);
    final encryptedBytes = base64Decode(encryptedData);
    
    // Simple XOR decryption
    final decrypted = <int>[];
    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }

  // Clear all security data
  static Future<void> clearSecurityData() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _saltKey);
    await _secureStorage.delete(key: _lockTimeoutKey);
    await _secureStorage.delete(key: _lastActiveKey);
    await _secureStorage.delete(key: _encryptionKeyKey);
  }
}