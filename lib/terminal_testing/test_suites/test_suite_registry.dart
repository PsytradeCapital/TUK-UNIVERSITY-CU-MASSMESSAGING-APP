import '../core/test_suite.dart';

/// Registry for managing and discovering test suites
class TestSuiteRegistry {
  final List<TestSuite> _testSuites = [];

  /// Register a test suite
  void registerTestSuite(TestSuite testSuite) {
    _testSuites.add(testSuite);
  }

  /// Get all registered test suites
  List<TestSuite> getAllTestSuites() {
    return List.unmodifiable(_testSuites);
  }

  /// Get test suites by category
  List<TestSuite> getTestSuitesByCategory(String category) {
    return _testSuites.where((suite) => suite.category == category).toList();
  }

  /// Get test suite by name
  TestSuite? getTestSuiteByName(String name) {
    try {
      return _testSuites.firstWhere((suite) => suite.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get all available categories
  List<String> getAvailableCategories() {
    return _testSuites.map((suite) => suite.category).toSet().toList()..sort();
  }

  /// Clear all registered test suites (useful for testing)
  void clear() {
    _testSuites.clear();
  }

  /// Get count of registered test suites
  int get count => _testSuites.length;
}