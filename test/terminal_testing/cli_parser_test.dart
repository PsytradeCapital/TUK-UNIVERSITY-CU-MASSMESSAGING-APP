import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/terminal_testing/cli/cli_parser.dart';
import 'property_test_utils.dart';

void main() {
  group('CLI Parser Tests', () {
    group('Property Tests', () {
      test('Property 15: Invalid Input Handling - **Feature: terminal-testing-framework, Property 15: Invalid Input Handling**', () {
        // **Validates: Requirements 5.5, 6.5**
        
        // Test specific known invalid argument patterns
        final invalidArgSets = [
          ['--invalid-option'],
          ['--category'],  // Missing value
          ['--timeout'],   // Missing value  
          ['--timeout', 'invalid'],  // Invalid timeout value
          ['--timeout', '-5'],       // Negative timeout
          ['--category', 'invalid-category'],  // Invalid category
          ['--verbose', '--quiet'],  // Conflicting options
          ['--unknown-flag'],
        ];
        
        for (final invalidArgs in invalidArgSets) {
          expect(
            () => CliParser.parseArguments(invalidArgs),
            throwsA(isA<ArgumentError>()),
            reason: 'Arguments $invalidArgs should throw ArgumentError',
          );
        }
      });
      
      test('Valid arguments should always parse successfully', () {
        PropertyTestUtils.runPropertyTest(
          description: 'Valid CLI arguments should always parse without errors',
          iterations: 100,
          property: () {
            // Generate valid argument combinations
            final args = <String>[];
            
            // Randomly add valid options
            if (PropertyTestUtils.randomBool()) {
              args.add('--verbose');
            } else if (PropertyTestUtils.randomBool()) {
              args.add('--quiet');
            }
            
            if (PropertyTestUtils.randomBool()) {
              args.addAll(['--category', 'auth']);
            }
            
            if (PropertyTestUtils.randomBool()) {
              args.addAll(['--timeout', '60']);
            }
            
            if (PropertyTestUtils.randomBool()) {
              args.add('--dry-run');
            }
            
            try {
              final config = CliParser.parseArguments(args);
              // Basic validation that config is created properly
              return config != null;
            } catch (e) {
              // Valid arguments should not throw exceptions
              return false;
            }
          },
        );
      });
    });
    
    group('Unit Tests', () {
      test('should parse empty arguments', () {
        final config = CliParser.parseArguments([]);
        
        expect(config.categories, isNull);
        expect(config.verbose, isFalse);
        expect(config.quiet, isFalse);
        expect(config.timeout, isNull);
        expect(config.dryRun, isFalse);
        expect(config.showHelp, isFalse);
      });
      
      test('should parse help flag', () {
        final config = CliParser.parseArguments(['--help']);
        expect(config.showHelp, isTrue);
      });
      
      test('should parse short help flag', () {
        final config = CliParser.parseArguments(['-h']);
        expect(config.showHelp, isTrue);
      });
      
      test('should parse verbose flag', () {
        final config = CliParser.parseArguments(['--verbose']);
        expect(config.verbose, isTrue);
      });
      
      test('should parse short verbose flag', () {
        final config = CliParser.parseArguments(['-v']);
        expect(config.verbose, isTrue);
      });
      
      test('should parse quiet flag', () {
        final config = CliParser.parseArguments(['--quiet']);
        expect(config.quiet, isTrue);
      });
      
      test('should parse short quiet flag', () {
        final config = CliParser.parseArguments(['-q']);
        expect(config.quiet, isTrue);
      });
      
      test('should parse dry-run flag', () {
        final config = CliParser.parseArguments(['--dry-run']);
        expect(config.dryRun, isTrue);
      });
      
      test('should parse valid category', () {
        final config = CliParser.parseArguments(['--category', 'auth']);
        expect(config.categories, equals(['auth']));
      });
      
      test('should parse short category flag', () {
        final config = CliParser.parseArguments(['-c', 'auth']);
        expect(config.categories, equals(['auth']));
      });
      
      test('should parse multiple categories', () {
        final config = CliParser.parseArguments(['-c', 'auth', '-c', 'sync']);
        expect(config.categories, equals(['auth', 'sync']));
      });
      
      test('should parse valid timeout', () {
        final config = CliParser.parseArguments(['--timeout', '60']);
        expect(config.timeout, equals(const Duration(seconds: 60)));
      });
      
      test('should parse short timeout flag', () {
        final config = CliParser.parseArguments(['-t', '120']);
        expect(config.timeout, equals(const Duration(seconds: 120)));
      });
      
      test('should parse file flag', () {
        // Create a temporary test file for this test
        final testFile = 'test_file_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file');
        
        try {
          final config = CliParser.parseArguments(['--file', testFile]);
          expect(config.testFile, equals(testFile));
        } finally {
          // Clean up
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should parse short file flag', () {
        // Create a temporary test file for this test
        final testFile = 'test_file2_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file');
        
        try {
          final config = CliParser.parseArguments(['-f', testFile]);
          expect(config.testFile, equals(testFile));
        } finally {
          // Clean up
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should parse positional test file argument', () {
        // Create a temporary test file for this test
        final testFile = 'positional_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file');
        
        try {
          final config = CliParser.parseArguments([testFile]);
          expect(config.testFile, equals(testFile));
        } finally {
          // Clean up
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should throw ArgumentError for invalid category', () {
        expect(
          () => CliParser.parseArguments(['--category', 'invalid']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for missing category value', () {
        expect(
          () => CliParser.parseArguments(['--category']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for invalid timeout', () {
        expect(
          () => CliParser.parseArguments(['--timeout', 'invalid']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for negative timeout', () {
        expect(
          () => CliParser.parseArguments(['--timeout', '-5']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for zero timeout', () {
        expect(
          () => CliParser.parseArguments(['--timeout', '0']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for excessive timeout', () {
        expect(
          () => CliParser.parseArguments(['--timeout', '3601']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for conflicting verbose and quiet', () {
        expect(
          () => CliParser.parseArguments(['--verbose', '--quiet']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for unknown option', () {
        expect(
          () => CliParser.parseArguments(['--unknown']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for non-existent test file', () {
        expect(
          () => CliParser.parseArguments(['--file', 'non_existent_test.dart']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for non-test file', () {
        // Create a temporary non-test file
        final nonTestFile = 'not_a_test.dart';
        final file = File(nonTestFile);
        file.writeAsStringSync('// Not a test file');
        
        try {
          expect(
            () => CliParser.parseArguments(['--file', nonTestFile]),
            throwsA(isA<ArgumentError>()),
          );
        } finally {
          // Clean up
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should throw ArgumentError for missing file value', () {
        expect(
          () => CliParser.parseArguments(['--file']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for missing timeout value', () {
        expect(
          () => CliParser.parseArguments(['--timeout']),
          throwsA(isA<ArgumentError>()),
        );
      });
      
      test('should throw ArgumentError for category and file combination', () {
        // Create a temporary test file
        final testFile = 'combo_test.dart';
        final file = File(testFile);
        file.writeAsStringSync('// Test file');
        
        try {
          expect(
            () => CliParser.parseArguments(['--category', 'auth', '--file', testFile]),
            throwsA(isA<ArgumentError>()),
          );
        } finally {
          // Clean up
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });
      
      test('should throw ArgumentError for multiple positional files', () {
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
            throwsA(isA<ArgumentError>()),
          );
        } finally {
          // Clean up
          if (file1.existsSync()) file1.deleteSync();
          if (file2.existsSync()) file2.deleteSync();
        }
      });
      
      test('should parse complex valid argument combinations', () {
        final config = CliParser.parseArguments([
          '--verbose',
          '--category', 'auth',
          '--category', 'sync', 
          '--timeout', '120',
          '--dry-run'
        ]);
        
        expect(config.verbose, isTrue);
        expect(config.categories, equals(['auth', 'sync']));
        expect(config.timeout, equals(const Duration(seconds: 120)));
        expect(config.dryRun, isTrue);
        expect(config.quiet, isFalse);
        expect(config.showHelp, isFalse);
      });
    });
  });
}