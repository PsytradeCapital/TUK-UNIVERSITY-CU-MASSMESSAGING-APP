/// Base class for all test collections in the terminal testing framework
abstract class TestSuite {
  /// The name of this test suite
  String get name;
  
  /// The category this test suite belongs to (auth, attendance, sync, personalization, integration)
  String get category;
  
  /// Execute all tests in this suite and return results
  Future<List<TestResult>> execute();
}

/// Represents the outcome of a single test execution
class TestResult {
  final String testName;
  final TestStatus status;
  final String? message;
  final Duration executionTime;
  final String? stackTrace;

  const TestResult({
    required this.testName,
    required this.status,
    this.message,
    required this.executionTime,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'TestResult(name: $testName, status: $status, time: ${executionTime.inMilliseconds}ms)';
  }
}

/// Status of a test execution
enum TestStatus {
  pass,
  fail,
  error,
}

/// Summary of all test executions
class TestSummary {
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final int errorTests;
  final Duration totalTime;
  final List<TestResult> results;

  const TestSummary({
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.errorTests,
    required this.totalTime,
    required this.results,
  });

  /// Calculate success percentage
  double get successPercentage {
    if (totalTests == 0) return 0.0;
    return (passedTests / totalTests) * 100;
  }

  @override
  String toString() {
    return 'TestSummary(total: $totalTests, passed: $passedTests, failed: $failedTests, errors: $errorTests, success: ${successPercentage.toStringAsFixed(1)}%)';
  }
}