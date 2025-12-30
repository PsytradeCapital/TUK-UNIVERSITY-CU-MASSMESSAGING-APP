import 'dart:io';
import 'dart:async';
import 'test_suite.dart';
import '../reporters/test_reporter.dart';
import '../test_suites/test_suite_registry.dart';
import '../test_suites/auth_test_suite.dart';
import '../test_suites/attendance_test_suite.dart';
import '../test_suites/sync_test_suite.dart';
import '../test_suites/personalization_test_suite.dart';
import '../mocks/mock_environment.dart';

/// Main orchestrator class that manages test execution
class TerminalTestRunner {
  final TestReporter _reporter;
  final TestSuiteRegistry _registry;
  final Duration _defaultTimeout;
  final MockEnvironment _mockEnv;

  TerminalTestRunner({
    TestReporter? reporter,
    TestSuiteRegistry? registry,
    Duration? defaultTimeout,
    MockEnvironment? mockEnvironment,
  })  : _reporter = reporter ?? TestReporter(),
        _registry = registry ?? TestSuiteRegistry(),
        _defaultTimeout = defaultTimeout ?? const Duration(seconds: 30),
        _mockEnv = mockEnvironment ?? MockEnvironment() {
    _initializeDefaultTestSuites();
  }

  /// Initialize default test suites
  void _initializeDefaultTestSuites() {
    // Only initialize if registry is empty (avoid duplicate registration)
    if (_registry.count == 0) {
      _registry.registerTestSuite(AuthTestSuite(_mockEnv));
      _registry.registerTestSuite(AttendanceTestSuite(_mockEnv));
      _registry.registerTestSuite(SyncTestSuite(_mockEnv));
      _registry.registerTestSuite(PersonalizationTestSuite(_mockEnv));
    }
  }

  /// Run tests with specified configuration
  Future<TestSummary> runTests({
    List<String>? categories,
    bool verbose = false,
    bool quiet = false,
    Duration? timeout,
    bool dryRun = false,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final discoveredSuites = await _discoverTestSuites(categories);
    
    // Create reporter with appropriate flags
    final reporter = TestReporter(verbose: verbose, quiet: quiet);
    
    // Set reporter instance for consistent output
    _reporter.setOutputMode(verbose: verbose, quiet: quiet);
    
    if (discoveredSuites.isEmpty) {
      if (!quiet) {
        if (categories != null && categories.isNotEmpty) {
          print('No test suites found for categories: ${categories.join(", ")}');
          print('Available categories: ${_registry.getAvailableCategories().join(", ")}');
        } else {
          print('No test suites found.');
        }
      }
      return TestSummary(
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        errorTests: 0,
        totalTime: Duration.zero,
        results: [],
      );
    }
    
    if (dryRun) {
      return _performDryRun(discoveredSuites);
    }

    if (!quiet) {
      print('Discovered ${discoveredSuites.length} test suites');
      print('Starting test execution with ${effectiveTimeout.inSeconds}s timeout...\n');
    }

    final results = <TestResult>[];
    final stopwatch = Stopwatch()..start();
    int currentTest = 0;
    int totalTests = 0;

    // Calculate total number of tests for progress tracking
    for (final suite in discoveredSuites) {
      // For now, assume each suite has at least 1 test
      // This will be more accurate when we implement actual test suites
      totalTests += 1;
    }

    for (final suite in discoveredSuites) {
      currentTest++;
      
      _reporter.reportTestSuiteStart(suite.name, suite.category);
      _reporter.reportProgress(currentTest, totalTests, suite.name);

      final suiteStopwatch = Stopwatch()..start();
      
      try {
        final suiteResults = await _executeTestSuiteWithTimeout(
          suite,
          effectiveTimeout,
          verbose,
        );
        
        suiteStopwatch.stop();
        results.addAll(suiteResults);
        
        // Report individual results
        for (final result in suiteResults) {
          _reporter.reportResult(result);
        }
        
        _reporter.reportTestSuiteComplete(suite.name, suiteResults.length, suiteStopwatch.elapsed);
        
      } catch (e, stackTrace) {
        suiteStopwatch.stop();
        final errorResult = TestResult(
          testName: '${suite.name} (Suite Execution)',
          status: TestStatus.error,
          message: 'Suite execution failed: ${e.toString()}',
          executionTime: suiteStopwatch.elapsed,
          stackTrace: stackTrace.toString(),
        );
        results.add(errorResult);
        _reporter.reportResult(errorResult);
      }
    }

    stopwatch.stop();
    
    final summary = _createSummary(results, stopwatch.elapsed);
    _reporter.reportSummary(summary);
    
    return summary;
  }

  /// Run a specific test file
  Future<TestSummary> runTestFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('Test file not found: $filePath');
    }

