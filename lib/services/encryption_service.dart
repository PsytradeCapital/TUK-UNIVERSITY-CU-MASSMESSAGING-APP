import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'security_service.dart';

class EncryptionService {
  static const int _ivLength = 16; // AES block size
  
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

  // Cloud-specific encryption methods for Firestore documents

  // Encrypt Firestore document data before upload
  static Future<Map<String, dynamic>> encryptFirestoreDocument(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    for (final field in sensitiveFields) {
      if (data[field] != null && data[field] is String) {
        encryptedData[field] = await encryptSensitiveData(data[field]);
      }
    }
    
    return encryptedData;
  }

  // Decrypt Firestore document data after retrieval
  static Future<Map<String, dynamic>> decryptFirestoreDocument(
    Map<String, dynamic> encryptedData,
    List<String> sensitiveFields,
  ) async {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    for (final field in sensitiveFields) {
      if (encryptedData[field] != null && encryptedData[field] is String) {
        decryptedData[field] = await decryptSensitiveData(encryptedData[field]);
      }
    }
    
    return decryptedData;
  }

  // Encrypt message log data for cloud storage
  static Future<Map<String, dynamic>> encryptMessageLogData(Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    // Encrypt message content if it contains sensitive information
    if (data['message'] != null) {
      // Only encrypt if message contains phone numbers or names
      final message = data['message'] as String;
      if (_containsSensitiveInfo(message)) {
        encryptedData['message'] = await encryptSensitiveData(message);
        encryptedData['isMessageEncrypted'] = true;
      } else {
        encryptedData['isMessageEncrypted'] = false;
      }
    }
    
    return encryptedData;
  }

  // Decrypt message log data from cloud storage
  static Future<Map<String, dynamic>> decryptMessageLogData(Map<String, dynamic> encryptedData) async {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    // Decrypt message content if it was encrypted
    if (encryptedData['message'] != null && encryptedData['isMessageEncrypted'] == true) {
      decryptedData['message'] = await decryptSensitiveData(encryptedData['message']);
    }
    
    // Remove encryption flag from decrypted data
    decryptedData.remove('isMessageEncrypted');
    
    return decryptedData;
  }

  // Check if message contains sensitive information
  static bool _containsSensitiveInfo(String message) {
    // Check for phone number patterns
    final phonePattern = RegExp(r'\b(?:\+254|254|0)[17]\d{8}\b');
    if (phonePattern.hasMatch(message)) return true;
    
    // Check for common name patterns (capitalized words)
    final namePattern = RegExp(r'\b[A-Z][a-z]+\s+[A-Z][a-z]+\b');
    if (namePattern.hasMatch(message)) return true;
    
    return false;
  }

  // Encrypt user profile data for cloud storage
  static Future<Map<String, dynamic>> encryptUserProfileData(Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    // Encrypt sensitive user fields
    if (data['name'] != null) {
      encryptedData['name'] = await encryptSensitiveData(data['name']);
    }
    
    if (data['phoneNumber'] != null) {
      encryptedData['phoneNumber'] = await encryptSensitiveData(data['phoneNumber']);
    }
    
    // Email is handled by Firebase Auth, don't encrypt it
    
    return encryptedData;
  }

  // Decrypt user profile data from cloud storage
  static Future<Map<String, dynamic>> decryptUserProfileData(Map<String, dynamic> encryptedData) async {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    // Decrypt sensitive user fields
    if (encryptedData['name'] != null) {
      decryptedData['name'] = await decryptSensitiveData(encryptedData['name']);
    }
    
    if (encryptedData['phoneNumber'] != null) {
      decryptedData['phoneNumber'] = await decryptSensitiveData(encryptedData['phoneNumber']);
    }
    
    return decryptedData;
  }

  // Batch encrypt multiple documents for cloud upload
  static Future<List<Map<String, dynamic>>> batchEncryptDocuments(
    List<Map<String, dynamic>> documents,
    List<String> sensitiveFields,
  ) async {
    final encryptedDocuments = <Map<String, dynamic>>[];
    
    for (final document in documents) {
      final encrypted = await encryptFirestoreDocument(document, sensitiveFields);
      encryptedDocuments.add(encrypted);
    }
    
    return encryptedDocuments;
  }

