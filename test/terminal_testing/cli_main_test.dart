import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/terminal_testing/cli/cli_parser.dart';
import '../../lib/terminal_testing/core/terminal_test_runner.dart';

void main() {
  group('CLI Main Integration Tests', () {
    group('Command Parsing Integration', () {
      test('should handle help command without errors', () {
        final config = CliParser.parseArguments(['--help']);
        expect(config.showHelp, isTrue);
        
        // Test that help display works
        expect(() => CliParser.displayUsage(), returnsNormally);
      });
      
      test('should handle short help command without errors', () {
        final config = CliParser.parseArguments(['-h']);
        expect(config.showHelp, isTrue);
        
        // Test that help display works
        expect(() => CliParser.displayUsage(), returnsNormally);
      });
      
      test('should create valid config for all supported argument combinations', () {
        final testCases = [
          // Basic flags
          ['--verbose'],
          ['--quiet'],
          ['--dry-run'],
          
          // Category combinations
          ['--category', 'auth'],
          ['--category', 'auth', '--category', 'sync'],
          ['-c', 'attendance'],
          
          // Timeout variations
          ['--timeout', '30'],
          ['--timeout', '60'],
          ['--timeout', '3600'],
          ['-t', '120'],
          
          // Complex combinations
          ['--verbose', '--category', 'auth', '--timeout', '60'],
          ['--quiet', '--dry-run'],
          ['-v', '-c', 'sync', '-t', '90'],
        ];
        
        for (final args in testCases) {
          expect(
            () => CliParser.parseArguments(args),
            returnsNormally,
            reason: 'Arguments $args should parse successfully',
          );
        }
      });
    });
    
    group('Error Message Formatting Tests', () {
      test('should format error messages consistently', () {
        final errorTestCases = [
          {
            'args': ['--category', 'invalid'],
            'expectedContains': ['Invalid category', 'Valid categories:'],
          },
          {
            'args': ['--timeout', 'abc'],
            'expectedContains': ['Timeout must be a positive integer', 'Got: "abc"'],
          },
          {
            'args': ['--timeout', '5000'],
            'expectedContains': ['Timeout cannot exceed 3600 seconds', 'Got: 5000'],
          },
          {
            'args': ['--verbose', '--quiet'],
            'expectedContains': ['Cannot use both --verbose and --quiet options'],
          },
          {
            'args': ['--unknown-flag'],
            'expectedContains': ['Unknown option: "--unknown-flag"', 'Use --help for available options'],
          },
        ];
        
        for (final testCase in errorTestCases) {
          try {
            CliParser.parseArguments(testCase['args'] as List<String>);
            fail('Expected ArgumentError for args: ${testCase['args']}');
          } catch (e) {
            expect(e, isA<ArgumentError>());
            final message = e.toString();
            
            for (final expectedText in testCase['expectedContains'] as List<String>) {
              expect(
                message,
                contains(expectedText),
                reason: 'Error message should contain "$expectedText" for args: ${testCase['args']}',
              );
            }
          }
        }
      });
      
      test('should provide helpful error messages for missing values', () {
        final missingValueTests = [
          {
            'args': ['--category'],
            'expectedContains': ['--category requires a value', 'Available categories:'],
          },
          {
            'args': ['--timeout'],
            'expectedContains': ['--timeout requires a value', 'positive integer in seconds'],
          },
          {
            'args': ['--file'],
            'expectedContains': ['--file requires a file path'],
          },
        ];
        
        for (final testCase in missingValueTests) {
          try {
            CliParser.parseArguments(testCase['args'] as List<String>);
            fail('Expected ArgumentError for args: ${testCase['args']}');
          } catch (e) {
            expect(e, isA<ArgumentError>());
            final message = e.toString();
            
            for (final expectedText in testCase['expectedContains'] as List<String>) {
              expect(
                message,
                contains(expectedText),
                reason: 'Error message should contain "$expectedText" for args: ${testCase['args']}',
              );
            }
          }
        }
      });
      
      test('should format file-related error messages clearly', () {
        // Test non-existent file
        expect(
          () => CliParser.parseArguments(['--file', 'missing_test.dart']),
          throwsA(
            predicate((e) => 
              e is ArgumentError && 
              e.message.contains('Test file not found: "missing_test.dart"')
            )
          ),
        );
        
        // Test non-test file - use a unique name to avoid conflicts
        final nonTestFile = 'cli_test_non_test_${DateTime.now().millisecondsSinceEpoch}.dart';
        final file = File(nonTestFile);
        
        // Clean up any existing file first
        if (file.existsSync()) {
          file.deleteSync();
        }
        
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
    });
    
    group('Help Display Integration', () {
      test('should display comprehensive usage information', () {
        // Capture output by testing that displayUsage doesn't throw
        expect(() => CliParser.displayUsage(), returnsNormally);
      });
      
      test('should display error with usage information', () {
        // Test the testable version that throws instead of calling exit
        expect(
          () => CliParser.displayUsageErrorTestable('Test error message'),
          throwsA(isA<ExitException>()),
        );
      });
      
      test('should include all valid categories in help output', () {
        // This test verifies that the help system is consistent with valid categories
        final expectedCategories = ['auth', 'attendance', 'sync', 'personalization', 'integration'];
        
        // Verify that all expected categories are in the valid categories list
        expect(CliParser.validCategories, containsAll(expectedCategories));
        
        // Verify that each category can be parsed successfully
        for (final category in expectedCategories) {
          expect(
            () => CliParser.parseArguments(['--category', category]),
            returnsNormally,
            reason: 'Category $category should be valid and parseable',
          );
        }
      });
    });
    
    group('Configuration Validation', () {
      test('should validate timeout ranges correctly', () {
        // Valid timeouts
        final validTimeouts = ['1', '30', '60', '300', '3600'];
        for (final timeout in validTimeouts) {
          expect(
            () => CliParser.parseArguments(['--timeout', timeout]),
            returnsNormally,
            reason: 'Timeout $timeout should be valid',
          );
        }
        
        // Invalid timeouts
        final invalidTimeouts = ['0', '-1', '3601', 'abc', '1.5'];
        for (final timeout in invalidTimeouts) {
          expect(
            () => CliParser.parseArguments(['--timeout', timeout]),
            throwsA(isA<ArgumentError>()),
            reason: 'Timeout $timeout should be invalid',
          );
        }
      });
      
      test('should validate category combinations', () {
        // Valid single categories
        for (final category in CliParser.validCategories) {
          expect(
            () => CliParser.parseArguments(['--category', category]),
            returnsNormally,
            reason: 'Single category $category should be valid',
          );
        }
        
        // Valid multiple categories
        expect(
          () => CliParser.parseArguments(['--category', 'auth', '--category', 'sync']),
          returnsNormally,
        );
        
        // Invalid categories
        final invalidCategories = ['invalid', 'test', 'unknown', ''];
        for (final category in invalidCategories) {
          expect(
            () => CliParser.parseArguments(['--category', category]),
            throwsA(isA<ArgumentError>()),
            reason: 'Invalid category $category should throw error',
          );
        }
      });
      
      test('should validate conflicting options', () {
        final conflictingCombinations = [
          ['--verbose', '--quiet'],
          ['-v', '-q'],
          ['--verbose', '-q'],
          ['-v', '--quiet'],
        ];
        
        for (final combination in conflictingCombinations) {
          expect(
            () => CliParser.parseArguments(combination),
            throwsA(isA<ArgumentError>()),
            reason: 'Conflicting options $combination should throw error',
          );
        }
      });
      
      test('should validate file and category exclusivity', () {
        // Create a temporary test file
        final testFile = 'exclusive_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file');
        
        try {
          final conflictingCombinations = [
            ['--category', 'auth', '--file', testFile],
            ['-c', 'sync', '-f', testFile],
            ['--file', testFile, '--category', 'attendance'],
          ];
          
          for (final combination in conflictingCombinations) {
            expect(
              () => CliParser.parseArguments(combination),
              throwsA(isA<ArgumentError>()),
              reason: 'File and category combination $combination should throw error',
            );
          }
        } finally {
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
    });
    
    group('Edge Cases and Robustness', () {
      test('should handle empty argument list', () {
        final config = CliParser.parseArguments([]);
        
        expect(config.categories, isNull);
        expect(config.verbose, isFalse);
        expect(config.quiet, isFalse);
        expect(config.timeout, isNull);
        expect(config.dryRun, isFalse);
        expect(config.showHelp, isFalse);
        expect(config.testFile, isNull);
      });
      
      test('should handle whitespace in arguments', () {
        // Create test file with spaces in content (but not name)
        final testFile = 'whitespace_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file with spaces');
        
        try {
          expect(
            () => CliParser.parseArguments(['--file', testFile]),
            returnsNormally,
          );
        } finally {
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should handle maximum valid timeout', () {
        final config = CliParser.parseArguments(['--timeout', '3600']);
        expect(config.timeout, equals(const Duration(seconds: 3600)));
      });
      
      test('should handle minimum valid timeout', () {
        final config = CliParser.parseArguments(['--timeout', '1']);
        expect(config.timeout, equals(const Duration(seconds: 1)));
      });
      
      test('should handle all flags together (non-conflicting)', () {
        final config = CliParser.parseArguments([
          '--verbose',
          '--dry-run',
          '--category', 'auth',
          '--timeout', '60',
        ]);
        
        expect(config.verbose, isTrue);
        expect(config.dryRun, isTrue);
        expect(config.categories, equals(['auth']));
        expect(config.timeout, equals(const Duration(seconds: 60)));
        expect(config.quiet, isFalse);
      });
    });
  });
}