    // Validate that it's a test file
    if (!filePath.endsWith('_test.dart')) {
      throw ArgumentError('File must be a test file (ending with _test.dart): $filePath');
    }

    print('Running specific test file: $filePath');
    
    // For individual file execution, we'll run it as a Dart test
    // This is a simplified implementation - in a full system, you might want to
    // parse the file and extract test suites or use dart test runner
    
    final stopwatch = Stopwatch()..start();
    final results = <TestResult>[];
    
    try {
      // Execute the test file using dart test
      final process = await Process.run(
        'dart',
        ['test', filePath],
        workingDirectory: Directory.current.path,
      );
      
      stopwatch.stop();
      
      if (process.exitCode == 0) {
        // Test passed
        results.add(TestResult(
          testName: 'File: ${filePath.split('/').last}',
          status: TestStatus.pass,
          message: 'All tests in file passed',
          executionTime: stopwatch.elapsed,
        ));
      } else {
        // Test failed
        results.add(TestResult(
          testName: 'File: ${filePath.split('/').last}',
          status: TestStatus.fail,
          message: 'Test file execution failed',
          executionTime: stopwatch.elapsed,
          stackTrace: process.stderr.toString(),
        ));
      }
      
    } catch (e) {
      stopwatch.stop();
      results.add(TestResult(
        testName: 'File: ${filePath.split('/').last}',
        status: TestStatus.error,
        message: 'Error executing test file: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      ));
    }
    
    final summary = _createSummary(results, stopwatch.elapsed);
    
    // Report results
    final reporter = TestReporter();
    reporter.reportSummary(summary);
    
    return summary;
  }

  /// Discover available test suites based on categories
  Future<List<TestSuite>> _discoverTestSuites(List<String>? categories) async {
    final allSuites = _registry.getAllTestSuites();
    
    if (categories == null || categories.isEmpty) {
      return allSuites;
    }
    
    // Validate categories exist
    final availableCategories = _registry.getAvailableCategories();
    final invalidCategories = categories.where((cat) => !availableCategories.contains(cat)).toList();
    
    if (invalidCategories.isNotEmpty) {
      throw ArgumentError(
        'Invalid categories: ${invalidCategories.join(", ")}. '
        'Available categories: ${availableCategories.join(", ")}'
      );
    }
    
    return allSuites.where((suite) => categories.contains(suite.category)).toList();
  }

  /// Execute a test suite with timeout and progress tracking
  Future<List<TestResult>> _executeTestSuiteWithTimeout(
    TestSuite suite,
    Duration timeout,
    bool verbose,
  ) async {
    final completer = Completer<List<TestResult>>();
    Timer? timeoutTimer;
    
    // Set up timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Test suite ${suite.name} timed out after ${timeout.inSeconds}s', timeout)
        );
      }
    });
    
    try {
      final results = await suite.execute();
      timeoutTimer.cancel();
      
      if (!completer.isCompleted) {
        completer.complete(results);
      }
      
      return results;
    } catch (e, stackTrace) {
      timeoutTimer.cancel();
      
      if (!completer.isCompleted) {
        completer.completeError(e, stackTrace);
      }
      
      rethrow;
    }
  }

  /// Display help information
  void displayHelp() {
    final availableCategories = _registry.getAvailableCategories();
    final categoriesText = availableCategories.isNotEmpty 
        ? availableCategories.join(', ')
        : 'No categories available';
        
    print('''
Terminal Testing Framework

Usage: dart run lib/terminal_testing/cli/main.dart [options]

Options:
  --category <category>    Run tests from specific category ($categoriesText)
  --verbose               Show detailed output
  --quiet                 Show minimal output
  --timeout <seconds>     Set custom timeout (default: 30)
  --dry-run              Validate setup without executing tests
  --help                 Show this help message

Examples:
  dart run lib/terminal_testing/cli/main.dart
  dart run lib/terminal_testing/cli/main.dart --category auth
  dart run lib/terminal_testing/cli/main.dart --verbose --timeout 60
  dart run lib/terminal_testing/cli/main.dart --dry-run
''');
  }

  /// Get available test categories
  List<String> getAvailableCategories() {
    return _registry.getAvailableCategories();
  }

  /// Discover test files in the project
  Future<List<String>> discoverTestFiles({String? pattern}) async {
    final testFiles = <String>[];
    final testDir = Directory('test');
    
    if (!await testDir.exists()) {
      return testFiles;
    }
    
    await for (final entity in testDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('_test.dart')) {
        if (pattern == null || entity.path.contains(pattern)) {
          testFiles.add(entity.path);
        }
      }
    }
    
    return testFiles..sort();
  }

  /// Run multiple test files
  Future<TestSummary> runTestFiles(List<String> filePaths) async {
    final allResults = <TestResult>[];
    final stopwatch = Stopwatch()..start();
    
    for (final filePath in filePaths) {
      try {
        final summary = await runTestFile(filePath);
        allResults.addAll(summary.results);
      } catch (e) {
        allResults.add(TestResult(
          testName: 'File: ${filePath.split('/').last}',
          status: TestStatus.error,
          message: 'Failed to execute file: $e',
          executionTime: Duration.zero,
          stackTrace: e.toString(),
        ));
      }
    }
    
    stopwatch.stop();
    return _createSummary(allResults, stopwatch.elapsed);
  }

  /// Validate test file path
  bool isValidTestFile(String filePath) {
    return filePath.endsWith('_test.dart') && File(filePath).existsSync();
  }

  List<TestSuite> _filterTestSuites(List<String>? categories) {
    final allSuites = _registry.getAllTestSuites();
    
    if (categories == null || categories.isEmpty) {
      return allSuites;
    }
    
    return allSuites.where((suite) => categories.contains(suite.category)).toList();
  }

  Future<TestSummary> _performDryRun(List<TestSuite> suites) async {
    if (!_reporter.isQuiet) {
      print('${TestReporter.cyan}${TestReporter.bold}DRY RUN MODE - Validating test setup${TestReporter.reset}');
      print('${TestReporter.cyan}No tests will be executed${TestReporter.reset}\n');
    }
    
    final validationResults = <String, bool>{};
    final validationMessages = <String>[];
    
    // Validate test suite discovery
    validationResults['Test Suite Discovery'] = suites.isNotEmpty;
    if (suites.isEmpty) {
      validationMessages.add('No test suites found');
    } else {
      validationMessages.add('Found ${suites.length} test suites');
    }
    
    // Validate mock environment setup
    try {
      _mockEnv.setup();
      validationResults['Mock Environment Setup'] = true;
      validationMessages.add('Mock environment initialized successfully');
      _mockEnv.teardown();
    } catch (e) {
      validationResults['Mock Environment Setup'] = false;
      validationMessages.add('Mock environment setup failed: $e');
    }
    
    // Validate test categories
    final categorizedSuites = <String, List<TestSuite>>{};
    for (final suite in suites) {
      categorizedSuites.putIfAbsent(suite.category, () => []).add(suite);
    }
    
    final expectedCategories = ['auth', 'attendance', 'sync', 'personalization'];
    final foundCategories = categorizedSuites.keys.toSet();
    final missingCategories = expectedCategories.where((cat) => !foundCategories.contains(cat)).toList();
    
    validationResults['Category Coverage'] = missingCategories.isEmpty;
    if (missingCategories.isNotEmpty) {
      validationMessages.add('Missing test categories: ${missingCategories.join(', ')}');
    } else {
      validationMessages.add('All expected test categories found');
    }
    
    // Validate individual test suites
    for (final suite in suites) {
      try {
        // Validate that the test suite can be instantiated and has required methods
        final suiteName = suite.name;
        final suiteCategory = suite.category;
        
        validationResults['Suite: $suiteName'] = suiteName.isNotEmpty && suiteCategory.isNotEmpty;
        if (_reporter.isVerbose) {
          validationMessages.add('Suite "$suiteName" in category "$suiteCategory" - OK');
        }
      } catch (e) {
        validationResults['Suite: ${suite.name}'] = false;
        validationMessages.add('Suite "${suite.name}" validation failed: $e');
      }
    }
    
    // Report validation results
    if (!_reporter.isQuiet) {
      print('${TestReporter.bold}Validation Results:${TestReporter.reset}');
      
      for (final entry in validationResults.entries) {
        final status = entry.value ? 
          '${TestReporter.green}${TestReporter.bold}[PASS]${TestReporter.reset}' : 
          '${TestReporter.red}${TestReporter.bold}[FAIL]${TestReporter.reset}';
        print('$status ${entry.key}');
      }
      
      if (_reporter.isVerbose) {
        print('\n${TestReporter.bold}Detailed Information:${TestReporter.reset}');
        for (final message in validationMessages) {
          print('  - $message');
        }
      }
      
      print('\n${TestReporter.bold}Test Suite Structure:${TestReporter.reset}');
      for (final category in categorizedSuites.keys.toList()..sort()) {
        print('  Category: ${TestReporter.cyan}$category${TestReporter.reset}');
        for (final suite in categorizedSuites[category]!) {
          if (_reporter.isVerbose) {
            print('    - ${suite.name} (${suite.runtimeType})');
          } else {
            print('    - ${suite.name}');
          }
        }
      }
      
      final allValid = validationResults.values.every((v) => v);
      if (allValid) {
        print('\n${TestReporter.green}${TestReporter.bold}✓ Dry run completed successfully - all validations passed${TestReporter.reset}');
        print('${TestReporter.cyan}Ready to execute ${suites.length} test suites${TestReporter.reset}');
      } else {
        print('\n${TestReporter.red}${TestReporter.bold}✗ Dry run found validation issues${TestReporter.reset}');
        print('${TestReporter.yellow}Fix the issues above before running tests${TestReporter.reset}');
      }
    }
    
    final allValid = validationResults.values.every((v) => v);
    return TestSummary(
      totalTests: suites.length,
      passedTests: allValid ? suites.length : 0,
      failedTests: allValid ? 0 : suites.length,
      errorTests: 0,
      totalTime: Duration.zero,
      results: [],
    );
  }

  Future<T> _executeWithTimeout<T>(Future<T> future, Duration timeout) async {
    return await future.timeout(timeout);
  }

  TestSummary _createSummary(List<TestResult> results, Duration totalTime) {
    final passed = results.where((r) => r.status == TestStatus.pass).length;
    final failed = results.where((r) => r.status == TestStatus.fail).length;
    final errors = results.where((r) => r.status == TestStatus.error).length;

    return TestSummary(
      totalTests: results.length,
      passedTests: passed,
      failedTests: failed,
      errorTests: errors,
      totalTime: totalTime,
      results: results,
    );
  }
}