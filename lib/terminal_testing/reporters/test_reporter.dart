import 'dart:io';
import '../core/test_suite.dart';

/// Handles result formatting and display with colorized output
/// Provides real-time progress indicators and clear PASS/FAIL/ERROR formatting
class TestReporter {
  static const String _green = '\x1B[32m';
  static const String _red = '\x1B[31m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _cyan = '\x1B[36m';
  static const String _bold = '\x1B[1m';
  static const String _reset = '\x1B[0m';

  // Expose color constants for use by other classes
  static const String green = _green;
  static const String red = _red;
  static const String yellow = _yellow;
  static const String blue = _blue;
  static const String cyan = _cyan;
  static const String bold = _bold;
  static const String reset = _reset;

  bool _verbose;
  bool _quiet;

  TestReporter({bool verbose = false, bool quiet = false})
      : _verbose = verbose,
        _quiet = quiet;

  /// Set output mode for verbose and quiet flags
  void setOutputMode({bool verbose = false, bool quiet = false}) {
    _verbose = verbose;
    _quiet = quiet;
  }

  /// Get current verbose mode
  bool get isVerbose => _verbose;

  /// Get current quiet mode
  bool get isQuiet => _quiet;

  /// Report progress during test execution with real-time display
  /// Shows current test number, total tests, and test name
  void reportProgress(int current, int total, String testName) {
    if (_quiet) return;
    
    // Clear the line and show progress
    stdout.write('\r${' ' * 80}\r'); // Clear previous line
    stdout.write('${_cyan}[$current/$total]$_reset Running: $testName');
    stdout.flush();
  }

  /// Report individual test result with colorized status indicators
  /// Displays PASS in green, FAIL in red, ERROR in yellow with test name and timing
  void reportResult(TestResult result) {
    if (_quiet && result.status == TestStatus.pass) return;
    
    final statusColor = _getStatusColor(result.status);
    final statusText = _getStatusText(result.status);
    
    // Clear progress line and show result
    stdout.write('\r${' ' * 80}\r');
    
    if (_verbose) {
      // Verbose mode: Show detailed information
      print('$statusColor$_bold[$statusText]$_reset ${result.testName} ${_formatDuration(result.executionTime)}');
      
      // Show message for all results in verbose mode
      if (result.message != null) {
        final messageColor = result.status == TestStatus.fail ? _red : 
                           result.status == TestStatus.error ? _yellow : _cyan;
        print('  ${messageColor}Details:$_reset ${result.message}');
      }
      
      // Show stack trace for errors in verbose mode
      if (result.stackTrace != null && result.status == TestStatus.error) {
        print('  ${_yellow}Stack trace:$_reset');
        final lines = result.stackTrace!.split('\n');
        for (final line in lines.take(10)) { // Show more lines in verbose mode
          if (line.trim().isNotEmpty) {
            print('    $line');
          }
        }
        if (lines.length > 10) {
          print('    ... (${lines.length - 10} more lines)');
        }
      }
    } else if (_quiet) {
      // Quiet mode: Only show failures and errors
      if (result.status != TestStatus.pass) {
        print('$statusColor$_bold[$statusText]$_reset ${result.testName}');
        if (result.message != null) {
          print('  ${result.message}');
        }
      }
    } else {
      // Normal mode: Standard output
      print('$statusColor$_bold[$statusText]$_reset ${result.testName} ${_formatDuration(result.executionTime)}');
      
      // Show failure reason for FAIL status
      if (result.message != null && result.status == TestStatus.fail) {
        print('  ${_red}Reason:$_reset ${result.message}');
      }
      
      // Show diagnostic information for ERROR status
      if (result.message != null && result.status == TestStatus.error) {
        print('  ${_yellow}Error:$_reset ${result.message}');
      }
      
      // Show limited stack trace in normal mode for errors
      if (result.stackTrace != null && result.status == TestStatus.error) {
        print('  ${_yellow}Stack trace:$_reset');
        final lines = result.stackTrace!.split('\n');
        for (final line in lines.take(3)) { // Limit stack trace lines in normal mode
          if (line.trim().isNotEmpty) {
            print('    $line');
          }
        }
        if (lines.length > 3) {
          print('    ... (${lines.length - 3} more lines, use --verbose for full trace)');
        }
      }
    }
  }

  /// Report final test summary with comprehensive statistics
  /// Shows total counts, success percentage, and overall status
  void reportSummary(TestSummary summary) {
    if (!_quiet) {
      // Clear any remaining progress line
      stdout.write('\r${' ' * 80}\r');
      print(''); // Add blank line
    }
    
    if (_quiet) {
      // Quiet mode: Minimal summary
      if (summary.failedTests > 0 || summary.errorTests > 0) {
        print('${_red}FAILED:$_reset ${summary.failedTests + summary.errorTests}/${summary.totalTests} tests failed');
      } else {
        print('${_green}PASSED:$_reset All ${summary.totalTests} tests passed');
      }
      return;
    }
    
    print('${_bold}${'=' * 60}$_reset');
    print('${_bold}${_blue}TEST EXECUTION SUMMARY$_reset');
    print('${_bold}${'=' * 60}$_reset');
    
    // Test counts with colors
    print('${_bold}Total Tests:$_reset ${summary.totalTests}');
    print('${_green}${_bold}Passed:$_reset ${summary.passedTests}');
    
    if (summary.failedTests > 0) {
      print('${_red}${_bold}Failed:$_reset ${summary.failedTests}');
    }
    
    if (summary.errorTests > 0) {
      print('${_yellow}${_bold}Errors:$_reset ${summary.errorTests}');
    }
    
    // Success percentage with color coding
    final successRate = summary.successPercentage;
    final successColor = successRate == 100.0 ? _green : 
                        successRate >= 80.0 ? _yellow : _red;
    print('${_bold}Success Rate:$_reset $successColor${successRate.toStringAsFixed(1)}%$_reset');
    
    // Execution time
    print('${_bold}Total Time:$_reset ${_formatDuration(summary.totalTime)}');
    
    // Additional comprehensive statistics
    if (summary.results.isNotEmpty) {
      final durations = summary.results.map((r) => r.executionTime.inMilliseconds).toList()..sort();
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      final maxDuration = durations.last;
      final minDuration = durations.first;
      
      print('${_bold}Performance Statistics:$_reset');
      print('  Average Test Time: ${avgDuration.toStringAsFixed(1)}ms');
      print('  Fastest Test: ${minDuration}ms');
      print('  Slowest Test: ${maxDuration}ms');
      
      // Test distribution by status
      final statusCounts = <TestStatus, int>{};
      for (final result in summary.results) {
        statusCounts[result.status] = (statusCounts[result.status] ?? 0) + 1;
      }
      
      print('${_bold}Test Distribution:$_reset');
      for (final entry in statusCounts.entries) {
        final percentage = (entry.value / summary.totalTests * 100).toStringAsFixed(1);
        final color = _getStatusColor(entry.key);
        final statusText = _getStatusText(entry.key);
        print('  $color$statusText:$_reset ${entry.value} (${percentage}%)');
      }
    }
    
    // Verbose mode: Show additional details
    if (_verbose) {
      print('\n${_bold}Detailed Results:$_reset');
      final categorizedResults = <TestStatus, List<TestResult>>{};
      for (final result in summary.results) {
        categorizedResults.putIfAbsent(result.status, () => []).add(result);
      }
      
      // Show failed tests
      if (categorizedResults[TestStatus.fail]?.isNotEmpty == true) {
        print('${_red}${_bold}Failed Tests:$_reset');
        for (final result in categorizedResults[TestStatus.fail]!) {
          print('  - ${result.testName}: ${result.message ?? 'No details'}');
        }
      }
      
      // Show error tests
      if (categorizedResults[TestStatus.error]?.isNotEmpty == true) {
        print('${_yellow}${_bold}Error Tests:$_reset');
        for (final result in categorizedResults[TestStatus.error]!) {
          print('  - ${result.testName}: ${result.message ?? 'No details'}');
        }
      }
      
      // Show all test results with timing
      if (summary.results.length <= 20) { // Only show all results if not too many
        print('\n${_bold}All Test Results:$_reset');
        for (final result in summary.results) {
          final statusColor = _getStatusColor(result.status);
          final statusText = _getStatusText(result.status);
          print('  $statusColor[$statusText]$_reset ${result.testName} ${_formatDuration(result.executionTime)}');
        }
      }
    }
    
    // Final status message
    print('${_bold}${'=' * 60}$_reset');
    if (summary.failedTests > 0 || summary.errorTests > 0) {
      print('${_red}${_bold}TESTS FAILED$_reset - See details above');
      if (!_verbose && (summary.failedTests > 0 || summary.errorTests > 0)) {
        print('${_cyan}Tip: Use --verbose flag for detailed error information$_reset');
      }
    } else {
      print('${_green}${_bold}ALL TESTS PASSED!$_reset');
    }
    print('');
  }

  /// Get color code for test status
  String _getStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.pass:
        return _green;
      case TestStatus.fail:
        return _red;
      case TestStatus.error:
        return _yellow;
    }
  }

  /// Get text representation of test status
  String _getStatusText(TestStatus status) {
    switch (status) {
      case TestStatus.pass:
        return 'PASS';
      case TestStatus.fail:
        return 'FAIL';
      case TestStatus.error:
        return 'ERROR';
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms < 1000) {
      return '(${ms}ms)';
    } else {
      final seconds = (ms / 1000).toStringAsFixed(1);
      return '(${seconds}s)';
    }
  }

  /// Report test suite start (for verbose mode)
  void reportTestSuiteStart(String suiteName, String category) {
    if (_verbose && !_quiet) {
      print('\n${_cyan}${_bold}Starting test suite:$_reset $suiteName ${_cyan}[$category]$_reset');
    }
  }

  /// Report test suite completion (for verbose mode)
  void reportTestSuiteComplete(String suiteName, int testCount, Duration duration) {
    if (_verbose && !_quiet) {
      print('${_cyan}Completed:$_reset $suiteName ($testCount tests, ${_formatDuration(duration)})');
    }
  }

  /// Generate comprehensive summary statistics as a map
  /// Useful for programmatic access to test results
  Map<String, dynamic> generateSummaryStatistics(TestSummary summary) {
    final stats = <String, dynamic>{
      'totalTests': summary.totalTests,
      'passedTests': summary.passedTests,
      'failedTests': summary.failedTests,
      'errorTests': summary.errorTests,
      'successPercentage': summary.successPercentage,
      'totalTimeMs': summary.totalTime.inMilliseconds,
      'totalTimeFormatted': _formatDuration(summary.totalTime),
    };

    if (summary.results.isNotEmpty) {
      final durations = summary.results.map((r) => r.executionTime.inMilliseconds).toList()..sort();
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      
      stats['performance'] = {
        'averageTestTimeMs': avgDuration,
        'fastestTestMs': durations.first,
        'slowestTestMs': durations.last,
      };

      // Test distribution by status
      final statusCounts = <String, int>{};
      for (final result in summary.results) {
        final statusKey = result.status.toString().split('.').last;
        statusCounts[statusKey] = (statusCounts[statusKey] ?? 0) + 1;
      }
      stats['statusDistribution'] = statusCounts;

      // Failed and error test details
      final failedTests = summary.results.where((r) => r.status == TestStatus.fail).toList();
      final errorTests = summary.results.where((r) => r.status == TestStatus.error).toList();
      
      if (failedTests.isNotEmpty) {
        stats['failedTestDetails'] = failedTests.map((r) => {
          'name': r.testName,
          'message': r.message,
          'executionTimeMs': r.executionTime.inMilliseconds,
        }).toList();
      }
      
      if (errorTests.isNotEmpty) {
        stats['errorTestDetails'] = errorTests.map((r) => {
          'name': r.testName,
          'message': r.message,
          'executionTimeMs': r.executionTime.inMilliseconds,
          'hasStackTrace': r.stackTrace != null,
        }).toList();
      }
    }

    return stats;
  }

  /// Generate a text-based comprehensive report
  /// Useful for logging or file output
  String generateTextReport(TestSummary summary) {
    final buffer = StringBuffer();
    
    buffer.writeln('=' * 60);
    buffer.writeln('TEST EXECUTION SUMMARY');
    buffer.writeln('=' * 60);
    
    buffer.writeln('Total Tests: ${summary.totalTests}');
    buffer.writeln('Passed: ${summary.passedTests}');
    buffer.writeln('Failed: ${summary.failedTests}');
    buffer.writeln('Errors: ${summary.errorTests}');
    buffer.writeln('Success Rate: ${summary.successPercentage.toStringAsFixed(1)}%');
    buffer.writeln('Total Time: ${_formatDuration(summary.totalTime)}');
    
    if (summary.results.isNotEmpty) {
      final durations = summary.results.map((r) => r.executionTime.inMilliseconds).toList()..sort();
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      
      buffer.writeln('\nPerformance Statistics:');
      buffer.writeln('  Average Test Time: ${avgDuration.toStringAsFixed(1)}ms');
      buffer.writeln('  Fastest Test: ${durations.first}ms');
      buffer.writeln('  Slowest Test: ${durations.last}ms');
    }
    
    // Failed tests
    final failedTests = summary.results.where((r) => r.status == TestStatus.fail).toList();
    if (failedTests.isNotEmpty) {
      buffer.writeln('\nFailed Tests:');
      for (final result in failedTests) {
        buffer.writeln('  - ${result.testName}: ${result.message ?? 'No details'}');
      }
    }
    
    // Error tests
    final errorTests = summary.results.where((r) => r.status == TestStatus.error).toList();
    if (errorTests.isNotEmpty) {
      buffer.writeln('\nError Tests:');
      for (final result in errorTests) {
        buffer.writeln('  - ${result.testName}: ${result.message ?? 'No details'}');
      }
    }
    
    buffer.writeln('\n' + '=' * 60);
    if (summary.failedTests > 0 || summary.errorTests > 0) {
      buffer.writeln('TESTS FAILED');
    } else {
      buffer.writeln('ALL TESTS PASSED!');
    }
    
    return buffer.toString();
  }
}