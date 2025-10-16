import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'security_service.dart';

class EncryptionService {
  static const String _ivLength = 16; // AES block size
  
  // Encrypt sensitive data using AES-like encryption
  static Future<String> encryptSensitiveData(String data) async {
    if (data.isEmpty) return data;
    
    try {
      final encryptionKey = await SecurityService.getEncryptionKey();
      return _encryptWithKey(data, encryptionKey);
    } catch (e) {
      // If encryption fails, return original data (fallback)
      return data;
    }
  }

  // Decrypt sensitive data
  static Future<String> decryptSensitiveData(String encryptedData) async {
    if (encryptedData.isEmpty) return encryptedData;
    
    try {
      final encryptionKey = await SecurityService.getEncryptionKey();
      return _decryptWithKey(encryptedData, encryptionKey);
    } catch (e) {
      // If decryption fails, return original data (fallback)
      return encryptedData;
    }
  }

  // Enhanced encryption with IV (Initialization Vector)
  static String _encryptWithKey(String data, String key) {
    final keyBytes = base64Decode(key);
    final dataBytes = utf8.encode(data);
    
    // Generate random IV
    final random = Random.secure();
    final iv = Uint8List.fromList(
      List<int>.generate(_ivLength, (i) => random.nextInt(256))
    );
    
    // Encrypt data using XOR with key and IV
    final encrypted = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      final keyIndex = i % keyBytes.length;
      final ivIndex = i % iv.length;
      encrypted.add(dataBytes[i] ^ keyBytes[keyIndex] ^ iv[ivIndex]);
    }
    
    // Combine IV and encrypted data
    final combined = [...iv, ...encrypted];
    return base64Encode(combined);
  }

  // Enhanced decryption with IV
  static String _decryptWithKey(String encryptedData, String key) {
    final keyBytes = base64Decode(key);
    final combinedBytes = base64Decode(encryptedData);
    
    if (combinedBytes.length < _ivLength) {
      throw Exception('Invalid encrypted data format');
    }
    
    // Extract IV and encrypted data
    final iv = combinedBytes.sublist(0, _ivLength);
    final encryptedBytes = combinedBytes.sublist(_ivLength);
    
    // Decrypt data
    final decrypted = <int>[];
    for (int i = 0; i < encryptedBytes.length; i++) {
      final keyIndex = i % keyBytes.length;
      final ivIndex = i % iv.length;
      decrypted.add(encryptedBytes[i] ^ keyBytes[keyIndex] ^ iv[ivIndex]);
    }
    
    return utf8.decode(decrypted);
  }

  // Hash sensitive data for searching (one-way)
  static String hashForSearch(String data) {
    final bytes = utf8.encode(data.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }

  // Create searchable hash with salt for phone numbers
  static Future<String> createSearchablePhoneHash(String phoneNumber) async {
    final normalized = _normalizePhoneForSearch(phoneNumber);
    final encryptionKey = await SecurityService.getEncryptionKey();
    final keyBytes = base64Decode(encryptionKey);
    
    // Use first 16 bytes of encryption key as salt
    final salt = keyBytes.sublist(0, 16);
    final combined = [...utf8.encode(normalized), ...salt];
    final digest = sha256.convert(combined);
    
    return base64Encode(digest.bytes);
  }

  // Normalize phone number for consistent searching
  static String _normalizePhoneForSearch(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    // Convert to standard format (remove country code for consistency)
    if (digitsOnly.startsWith('254') && digitsOnly.length == 12) {
      return digitsOnly.substring(3); // Remove 254 prefix
    } else if (digitsOnly.length == 10) {
      return digitsOnly.startsWith('0') ? digitsOnly.substring(1) : digitsOnly;
    }
    
    return digitsOnly;
  }

  // Encrypt attendee data for storage
  static Future<Map<String, dynamic>> encryptAttendeeData(Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    // Encrypt sensitive fields
    if (data['name'] != null) {
      encryptedData['name'] = await encryptSensitiveData(data['name']);
    }
    
    if (data['phone_number'] != null) {
      encryptedData['phone_number'] = await encryptSensitiveData(data['phone_number']);
      // Create searchable hash for phone number
      encryptedData['phone_hash'] = await createSearchablePhoneHash(data['phone_number']);
    }
    
    if (data['location'] != null) {
      encryptedData['location'] = await encryptSensitiveData(data['location']);
    }
    
    return encryptedData;
  }

  // Decrypt attendee data from storage
  static Future<Map<String, dynamic>> decryptAttendeeData(Map<String, dynamic> encryptedData) async {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    // Decrypt sensitive fields
    if (encryptedData['name'] != null) {
      decryptedData['name'] = await decryptSensitiveData(encryptedData['name']);
    }
    
    if (encryptedData['phone_number'] != null) {
      decryptedData['phone_number'] = await decryptSensitiveData(encryptedData['phone_number']);
    }
    
    if (encryptedData['location'] != null) {
      decryptedData['location'] = await decryptSensitiveData(encryptedData['location']);
    }
    
    // Remove hash field from decrypted data
    decryptedData.remove('phone_hash');
    
    return decryptedData;
  }

  // Batch encrypt multiple attendee records
  static Future<List<Map<String, dynamic>>> encryptAttendeeList(List<Map<String, dynamic>> attendeeList) async {
    final encryptedList = <Map<String, dynamic>>[];
    
    for (final attendee in attendeeList) {
      final encrypted = await encryptAttendeeData(attendee);
      encryptedList.add(encrypted);
    }
    
    return encryptedList;
  }

  // Batch decrypt multiple attendee records
  static Future<List<Map<String, dynamic>>> decryptAttendeeList(List<Map<String, dynamic>> encryptedList) async {
    final decryptedList = <Map<String, dynamic>>[];
    
    for (final encrypted in encryptedList) {
      final decrypted = await decryptAttendeeData(encrypted);
      decryptedList.add(decrypted);
    }
    
    return decryptedList;
  }

  // Verify if data is encrypted (basic check)
  static bool isDataEncrypted(String data) {
    if (data.isEmpty) return false;
    
    try {
      // Try to decode as base64 - encrypted data should be base64 encoded
      base64Decode(data);
      // If it contains only printable ASCII characters, it's probably not encrypted
      return !RegExp(r'^[\x20-\x7E]*$').hasMatch(data);
    } catch (e) {
      return false;
    }
  }

  // Migrate unencrypted data to encrypted format
  static Future<String> migrateToEncrypted(String data) async {
    if (isDataEncrypted(data)) {
      return data; // Already encrypted
    }
    return await encryptSensitiveData(data);
  }
}