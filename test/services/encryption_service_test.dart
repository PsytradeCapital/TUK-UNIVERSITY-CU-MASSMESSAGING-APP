import 'package:flutter_test/flutter_test.dart';
import 'package:christian_union_attendance_app/services/encryption_service.dart';

void main() {
  group('EncryptionService Cloud Encryption Tests', () {
    test('should encrypt and decrypt Firestore document data', () async {
      // Test data
      final testData = {
        'name': 'John Doe',
        'phoneNumber': '+254712345678',
        'location': 'Nairobi',
        'yearOfStudy': 'Year 2', // This should not be encrypted
      };
      
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      
      // Encrypt document
      final encryptedData = await EncryptionService.encryptFirestoreDocument(
        testData, 
        sensitiveFields,
      );
      
      // Verify sensitive fields are encrypted
      expect(encryptedData['name'], isNot(equals(testData['name'])));
      expect(encryptedData['phoneNumber'], isNot(equals(testData['phoneNumber'])));
      expect(encryptedData['location'], isNot(equals(testData['location'])));
      
      // Verify non-sensitive fields are not encrypted
      expect(encryptedData['yearOfStudy'], equals(testData['yearOfStudy']));
      
      // Decrypt document
      final decryptedData = await EncryptionService.decryptFirestoreDocument(
        encryptedData,
        sensitiveFields,
      );
      
      // Verify decryption restores original data
      expect(decryptedData['name'], equals(testData['name']));
      expect(decryptedData['phoneNumber'], equals(testData['phoneNumber']));
      expect(decryptedData['location'], equals(testData['location']));
      expect(decryptedData['yearOfStudy'], equals(testData['yearOfStudy']));
    });

    test('should encrypt and decrypt message log data', () async {
      // Test data with sensitive message
      final testData = {
        'message': 'Hello John Doe, your number +254712345678 is registered',
        'attendeeId': '123',
        'serviceId': 1,
      };
      
      // Encrypt message log
      final encryptedData = await EncryptionService.encryptMessageLogData(testData);
      
      // Message should be encrypted because it contains sensitive info
      expect(encryptedData['message'], isNot(equals(testData['message'])));
      expect(encryptedData['isMessageEncrypted'], isTrue);
      
      // Decrypt message log
      final decryptedData = await EncryptionService.decryptMessageLogData(encryptedData);
      
      // Verify decryption restores original message
      expect(decryptedData['message'], equals(testData['message']));
      expect(decryptedData.containsKey('isMessageEncrypted'), isFalse);
    });

    test('should handle non-sensitive message data correctly', () async {
      // Test data without sensitive information
      final testData = {
        'message': 'Welcome to the service!',
        'attendeeId': '123',
        'serviceId': 1,
      };
      
      // Encrypt message log
      final encryptedData = await EncryptionService.encryptMessageLogData(testData);
      
      // Message should not be encrypted because it doesn't contain sensitive info
      expect(encryptedData['message'], equals(testData['message']));
      expect(encryptedData['isMessageEncrypted'], isFalse);
      
      // Decrypt message log
      final decryptedData = await EncryptionService.decryptMessageLogData(encryptedData);
      
      // Verify message remains unchanged
      expect(decryptedData['message'], equals(testData['message']));
    });

    test('should validate cloud encryption comprehensively', () async {
      // Run comprehensive validation
      final validationResults = await EncryptionService.validateCloudEncryption();
      
      // Check that all tests passed
      expect(validationResults['allTestsPassed'], isTrue);
      expect(validationResults['attendeeEncryptionValid'], isTrue);
      expect(validationResults['messageEncryptionValid'], isTrue);
      expect(validationResults['firestoreEncryptionValid'], isTrue);
      expect(validationResults['fileEncryptionValid'], isTrue);
      expect(validationResults['backupEncryptionValid'], isTrue);
    });

    test('should encrypt and decrypt file data', () async {
      // Test file data
      final testFileData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      
      // Encrypt file
      final encryptedFile = await EncryptionService.encryptFileData(testFileData);
      
      // Verify file is encrypted (different from original)
      expect(encryptedFile, isNot(equals(testFileData)));
      expect(encryptedFile.length, greaterThan(testFileData.length)); // IV adds length
      
      // Decrypt file
      final decryptedFile = await EncryptionService.decryptFileData(encryptedFile);
      
      // Verify decryption restores original file
      expect(decryptedFile, equals(testFileData));
    });

    test('should create and restore encrypted backup', () async {
      // Test backup data
      final testData = {
        'attendees': [
          {'name': 'John Doe', 'phone': '+254712345678'},
          {'name': 'Jane Smith', 'phone': '+254787654321'},
        ],
        'messages': [
          {'message': 'Welcome!', 'sent': true},
        ],
      };
      
      // Create encrypted backup
      final encryptedBackup = await EncryptionService.createEncryptedBackup(testData);
      
      // Verify backup is encrypted
      expect(encryptedBackup['encryptedData'], isNotNull);
      expect(encryptedBackup['backupVersion'], equals('1.0'));
      expect(encryptedBackup['createdAt'], isNotNull);
      
      // Restore from backup
      final restoredData = await EncryptionService.restoreFromEncryptedBackup(encryptedBackup);
      
      // Verify restored data matches original
      expect(restoredData['attendees'], equals(testData['attendees']));
      expect(restoredData['messages'], equals(testData['messages']));
    });
  });
}