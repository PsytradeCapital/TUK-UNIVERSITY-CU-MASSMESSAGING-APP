import 'dart:io';

/// Custom exception for exit calls in tests
class ExitException implements Exception {
  final int code;
  ExitException(this.code);
}

/// Configuration for terminal test execution
class TestConfig {
  final List<String>? categories;
  final bool verbose;
  final bool quiet;
  final Duration? timeout;
  final bool dryRun;
  final bool showHelp;
  final String? testFile;

  const TestConfig({
    this.categories,
    this.verbose = false,
    this.quiet = false,
    this.timeout,
    this.dryRun = false,
    this.showHelp = false,
    this.testFile,
  });
}

/// Parses command line arguments for the terminal testing framework
class CliParser {
  static const List<String> validCategories = [
    'auth',
    'attendance', 
    'sync',
    'personalization',
    'integration'
  ];

  /// Parse command line arguments and return configuration
  static TestConfig parseArguments(List<String> args) {
    List<String>? categories;
    bool verbose = false;
    bool quiet = false;
    Duration? timeout;
    bool dryRun = false;
    bool showHelp = false;
    String? testFile;

    // Handle empty arguments
    if (args.isEmpty) {
      return const TestConfig();
    }

    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      
      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
          
        case '--verbose':
        case '-v':
          verbose = true;
          break;
          
        case '--quiet':
        case '-q':
          quiet = true;
          break;
          
        case '--dry-run':
          dryRun = true;
          break;
          
        case '--category':
        case '-c':
          if (i + 1 >= args.length) {
            throw ArgumentError('--category requires a value. Available categories: ${validCategories.join(', ')}');
          }
          final category = args[++i];
          if (!validCategories.contains(category)) {
            throw ArgumentError(
              'Invalid category: "$category". Valid categories: ${validCategories.join(', ')}'
            );
          }
          categories ??= [];
          categories.add(category);
          break;
          
        case '--timeout':
        case '-t':
          if (i + 1 >= args.length) {
            throw ArgumentError('--timeout requires a value (positive integer in seconds)');
          }
          final timeoutStr = args[++i];
          final timeoutSeconds = int.tryParse(timeoutStr);
          if (timeoutSeconds == null || timeoutSeconds <= 0) {
            throw ArgumentError('Timeout must be a positive integer (seconds). Got: "$timeoutStr"');
          }
          if (timeoutSeconds > 3600) { // 1 hour max
            throw ArgumentError('Timeout cannot exceed 3600 seconds (1 hour). Got: $timeoutSeconds');
          }
          timeout = Duration(seconds: timeoutSeconds);
          break;
          
        case '--file':
        case '-f':
          if (i + 1 >= args.length) {
            throw ArgumentError('--file requires a file path');
          }
          testFile = args[++i];
          // Validate file exists and is a test file
          if (!File(testFile).existsSync()) {
            throw ArgumentError('Test file not found: "$testFile"');
          }
          if (!testFile.endsWith('_test.dart')) {
            throw ArgumentError('File must be a test file (ending with _test.dart): "$testFile"');
          }
          break;
          
        default:
          if (arg.startsWith('-')) {
            throw ArgumentError('Unknown option: "$arg". Use --help for available options.');
          }
          // Treat as positional argument (test file)
          if (testFile != null) {
            throw ArgumentError('Multiple test files specified. Use --file for explicit file specification.');
          }
          testFile = arg;
          // Validate positional test file
          if (!File(testFile).existsSync()) {
            throw ArgumentError('Test file not found: "$testFile"');
          }
          if (!testFile.endsWith('_test.dart')) {
            throw ArgumentError('File must be a test file (ending with _test.dart): "$testFile"');
          }
          break;
      }
    }

    // Validate conflicting options
    if (verbose && quiet) {
      throw ArgumentError('Cannot use both --verbose and --quiet options');
    }

    // Validate category and file combinations
    if (testFile != null && categories != null && categories.isNotEmpty) {
      throw ArgumentError('Cannot specify both --category and --file options');
    }

    return TestConfig(
      categories: categories,
      verbose: verbose,
      quiet: quiet,
      timeout: timeout,
      dryRun: dryRun,
      showHelp: showHelp,
      testFile: testFile,
    );
  }

  /// Display available categories and usage information
  static void displayUsageError(String error) {
    print('Error: $error\n');
    displayUsage();
    exit(1);
  }

  /// Display available categories and usage information (testable version)
  static void displayUsageErrorTestable(String error) {
    print('Error: $error\n');
    displayUsage();
    throw ExitException(1);
  }

  /// Display comprehensive usage information
  static void displayUsage() {
    print('''
Terminal Testing Framework

USAGE:
    dart run lib/terminal_testing/cli/main.dart [OPTIONS] [FILE]

DESCRIPTION:
    Run comprehensive tests for the Flutter attendance app directly from the 
    command line without requiring device connections. Tests use mock environments
    to simulate external dependencies.

OPTIONS:
    -h, --help              Show this help message and exit
    -v, --verbose           Enable verbose output with detailed test information
    -q, --quiet             Enable quiet mode with minimal output
    -c, --category <CAT>    Run tests from specific category only
                           Can be used multiple times for multiple categories
    -t, --timeout <SEC>     Set custom timeout in seconds (default: 30)
    -f, --file <PATH>       Run a specific test file
        --dry-run           Validate test setup without executing tests

CATEGORIES:
    ${validCategories.map((cat) => '    $cat').join('\n')}

EXAMPLES:
    # Run all tests
    dart run lib/terminal_testing/cli/main.dart

    # Run only authentication tests
    dart run lib/terminal_testing/cli/main.dart --category auth

    # Run multiple categories with verbose output
    dart run lib/terminal_testing/cli/main.dart -c auth -c sync --verbose

    # Run with custom timeout
    dart run lib/terminal_testing/cli/main.dart --timeout 60

    # Validate setup without running tests
    dart run lib/terminal_testing/cli/main.dart --dry-run

    # Run a specific test file
    dart run lib/terminal_testing/cli/main.dart --file test/auth_test.dart

    # Quiet mode for CI/CD
    dart run lib/terminal_testing/cli/main.dart --quiet

EXIT CODES:
    0    All tests passed
    1    Some tests failed or error occurred

For more information, visit: https://github.com/your-repo/terminal-testing-framework
''');
  }
}