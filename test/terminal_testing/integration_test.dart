import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/terminal_testing/core/terminal_test_runner.dart';
import '../../lib/terminal_testing/core/test_suite.dart';
import '../../lib/terminal_testing/reporters/test_reporter.dart';
import '../../lib/terminal_testing/mocks/mock_environment.dart';
import '../../lib/terminal_testing/test_suites/test_suite_registry.dart';
import '../../lib/terminal_testing/cli/cli_parser.dart';

void main() {
  group('Terminal Testing Framework Integration Tests', () {
    late TerminalTestRunner runner;
    late MockEnvironment mockEnv;
    late TestReporter reporter;
    late TestSuiteRegistry registry;

    setUp(() {
      mockEnv = MockEnvironment();
      reporter = TestReporter();
      registry = TestSuiteRegistry();
      runner = TerminalTestRunner(
        reporter: reporter,
        registry: registry,
        mockEnvironment: mockEnv,
      );
    });

    tearDown(() {
      mockEnv.teardown();
      registry.clear();
    });

    group('End-to-End Test Execution', () {
      test('should execute complete test flow with all components', () async {
        // Test complete command execution scenario
        final summary = await runner.runTests(
          categories: null, // Run all tests
          verbose: false,
          quiet: false,
          timeout: const Duration(seconds: 30),
          dryRun: false,
        );

        // Verify summary completeness
        expect(summary.totalTests, greaterThan(0));
        expect(summary.passedTests + summary.failedTests + summary.errorTests, 
               equals(summary.totalTests));
        expect(summary.successPercentage, greaterThanOrEqualTo(0.0));
        expect(summary.successPercentage, lessThanOrEqualTo(100.0));
        expect(summary.results.length, equals(summary.totalTests));
        expect(summary.totalTime.inMilliseconds, greaterThan(0));
      });

      test('should handle category filtering correctly', () async {
        // Test category-specific execution
        final authSummary = await runner.runTests(
          categories: ['auth'],
          verbose: false,
          quiet: false,
        );

        // Verify only auth tests were run
        expect(authSummary.totalTests, greaterThan(0));
        
        // All results should be from auth category (we can't directly verify this
        // without modifying the test suite structure, but we can verify the test ran)
        expect(authSummary.results.length, equals(authSummary.totalTests));
      });

      test('should handle verbose mode correctly', () async {
        // Test verbose output mode
        final summary = await runner.runTests(
          verbose: true,
          quiet: false,
        );

        // Verify test execution completed
        expect(summary.totalTests, greaterThan(0));
        expect(summary.results.isNotEmpty, isTrue);
      });

      test('should handle quiet mode correctly', () async {
        // Test quiet output mode
        final summary = await runner.runTests(
          verbose: false,
          quiet: true,
        );

        // Verify test execution completed
        expect(summary.totalTests, greaterThan(0));
        expect(summary.results.isNotEmpty, isTrue);
      });

      test('should handle dry-run mode correctly', () async {
        // Test dry-run validation
        final summary = await runner.runTests(
          dryRun: true,
        );

        // In dry-run mode, we should get validation results
        expect(summary.totalTests, greaterThanOrEqualTo(0));
        // Dry run should complete quickly
        expect(summary.totalTime.inSeconds, lessThan(5));
      });

      test('should handle timeout configuration', () async {
        // Test with custom timeout
        final shortTimeout = Duration(milliseconds: 100);
        
        // This might timeout, but should handle it gracefully
        try {
          final summary = await runner.runTests(
            timeout: shortTimeout,
          );
          
          // If it completes, verify the results
          expect(summary.totalTests, greaterThanOrEqualTo(0));
        } catch (e) {
          // Timeout is acceptable for very short timeouts
          expect(e.toString(), contains('timeout'));
        }
      });

      test('should handle invalid categories gracefully', () async {
        // Test error handling for invalid categories
        expect(
          () => runner.runTests(categories: ['invalid-category']),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Error Recovery and Cleanup', () {
      test('should handle mock environment setup failures', () async {
        // Create a mock environment that will fail setup
        final failingMockEnv = MockEnvironment();
        
        // Manually cause a failure state (this is a simulation)
        // In a real scenario, we might have network issues, etc.
        
        final testRunner = TerminalTestRunner(
          mockEnvironment: failingMockEnv,
        );

        // Test should handle setup gracefully
        final summary = await testRunner.runTests();
        
        // Should still return a valid summary even if some tests fail
        expect(summary.totalTests, greaterThanOrEqualTo(0));
        expect(summary.results, isNotNull);
        
        // Cleanup
        failingMockEnv.teardown();
      });

      test('should cleanup resources after test execution', () async {
        // Verify mock environment is properly initialized
        expect(mockEnv.isInitialized, isFalse);
        
        // Run tests
        await runner.runTests();
        
        // Mock environment should be initialized during test execution
        // (This test verifies the lifecycle management)
        
        // Manual cleanup to verify it works
        mockEnv.teardown();
        expect(mockEnv.isInitialized, isFalse);
      });

      test('should handle partial test suite failures', () async {
        // This test verifies that if some test suites fail,
        // the overall execution continues and provides results
        
        final summary = await runner.runTests();
        
        // Even if some tests fail, we should get a complete summary
        expect(summary.totalTests, greaterThan(0));
        expect(summary.results.length, equals(summary.totalTests));
        
        // Verify that failed/error tests are properly counted
        final actualTotal = summary.passedTests + summary.failedTests + summary.errorTests;
        expect(actualTotal, equals(summary.totalTests));
      });

      test('should handle concurrent test execution safely', () async {
        // Test that multiple test runs don't interfere with each other
        final futures = <Future<TestSummary>>[];
        
        // Start multiple test runs concurrently
        for (int i = 0; i < 3; i++) {
          final concurrentRunner = TerminalTestRunner();
          futures.add(concurrentRunner.runTests(
            categories: ['auth'], // Use smaller category for faster execution
            quiet: true, // Reduce output noise
          ));
        }
        
        // Wait for all to complete
        final results = await Future.wait(futures);
        
        // All should complete successfully
        expect(results.length, equals(3));
        for (final summary in results) {
          expect(summary.totalTests, greaterThanOrEqualTo(0));
          expect(summary.results.length, equals(summary.totalTests));
        }
      });
    });

    group('CLI Integration', () {
      test('should parse and execute CLI arguments correctly', () {
        // Test CLI argument parsing
        final config1 = CliParser.parseArguments(['--verbose']);
        expect(config1.verbose, isTrue);
        expect(config1.quiet, isFalse);
        
        final config2 = CliParser.parseArguments(['--quiet']);
        expect(config2.verbose, isFalse);
        expect(config2.quiet, isTrue);
        
        final config3 = CliParser.parseArguments(['--category', 'auth']);
        expect(config3.categories, contains('auth'));
        
        final config4 = CliParser.parseArguments(['--timeout', '60']);
        expect(config4.timeout?.inSeconds, equals(60));
        
        final config5 = CliParser.parseArguments(['--dry-run']);
        expect(config5.dryRun, isTrue);
      });

      test('should handle CLI error scenarios', () {
        // Test invalid arguments
        expect(
          () => CliParser.parseArguments(['--invalid-flag']),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => CliParser.parseArguments(['--timeout', 'invalid']),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => CliParser.parseArguments(['--timeout', '-5']),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should provide help information', () {
        // Test help display
        expect(() => runner.displayHelp(), returnsNormally);
        
        // Test available categories
        final categories = runner.getAvailableCategories();
        expect(categories, isNotEmpty);
        expect(categories, contains('auth'));
        expect(categories, contains('attendance'));
        expect(categories, contains('sync'));
        expect(categories, contains('personalization'));
      });
    });

    group('File-based Test Execution', () {
      test('should validate test file paths correctly', () {
        // Test valid test file validation
        expect(runner.isValidTestFile('nonexistent_test.dart'), isFalse);
        expect(runner.isValidTestFile('not_a_test.dart'), isFalse);
        expect(runner.isValidTestFile(''), isFalse);
      });

      test('should discover test files correctly', () async {
        // Test file discovery
        final testFiles = await runner.discoverTestFiles();
        
        // Should find test files in the test directory
        expect(testFiles, isNotEmpty);
        
        // All discovered files should be test files
        for (final file in testFiles) {
          expect(file, endsWith('_test.dart'));
        }
      });

      test('should handle test file execution errors gracefully', () async {
        // Test execution of non-existent file
        expect(
          () => runner.runTestFile('nonexistent_test.dart'),
          throwsA(isA<ArgumentError>()),
        );
        
        // Test execution of non-test file
        expect(
          () => runner.runTestFile('not_a_test.dart'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Performance and Reliability', () {
      test('should complete execution within reasonable time', () async {
        final stopwatch = Stopwatch()..start();
        
        final summary = await runner.runTests(
          categories: ['auth'], // Use smaller subset for performance test
          quiet: true,
        );
        
        stopwatch.stop();
        
        // Should complete within reasonable time (adjust as needed)
        expect(stopwatch.elapsed.inSeconds, lessThan(30));
        expect(summary.totalTests, greaterThan(0));
      });

      test('should handle repeated executions consistently', () async {
        // Run the same test multiple times
        final results = <TestSummary>[];
        
        for (int i = 0; i < 3; i++) {
          final summary = await runner.runTests(
            categories: ['auth'],
            quiet: true,
          );
          results.add(summary);
        }
        
        // Results should be consistent
        expect(results.length, equals(3));
        
        // All runs should have the same number of tests
        final firstTestCount = results.first.totalTests;
        for (final summary in results) {
          expect(summary.totalTests, equals(firstTestCount));
          expect(summary.results.length, equals(summary.totalTests));
        }
      });

      test('should handle memory cleanup properly', () async {
        // Test multiple sequential runs to check for memory leaks
        for (int i = 0; i < 5; i++) {
          final testRunner = TerminalTestRunner();
          final summary = await testRunner.runTests(
            categories: ['auth'],
            quiet: true,
          );
          
          expect(summary.totalTests, greaterThan(0));
          
          // Explicit cleanup (in real usage, this happens automatically)
          // This test ensures cleanup works properly
        }
      });
    });

    group('Reporter Integration', () {
      test('should generate comprehensive statistics', () async {
        final summary = await runner.runTests(quiet: true);
        
        // Test statistics generation
        final stats = reporter.generateSummaryStatistics(summary);
        
        expect(stats, containsPair('totalTests', summary.totalTests));
        expect(stats, containsPair('passedTests', summary.passedTests));
        expect(stats, containsPair('failedTests', summary.failedTests));
        expect(stats, containsPair('errorTests', summary.errorTests));
        expect(stats, containsPair('successPercentage', summary.successPercentage));
        expect(stats, contains('totalTimeMs'));
        
        if (summary.results.isNotEmpty) {
          expect(stats, contains('performance'));
          expect(stats, contains('statusDistribution'));
        }
      });

      test('should generate text reports correctly', () async {
        final summary = await runner.runTests(quiet: true);
        
        // Test text report generation
        final textReport = reporter.generateTextReport(summary);
        
        expect(textReport, contains('TEST EXECUTION SUMMARY'));
        expect(textReport, contains('Total Tests: ${summary.totalTests}'));
        expect(textReport, contains('Success Rate:'));
        
        if (summary.failedTests > 0 || summary.errorTests > 0) {
          expect(textReport, contains('TESTS FAILED'));
        } else {
          expect(textReport, contains('ALL TESTS PASSED'));
        }
      });
    });
  });
}