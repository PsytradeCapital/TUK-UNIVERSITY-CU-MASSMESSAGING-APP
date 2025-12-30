import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/terminal_testing/cli/cli_parser.dart';

void main() {
  group('CLI Help System Tests', () {
    group('Help Display Tests', () {
      test('should have displayUsage method that does not throw', () {
        // Test that displayUsage method exists and can be called
        expect(() => CliParser.displayUsage(), returnsNormally);
      });
      
      test('should have displayUsageError method for error handling', () {
        // Test that displayUsageError method exists
        // We can't easily test the output without complex mocking,
        // but we can verify it throws the expected exception
        expect(
          () => CliParser.displayUsageErrorTestable('Test error'),
          throwsA(isA<ExitException>()),
        );
      });
    });
    
    group('Error Message Tests', () {
      test('should provide specific error for invalid category with suggestions', () {
        expect(
          () => CliParser.parseArguments(['--category', 'invalid-cat']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Invalid category: "invalid-cat"') &&
              e.message.contains('Valid categories:')
            )
          ),
        );
      });
      
      test('should provide specific error for missing category value', () {
        expect(
          () => CliParser.parseArguments(['--category']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('--category requires a value') &&
              e.message.contains('Available categories:')
            )
          ),
        );
      });
      
      test('should provide specific error for invalid timeout with example', () {
        expect(
          () => CliParser.parseArguments(['--timeout', 'abc']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Timeout must be a positive integer') &&
              e.message.contains('Got: "abc"')
            )
          ),
        );
      });
      
      test('should provide specific error for excessive timeout', () {
        expect(
          () => CliParser.parseArguments(['--timeout', '5000']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Timeout cannot exceed 3600 seconds') &&
              e.message.contains('Got: 5000')
            )
          ),
        );
      });
      
      test('should provide specific error for non-existent file', () {
        expect(
          () => CliParser.parseArguments(['--file', 'missing_test.dart']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Test file not found: "missing_test.dart"')
            )
          ),
        );
      });
      
      test('should provide specific error for non-test file', () {
        // Create a temporary non-test file with a name that doesn't end with _test.dart
        final nonTestFile = 'not_a_test_file.dart';
        final file = File(nonTestFile);
        file.writeAsStringSync('// Not a test file');
        
        try {
          expect(
            () => CliParser.parseArguments(['--file', nonTestFile]),
            throwsA(
              predicate((e) => 
                e is ArgumentError && 
                e.message.contains('File must be a test file (ending with _test.dart)') &&
                e.message.contains('"$nonTestFile"')
              )
            ),
          );
        } finally {
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should provide specific error for conflicting options', () {
        expect(
          () => CliParser.parseArguments(['--verbose', '--quiet']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Cannot use both --verbose and --quiet options')
            )
          ),
        );
      });
      
      test('should provide specific error for unknown option with suggestion', () {
        expect(
          () => CliParser.parseArguments(['--unknown-flag']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Unknown option: "--unknown-flag"') &&
              e.message.contains('Use --help for available options')
            )
          ),
        );
      });
      
      test('should provide specific error for category and file combination', () {
        // Create a temporary test file
        final testFile = 'combo_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file');
        
        try {
          expect(
            () => CliParser.parseArguments(['--category', 'auth', '--file', testFile]),
            throwsA(
              predicate((e) => 
                e is ArgumentError && 
                e.message.contains('Cannot specify both --category and --file options')
              )
            ),
          );
        } finally {
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should provide specific error for multiple positional files', () {
        // Create temporary test files
        final testFile1 = 'multi1_test.dart';
        final testFile2 = 'multi2_test.dart';
        final file1 = File(testFile1);
        final file2 = File(testFile2);
        file1.writeAsStringSync('// Test file 1');
        file2.writeAsStringSync('// Test file 2');
        
        try {
          expect(
            () => CliParser.parseArguments([testFile1, testFile2]),
            throwsA(
              predicate((e) => 
                e is ArgumentError && 
                e.message.contains('Multiple test files specified')
              )
            ),
          );
        } finally {
          if (file1.existsSync()) file1.deleteSync();
          if (file2.existsSync()) file2.deleteSync();
        }
      });
      
      test('should provide helpful error messages for missing required values', () {
        final testCases = [
          ['--timeout', 'requires a value (positive integer in seconds)'],
          ['--file', 'requires a file path'],
        ];
        
        for (final testCase in testCases) {
          final flag = testCase[0];
          final expectedMessage = testCase[1];
          
          expect(
            () => CliParser.parseArguments([flag]),
            throwsA(
              predicate((e) => 
                e is ArgumentError && 
                e.message.contains(expectedMessage)
              )
            ),
            reason: 'Flag $flag should provide helpful error message',
          );
        }
      });
    });
    
    group('Valid Categories Test', () {
      test('should have all expected valid categories', () {
        final expectedCategories = ['auth', 'attendance', 'sync', 'personalization', 'integration'];
        
        expect(CliParser.validCategories, containsAll(expectedCategories));
        expect(CliParser.validCategories.length, equals(expectedCategories.length));
      });
      
      test('should accept all valid categories', () {
        for (final category in CliParser.validCategories) {
          expect(
            () => CliParser.parseArguments(['--category', category]),
            returnsNormally,
            reason: 'Category $category should be valid',
          );
        }
      });
    });
  });
}