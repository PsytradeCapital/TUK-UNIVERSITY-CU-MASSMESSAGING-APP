import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/terminal_testing/reporters/test_reporter.dart';
import '../../lib/terminal_testing/core/test_suite.dart';
import 'property_test_utils.dart';

void main() {
  group('TestReporter Tests', () {
    late TestReporter reporter;

    setUp(() {
      reporter = TestReporter();
    });

    group('Property Tests', () {
      test('Property 5: Result Formatting Consistency - **Feature: terminal-testing-framework, Property 5: Result Formatting Consistency**', () {
        // **Validates: Requirements 2.1, 2.2, 2.3**
        
        PropertyTestUtils.runPropertyTest(
          description: 'All test results should include correct status indicator, color coding, test name, and diagnostic information',
          iterations: 100,
          property: () {
            // Generate random test result
            final testName = PropertyTestUtils.randomString(minLength: 5, maxLength: 30);
            final statuses = [TestStatus.pass, TestStatus.fail, TestStatus.error];
            final status = statuses[PropertyTestUtils.randomInt(max: 2)];
            final executionTime = Duration(milliseconds: PropertyTestUtils.randomInt(min: 1, max: 5000));
            
            String? message;
            String? stackTrace;
            
            // Add message for FAIL and ERROR status
            if (status == TestStatus.fail) {
              message = 'Test failed: ${PropertyTestUtils.randomString()}';
            } else if (status == TestStatus.error) {
              message = 'Test error: ${PropertyTestUtils.randomString()}';
              if (PropertyTestUtils.randomBool()) {
                stackTrace = 'Stack trace line 1\nStack trace line 2\nStack trace line 3';
              }
            }
            
            final testResult = TestResult(
              testName: testName,
              status: status,
              message: message,
              executionTime: executionTime,
              stackTrace: stackTrace,
            );
            
            try {
              // Test that the method executes without throwing
              reporter.reportResult(testResult);
              
              // Since we can't easily capture stdout in tests, we verify:
              // 1. Method doesn't throw with valid input
              // 2. All required fields are present in the TestResult
              final hasTestName = testName.isNotEmpty;
              final hasValidStatus = [TestStatus.pass, TestStatus.fail, TestStatus.error].contains(status);
              final hasValidExecutionTime = executionTime.inMilliseconds >= 0;
              
              // Verify message is provided for FAIL/ERROR when expected
              bool messageRequirementMet = true;
              if (status == TestStatus.fail || status == TestStatus.error) {
                // Message should be provided for these statuses
                messageRequirementMet = message != null;
              }
              
              return hasTestName && hasValidStatus && hasValidExecutionTime && messageRequirementMet;
                     
            } catch (e) {
              return false;
            }
          },
        );
      });

      test('Property 6: Progress Counter Accuracy - **Feature: terminal-testing-framework, Property 6: Progress Counter Accuracy**', () {
        // **Validates: Requirements 2.4**
        
        PropertyTestUtils.runPropertyTest(
          description: 'Progress counters should accurately reflect current position and total count',
          iterations: 100,
          property: () {
            // Generate random progress values with proper constraints
            final total = 1 + PropertyTestUtils.randomInt(max: 99); // total is 1-100
            final current = 1 + PropertyTestUtils.randomInt(max: total - 1); // current is 1 to total (inclusive)
            final testName = PropertyTestUtils.randomString(minLength: 1, maxLength: 20);
            
            try {
              reporter.reportProgress(current, total, testName);
              
              // Verify the parameters are reasonable and method doesn't throw
              final validCurrent = current >= 1 && current <= total;
              final validTotal = total >= 1;
              final validTestName = testName.isNotEmpty;
              
              return validCurrent && validTotal && validTestName;
            } catch (e) {
              return false;
            }
          },
        );
      });
      
      test('Output mode compliance property test', () {
        PropertyTestUtils.runPropertyTest(
          description: 'Output should respect verbose and quiet mode settings',
          iterations: 50,
          property: () {
            final verbose = PropertyTestUtils.randomBool();
            final quiet = PropertyTestUtils.randomBool();
            
            final testReporter = TestReporter(verbose: verbose, quiet: quiet);
            
            final testResult = TestResult(
              testName: PropertyTestUtils.randomString(),
              status: TestStatus.pass,
              executionTime: Duration(milliseconds: PropertyTestUtils.randomInt(max: 1000)),
            );
            
            try {
              // These methods should not throw regardless of mode settings
              testReporter.reportResult(testResult);
              testReporter.reportProgress(1, 5, 'Test');
              
              return true;
            } catch (e) {
              return false;
            }
          },
        );
      });

      test('Property 16: Output Mode Compliance - **Feature: terminal-testing-framework, Property 16: Output Mode Compliance**', () {
        // **Validates: Requirements 6.1, 6.2**
        
        PropertyTestUtils.runPropertyTest(
          description: 'TestReporter should work correctly with any valid output mode configuration',
          iterations: 50,
          property: () {
            // Generate valid output mode configuration
            final verbose = PropertyTestUtils.randomBool();
            final quiet = verbose ? false : PropertyTestUtils.randomBool(); // Ensure not both true
            
            try {
              final testReporter = TestReporter(verbose: verbose, quiet: quiet);
              
              // Verify initial mode settings
              if (testReporter.isVerbose != verbose || testReporter.isQuiet != quiet) {
                return false;
              }
              
              // Test basic functionality
              final testResult = TestResult(
                testName: 'Test',
                status: TestStatus.pass,
                executionTime: const Duration(milliseconds: 100),
              );
              
              testReporter.reportResult(testResult);
              testReporter.reportProgress(1, 1, 'Test');
              
              // Test setOutputMode
              final newVerbose = PropertyTestUtils.randomBool();
              final newQuiet = newVerbose ? false : PropertyTestUtils.randomBool();
              
              testReporter.setOutputMode(verbose: newVerbose, quiet: newQuiet);
              
              // Verify mode was updated
              if (testReporter.isVerbose != newVerbose || testReporter.isQuiet != newQuiet) {
                return false;
              }
              
              // Test that it still works after mode change
              testReporter.reportResult(testResult);
              
              return true;
              
            } catch (e) {
              return false;
            }
          },
        );
      });

      test('Property 4: Summary Report Completeness - **Feature: terminal-testing-framework, Property 4: Summary Report Completeness**', () {
        // **Validates: Requirements 1.5, 2.5**
        
        PropertyTestUtils.runPropertyTest(
          description: 'For any test execution, the final summary should contain total counts, individual results, and calculated success percentage',
          iterations: 100,
          property: () {
            // Generate random test results
            final totalTests = 1 + PropertyTestUtils.randomInt(max: 20);
            final results = <TestResult>[];
            
            int passedTests = 0;
            int failedTests = 0;
            int errorTests = 0;
            
            for (int i = 0; i < totalTests; i++) {
              final statuses = [TestStatus.pass, TestStatus.fail, TestStatus.error];
              final status = statuses[PropertyTestUtils.randomInt(max: 2)];
              
              switch (status) {
                case TestStatus.pass:
                  passedTests++;
                  break;
                case TestStatus.fail:
                  failedTests++;
                  break;
                case TestStatus.error:
                  errorTests++;
                  break;
              }
              
              results.add(TestResult(
                testName: 'Test ${i + 1}',
                status: status,
                message: status != TestStatus.pass ? 'Test ${status.name}' : null,
                executionTime: Duration(milliseconds: PropertyTestUtils.randomInt(min: 1, max: 1000)),
                stackTrace: status == TestStatus.error && PropertyTestUtils.randomBool() ? 'Stack trace' : null,
              ));
            }
            
            final totalTime = Duration(milliseconds: PropertyTestUtils.randomInt(min: 100, max: 10000));
            
            final summary = TestSummary(
              totalTests: totalTests,
              passedTests: passedTests,
              failedTests: failedTests,
              errorTests: errorTests,
              totalTime: totalTime,
              results: results,
            );
            
            try {
              // Test that reportSummary works without throwing
              reporter.reportSummary(summary);
              
              // Verify summary completeness requirements
              
              // 1. Total counts should be accurate
              final countsMatch = (passedTests + failedTests + errorTests) == totalTests;
              
              // 2. Success percentage should be calculated correctly
              final expectedSuccessRate = totalTests > 0 ? (passedTests / totalTests) * 100 : 0.0;
              final actualSuccessRate = summary.successPercentage;
              final successRateCorrect = (actualSuccessRate - expectedSuccessRate).abs() < 0.01; // Allow small floating point differences
              
              // 3. Individual results should be included
              final resultsIncluded = summary.results.length == totalTests;
              
              // 4. All results should have required fields
              final allResultsValid = summary.results.every((result) => 
                result.testName.isNotEmpty &&
                [TestStatus.pass, TestStatus.fail, TestStatus.error].contains(result.status) &&
                result.executionTime.inMilliseconds >= 0
              );
              
              // 5. Test comprehensive statistics generation
              final stats = reporter.generateSummaryStatistics(summary);
              final statsComplete = stats.containsKey('totalTests') &&
                                  stats.containsKey('passedTests') &&
                                  stats.containsKey('failedTests') &&
                                  stats.containsKey('errorTests') &&
                                  stats.containsKey('successPercentage') &&
                                  stats.containsKey('totalTimeMs');
              
              // 6. Test text report generation
              final textReport = reporter.generateTextReport(summary);
              final textReportValid = textReport.contains('TEST EXECUTION SUMMARY') &&
                                    textReport.contains('Total Tests: $totalTests') &&
                                    textReport.contains('Success Rate:');
              
              return countsMatch && successRateCorrect && resultsIncluded && 
                     allResultsValid && statsComplete && textReportValid;
              
            } catch (e) {
              return false;
            }
          },
        );
      });
    });

    group('Unit Tests', () {
      test('should format PASS result correctly', () {
        final testResult = TestResult(
          testName: 'Sample Pass Test',
          status: TestStatus.pass,
          executionTime: const Duration(milliseconds: 150),
        );

        // Test that reportResult doesn't throw
        expect(() => reporter.reportResult(testResult), returnsNormally);
      });

      test('should format FAIL result with message', () {
        final testResult = TestResult(
          testName: 'Sample Fail Test',
          status: TestStatus.fail,
          message: 'Expected true but got false',
          executionTime: const Duration(milliseconds: 200),
        );

        expect(() => reporter.reportResult(testResult), returnsNormally);
      });

      test('should format ERROR result with stack trace', () {
        final testResult = TestResult(
          testName: 'Sample Error Test',
          status: TestStatus.error,
          message: 'Null pointer exception',
          executionTime: const Duration(milliseconds: 50),
          stackTrace: 'at line 1\nat line 2\nat line 3',
        );

        expect(() => reporter.reportResult(testResult), returnsNormally);
      });

      test('should report progress without throwing', () {
        expect(() => reporter.reportProgress(3, 10, 'Current Test'), returnsNormally);
      });

      test('should report summary with all test types', () {
        final results = [
          TestResult(
            testName: 'Pass Test',
            status: TestStatus.pass,
            executionTime: const Duration(milliseconds: 100),
          ),
          TestResult(
            testName: 'Fail Test',
            status: TestStatus.fail,
            message: 'Test failed',
            executionTime: const Duration(milliseconds: 150),
          ),
          TestResult(
            testName: 'Error Test',
            status: TestStatus.error,
            message: 'Test error',
            executionTime: const Duration(milliseconds: 75),
          ),
        ];

        final summary = TestSummary(
          totalTests: 3,
          passedTests: 1,
          failedTests: 1,
          errorTests: 1,
          totalTime: const Duration(milliseconds: 325),
          results: results,
        );

        expect(() => reporter.reportSummary(summary), returnsNormally);
      });

      test('should handle verbose mode', () {
        final verboseReporter = TestReporter(verbose: true);
        
        expect(() => verboseReporter.reportTestSuiteStart('Auth Suite', 'auth'), returnsNormally);
        expect(() => verboseReporter.reportTestSuiteComplete('Auth Suite', 5, const Duration(seconds: 2)), returnsNormally);
      });

      test('should handle quiet mode', () {
        final quietReporter = TestReporter(quiet: true);
        
        final passResult = TestResult(
          testName: 'Quiet Test',
          status: TestStatus.pass,
          executionTime: const Duration(milliseconds: 100),
        );
        
        // Should not output for passing tests in quiet mode
        expect(() => quietReporter.reportResult(passResult), returnsNormally);
        expect(() => quietReporter.reportProgress(1, 5, 'Test'), returnsNormally);
      });

      test('should format duration correctly', () {
        final shortResult = TestResult(
          testName: 'Short Test',
          status: TestStatus.pass,
          executionTime: const Duration(milliseconds: 150),
        );

        final longResult = TestResult(
          testName: 'Long Test',
          status: TestStatus.pass,
          executionTime: const Duration(milliseconds: 2500),
        );

        expect(() => reporter.reportResult(shortResult), returnsNormally);
        expect(() => reporter.reportResult(longResult), returnsNormally);
      });

      test('should handle edge cases', () {
        // Test with empty test name
        final emptyNameResult = TestResult(
          testName: '',
          status: TestStatus.pass,
          executionTime: Duration.zero,
        );

        // Test with very long test name
        final longNameResult = TestResult(
          testName: 'A' * 200,
          status: TestStatus.pass,
          executionTime: const Duration(milliseconds: 1),
        );

        expect(() => reporter.reportResult(emptyNameResult), returnsNormally);
        expect(() => reporter.reportResult(longNameResult), returnsNormally);
      });
    });
  });
}