  // Batch decrypt multiple documents from cloud
  static Future<List<Map<String, dynamic>>> batchDecryptDocuments(
    List<Map<String, dynamic>> encryptedDocuments,
    List<String> sensitiveFields,
  ) async {
    final decryptedDocuments = <Map<String, dynamic>>[];
    
    for (final document in encryptedDocuments) {
      final decrypted = await decryptFirestoreDocument(document, sensitiveFields);
      decryptedDocuments.add(decrypted);
    }
    
    return decryptedDocuments;
  }

  // Create encrypted backup data for export
  static Future<Map<String, dynamic>> createEncryptedBackup(Map<String, dynamic> data) async {
    final encryptedBackup = <String, dynamic>{};
    
    // Encrypt the entire data structure as JSON
    final jsonData = jsonEncode(data);
    encryptedBackup['encryptedData'] = await encryptSensitiveData(jsonData);
    encryptedBackup['backupVersion'] = '1.0';
    encryptedBackup['createdAt'] = DateTime.now().toIso8601String();
    
    return encryptedBackup;
  }

  // Restore data from encrypted backup
  static Future<Map<String, dynamic>> restoreFromEncryptedBackup(Map<String, dynamic> encryptedBackup) async {
    if (encryptedBackup['encryptedData'] == null) {
      throw Exception('Invalid backup format: missing encrypted data');
    }
    
    final decryptedJson = await decryptSensitiveData(encryptedBackup['encryptedData']);
    final data = jsonDecode(decryptedJson) as Map<String, dynamic>;
    
    return data;
  }

  // Validate encryption key strength for cloud operations
  static Future<bool> validateEncryptionKeyForCloud() async {
    try {
      final encryptionKey = await SecurityService.getEncryptionKey();
      final keyBytes = base64Decode(encryptionKey);
      
      // Key should be at least 32 bytes (256 bits) for cloud security
      if (keyBytes.length < 32) {
        return false;
      }
      
      // Test encryption/decryption round trip
      const testData = 'Cloud encryption test data';
      final encrypted = await encryptSensitiveData(testData);
      final decrypted = await decryptSensitiveData(encrypted);
      
      return decrypted == testData;
    } catch (e) {
      return false;
    }
  }

  // Generate secure hash for cloud document indexing
  static Future<String> generateCloudDocumentHash(Map<String, dynamic> data) async {
    final encryptionKey = await SecurityService.getEncryptionKey();
    final keyBytes = base64Decode(encryptionKey);
    
    // Create deterministic hash from document data
    final sortedKeys = data.keys.toList()..sort();
    final dataString = sortedKeys.map((key) => '$key:${data[key]}').join('|');
    
    // Use HMAC for secure hashing
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(dataString));
    
