import 'dart:io';
import 'dart:async';
import 'cli_parser.dart';
import '../core/terminal_test_runner.dart';
import '../core/test_suite.dart';
import '../reporters/test_reporter.dart';
import '../mocks/mock_environment.dart';
import '../test_suites/test_suite_registry.dart';

/// Main entry point for the terminal testing framework CLI
/// Wires together all components: TestRunner, Reporter, MockEnvironment, and TestSuites
Future<void> main(List<String> args) async {
  int exitCode = 0;
  MockEnvironment? mockEnv;
  TestConfig? config;
  
  try {
    config = CliParser.parseArguments(args);
    
    if (config.showHelp) {
      CliParser.displayUsage();
      exit(0);
    }

    // Initialize components with proper wiring
    mockEnv = MockEnvironment();
    final reporter = TestReporter(verbose: config.verbose, quiet: config.quiet);
    final registry = TestSuiteRegistry();
    
    // Create runner with all components wired together
    final runner = TerminalTestRunner(
      reporter: reporter,
      registry: registry,
      defaultTimeout: config.timeout,
      mockEnvironment: mockEnv,
    );
    
    // Setup mock environment for test execution
    if (!config.dryRun) {
      mockEnv.setup();
    }
    
    late final TestSummary summary;
    if (config.testFile != null) {
      // Validate test file exists before execution
      if (!runner.isValidTestFile(config.testFile!)) {
        throw ArgumentError('Invalid test file: ${config.testFile}. File must exist and end with _test.dart');
      }
      summary = await runner.runTestFile(config.testFile!);
    } else {
      summary = await runner.runTests(
        categories: config.categories,
        verbose: config.verbose,
        quiet: config.quiet,
        timeout: config.timeout,
        dryRun: config.dryRun,
      );
    }
    
    // Set exit code based on test results
    if (summary.failedTests > 0 || summary.errorTests > 0) {
      exitCode = 1;
    }
    
  } catch (e) {
    if (e is ArgumentError) {
      CliParser.displayUsageError(e.message);
      // displayUsageError already calls exit(1)
    } else {
      stderr.writeln('${TestReporter.red}${TestReporter.bold}Fatal Error:${TestReporter.reset} $e');
      if (e is TimeoutException) {
        stderr.writeln('${TestReporter.yellow}Tip: Try increasing timeout with --timeout flag${TestReporter.reset}');
      }
      exitCode = 1;
    }
  } finally {
    // Ensure proper cleanup of mock environment
    try {
      mockEnv?.teardown();
    } catch (e) {
      if (!(config?.quiet ?? false)) {
        stderr.writeln('${TestReporter.yellow}Warning: Error during cleanup: $e${TestReporter.reset}');
      }
    }
  }
  
  exit(exitCode);
}