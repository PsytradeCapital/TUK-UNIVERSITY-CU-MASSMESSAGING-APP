import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'lib/services/migration_tool.dart';
import 'lib/services/data_migration_service.dart';

/// Simple test script to validate migration tool functionality
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Testing Data Migration Tool...');
  
  final migrationTool = MigrationTool();
  
  // Test 1: Check authentication status
  print('\n1. Testing authentication status...');
  final isAuthenticated = migrationTool.isAuthenticated;
  print('Authenticated: $isAuthenticated');
  
  // Test 2: Get migration status
  print('\n2. Testing migration status...');
  try {
    final status = await migrationTool.getMigrationStatus();
    print('Migration Status:');
    print('  - Authenticated: ${status.isAuthenticated}');
    print('  - Local Data Exists: ${status.localDataExists}');
    print('  - Cloud Data Exists: ${status.cloudDataExists}');
    print('  - Local Attendees: ${status.localAttendeesCount}');
    print('  - Local Messages: ${status.localMessageLogsCount}');
    print('  - Local Services: ${status.localServicesCount}');
  } catch (e) {
    print('Error getting migration status: $e');
  }
  
  // Test 3: Validate sample JSON file
  print('\n3. Testing JSON validation...');
  try {
    final sampleJson = {
      'exportedAt': DateTime.now().toIso8601String(),
      'exportedBy': 'test-user',
      'version': '1.0',
      'attendees': [
        {
          'name': 'Test User',
          'phoneNumber': '+254712345678',
          'location': 'Nairobi',
          'category': 'student',
          'yearOfStudy': '3rd Year',
        }
      ],
      'messageLogs': [],
      'services': [],
    };
    
    // Create temporary test file
    final tempFile = File('test_export.json');
    await tempFile.writeAsString(json.encode(sampleJson));
    
    final validation = await migrationTool.validateImportFile('test_export.json');
    print('Validation Result:');
    print('  - Valid: ${validation.isValid}');
    print('  - Total Items: ${validation.totalItems}');
    print('  - Attendees: ${validation.attendeesCount}');
    print('  - Version: ${validation.version}');
    
    // Clean up
    await tempFile.delete();
  } catch (e) {
    print('Error validating JSON: $e');
  }
  
  // Test 4: Test cleanup functionality
  print('\n4. Testing cleanup functionality...');
  try {
    final deletedCount = await migrationTool.cleanupOldExports(daysOld: 30);
    print('Deleted $deletedCount old export files');
  } catch (e) {
    print('Error during cleanup: $e');
  }
  
  print('\nMigration tool tests completed!');
}