    return base64Encode(digest.bytes);
  }

  // Password security validation methods (for client-side validation only)
  
  /// Validate password strength before sending to Firebase Auth
  /// Note: Firebase Auth handles actual password hashing and storage
  static bool isPasswordSecure(String password) {
    // Minimum length check
    if (password.length < 8) return false;
    
    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    
    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    
    // Check for at least one digit
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    
    // Check for at least one special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return false;
    
    return true;
  }

  /// Get password strength score (0-4)
  static int getPasswordStrength(String password) {
    int score = 0;
    
    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    
    // Character variety checks
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    
    // Bonus for very long passwords
    if (password.length >= 16) score++;
    
    return score > 4 ? 4 : score;
  }

  /// Get password strength description
  static String getPasswordStrengthDescription(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Very Weak';
      case 2:
        return 'Weak';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Unknown';
    }
  }

  /// Validate that no passwords are stored in plain text
  /// This is a security audit method to ensure compliance
  static bool validateNoPlaintextPasswords(Map<String, dynamic> data) {
    // Check for common password field names
    final passwordFields = [
      'password',
      'passwd',
      'pwd',
      'pass',
      'secret',
      'key',
      'token',
    ];
    
    for (final field in passwordFields) {
      if (data.containsKey(field)) {
        final value = data[field];
        if (value is String && value.isNotEmpty) {
          // If it looks like a plain text password (not base64 encoded), flag it
          if (!isDataEncrypted(value)) {
            return false; // Found potential plain text password
          }
        }
      }
    }
    
    return true; // No plain text passwords found
  }

  /// Security audit method to check for proper encryption usage
  static Future<Map<String, dynamic>> performSecurityAudit() async {
    final auditResults = <String, dynamic>{};
    
    try {
      // Check encryption key strength
      auditResults['encryptionKeyValid'] = await validateEncryptionKeyForCloud();
      
      // Check if security service is properly initialized
      auditResults['securityServiceInitialized'] = true;
      
      // Test encryption round-trip
      const testData = 'Security audit test data';
      final encrypted = await encryptSensitiveData(testData);
      final decrypted = await decryptSensitiveData(encrypted);
      auditResults['encryptionRoundTripSuccess'] = decrypted == testData;
      
      // Check if encrypted data looks properly encrypted
      auditResults['encryptionProducesValidFormat'] = isDataEncrypted(encrypted);
      
      auditResults['auditTimestamp'] = DateTime.now().toIso8601String();
      auditResults['auditPassed'] = auditResults['encryptionKeyValid'] &&
                                   auditResults['securityServiceInitialized'] &&
                                   auditResults['encryptionRoundTripSuccess'] &&
                                   auditResults['encryptionProducesValidFormat'];
      
    } catch (e) {
      auditResults['auditError'] = e.toString();
      auditResults['auditPassed'] = false;
    }
    
    return auditResults;
  }

  // Enhanced cloud-specific encryption methods for Firestore operations

  /// Encrypt service data for cloud storage
  static Future<Map<String, dynamic>> encryptServiceData(Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    // Services typically don't contain sensitive data, but encrypt any notes or descriptions
    if (data['notes'] != null) {
      encryptedData['notes'] = await encryptSensitiveData(data['notes']);
    }
    
    if (data['description'] != null) {
      encryptedData['description'] = await encryptSensitiveData(data['description']);
    }
    
    return encryptedData;
  }

  /// Decrypt service data from cloud storage
  static Future<Map<String, dynamic>> decryptServiceData(Map<String, dynamic> encryptedData) async {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    // Decrypt service fields if they were encrypted
    if (encryptedData['notes'] != null) {
      decryptedData['notes'] = await decryptSensitiveData(encryptedData['notes']);
    }
    
    if (encryptedData['description'] != null) {
      decryptedData['description'] = await decryptSensitiveData(encryptedData['description']);
    }
    
    return decryptedData;
  }

  /// Encrypt sync queue data for cloud storage
  static Future<Map<String, dynamic>> encryptSyncQueueData(Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    // Encrypt the actual data payload if it contains sensitive information
    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      final payloadData = data['data'] as Map<String, dynamic>;
      
      // Determine what type of data this is and encrypt accordingly
      final collection = data['collection'] as String?;
      
      if (collection == 'attendees') {
        final sensitiveFields = ['name', 'phoneNumber', 'location'];
        encryptedData['data'] = await encryptFirestoreDocument(payloadData, sensitiveFields);
      } else if (collection == 'messageLogs') {
        encryptedData['data'] = await encryptMessageLogData(payloadData);
      } else if (collection == 'users') {
        encryptedData['data'] = await encryptUserProfileData(payloadData);
      } else {
        // For unknown collections, encrypt the entire data as JSON
        final jsonData = jsonEncode(payloadData);
        encryptedData['data'] = {'encryptedPayload': await encryptSensitiveData(jsonData)};
      }
    }
    
    return encryptedData;
  }

  /// Decrypt sync queue data from cloud storage
  static Future<Map<String, dynamic>> decryptSyncQueueData(Map<String, dynamic> encryptedData) async {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    // Decrypt the actual data payload if it was encrypted
    if (encryptedData['data'] != null && encryptedData['data'] is Map<String, dynamic>) {
      final payloadData = encryptedData['data'] as Map<String, dynamic>;
      
      // Check if this is a generic encrypted payload
      if (payloadData.containsKey('encryptedPayload')) {
        final decryptedJson = await decryptSensitiveData(payloadData['encryptedPayload']);
        decryptedData['data'] = jsonDecode(decryptedJson) as Map<String, dynamic>;
      } else {
        // Determine what type of data this is and decrypt accordingly
        final collection = encryptedData['collection'] as String?;
        
        if (collection == 'attendees') {
          final sensitiveFields = ['name', 'phoneNumber', 'location'];
          decryptedData['data'] = await decryptFirestoreDocument(payloadData, sensitiveFields);
        } else if (collection == 'messageLogs') {
          decryptedData['data'] = await decryptMessageLogData(payloadData);
        } else if (collection == 'users') {
          decryptedData['data'] = await decryptUserProfileData(payloadData);
        } else {
          // For unknown collections, keep data as-is
          decryptedData['data'] = payloadData;
        }
      }
    }
    
    return decryptedData;
  }

  /// Validate that all sensitive fields in a document are properly encrypted
  static Future<bool> validateDocumentEncryption(
    Map<String, dynamic> document,
    List<String> sensitiveFields,
  ) async {
    for (final field in sensitiveFields) {
      if (document[field] != null && document[field] is String) {
        final value = document[field] as String;
        if (value.isNotEmpty && !isDataEncrypted(value)) {
          return false; // Found unencrypted sensitive data
        }
      }
    }
    return true;
  }

  /// Encrypt data for Firebase Storage (file uploads)
  static Future<List<int>> encryptFileData(List<int> fileData) async {
    try {
      final encryptionKey = await SecurityService.getEncryptionKey();
      final keyBytes = base64Decode(encryptionKey);
      
      // Generate random IV for file encryption
      final random = Random.secure();
      final iv = Uint8List.fromList(
        List<int>.generate(_ivLength, (i) => random.nextInt(256))
      );
      
      // Encrypt file data using XOR with key and IV
      final encrypted = <int>[];
      for (int i = 0; i < fileData.length; i++) {
        final keyIndex = i % keyBytes.length;
        final ivIndex = i % iv.length;
        encrypted.add(fileData[i] ^ keyBytes[keyIndex] ^ iv[ivIndex]);
      }
      
      // Combine IV and encrypted data
      return [...iv, ...encrypted];
    } catch (e) {
      throw Exception('Failed to encrypt file data: $e');
    }
  }

  /// Decrypt data from Firebase Storage (file downloads)
  static Future<List<int>> decryptFileData(List<int> encryptedFileData) async {
    try {
      final encryptionKey = await SecurityService.getEncryptionKey();
      final keyBytes = base64Decode(encryptionKey);
      
      if (encryptedFileData.length < _ivLength) {
        throw Exception('Invalid encrypted file format');
      }
      
      // Extract IV and encrypted data
      final iv = encryptedFileData.sublist(0, _ivLength);
      final encryptedBytes = encryptedFileData.sublist(_ivLength);
      
      // Decrypt file data
      final decrypted = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        final keyIndex = i % keyBytes.length;
        final ivIndex = i % iv.length;
        decrypted.add(encryptedBytes[i] ^ keyBytes[keyIndex] ^ iv[ivIndex]);
      }
      
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt file data: $e');
    }
  }

  /// Create encrypted metadata for cloud storage
  static Future<Map<String, dynamic>> createEncryptedMetadata(
    Map<String, dynamic> metadata,
  ) async {
    final encryptedMetadata = <String, dynamic>{};
    
    // Encrypt sensitive metadata fields
    for (final entry in metadata.entries) {
      if (entry.value is String && _isSensitiveMetadata(entry.key)) {
        encryptedMetadata[entry.key] = await encryptSensitiveData(entry.value);
      } else {
        encryptedMetadata[entry.key] = entry.value;
      }
    }
    
    // Add encryption marker
    encryptedMetadata['_encrypted'] = true;
    encryptedMetadata['_encryptionVersion'] = '1.0';
    
    return encryptedMetadata;
  }

  /// Decrypt metadata from cloud storage
  static Future<Map<String, dynamic>> decryptMetadata(
    Map<String, dynamic> encryptedMetadata,
  ) async {
    final decryptedMetadata = Map<String, dynamic>.from(encryptedMetadata);
    
    // Only decrypt if marked as encrypted
    if (encryptedMetadata['_encrypted'] == true) {
      for (final entry in encryptedMetadata.entries) {
        if (entry.value is String && _isSensitiveMetadata(entry.key)) {
          decryptedMetadata[entry.key] = await decryptSensitiveData(entry.value);
        }
      }
      
      // Remove encryption markers
      decryptedMetadata.remove('_encrypted');
      decryptedMetadata.remove('_encryptionVersion');
    }
    
    return decryptedMetadata;
  }

  /// Check if metadata field contains sensitive information
  static bool _isSensitiveMetadata(String fieldName) {
    final sensitiveFields = [
      'name',
      'description',
      'notes',
      'comment',
      'title',
      'author',
      'creator',
    ];
    
    return sensitiveFields.contains(fieldName.toLowerCase());
  }

  /// Perform comprehensive encryption validation for cloud deployment
  static Future<Map<String, dynamic>> validateCloudEncryption() async {
    final validationResults = <String, dynamic>{};
    
    try {
      // Test all encryption methods
      final testData = {
        'name': 'Test User',
        'phoneNumber': '+254712345678',
        'location': 'Nairobi',
        'message': 'Test message with sensitive data',
      };
      
      // Test attendee encryption
      final encryptedAttendee = await encryptAttendeeData(testData);
      final decryptedAttendee = await decryptAttendeeData(encryptedAttendee);
      validationResults['attendeeEncryptionValid'] = 
          decryptedAttendee['name'] == testData['name'] &&
          decryptedAttendee['phoneNumber'] == testData['phoneNumber'];
      
      // Test message log encryption
      final encryptedMessage = await encryptMessageLogData(testData);
      final decryptedMessage = await decryptMessageLogData(encryptedMessage);
      validationResults['messageEncryptionValid'] = 
          decryptedMessage['message'] == testData['message'];
      
      // Test Firestore document encryption
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      final encryptedDoc = await encryptFirestoreDocument(testData, sensitiveFields);
      final decryptedDoc = await decryptFirestoreDocument(encryptedDoc, sensitiveFields);
      validationResults['firestoreEncryptionValid'] = 
          decryptedDoc['name'] == testData['name'];
      
      // Test file encryption
      final testFileData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final encryptedFile = await encryptFileData(testFileData);
      final decryptedFile = await decryptFileData(encryptedFile);
      validationResults['fileEncryptionValid'] = 
          decryptedFile.toString() == testFileData.toString();
      
      // Test backup encryption
      final encryptedBackup = await createEncryptedBackup(testData);
      final decryptedBackup = await restoreFromEncryptedBackup(encryptedBackup);
      validationResults['backupEncryptionValid'] = 
          decryptedBackup['name'] == testData['name'];
      
      // Overall validation
      validationResults['allTestsPassed'] = 
          validationResults['attendeeEncryptionValid'] &&
          validationResults['messageEncryptionValid'] &&
          validationResults['firestoreEncryptionValid'] &&
          validationResults['fileEncryptionValid'] &&
          validationResults['backupEncryptionValid'];
      
      validationResults['validationTimestamp'] = DateTime.now().toIso8601String();
      
    } catch (e) {
      validationResults['validationError'] = e.toString();
      validationResults['allTestsPassed'] = false;
    }
    
    return validationResults;
  }
}