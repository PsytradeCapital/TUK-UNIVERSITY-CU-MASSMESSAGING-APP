import 'dart:math';

/// Utility class for property-based testing
class PropertyTestUtils {
  static final Random _random = Random();
  
  /// Run a property test with the specified number of iterations
  static void runPropertyTest({
    required String description,
    required bool Function() property,
    int iterations = 100,
  }) {
    for (int i = 0; i < iterations; i++) {
      try {
        final result = property();
        if (!result) {
          throw PropertyTestFailure('Property failed on iteration ${i + 1}');
        }
      } catch (e) {
        if (e is PropertyTestFailure) {
          rethrow;
        }
        throw PropertyTestFailure('Property failed on iteration ${i + 1}: $e');
      }
    }
  }

  /// Run an async property test with the specified number of iterations
  static Future<void> runAsyncPropertyTest({
    required String description,
    required Future<bool> Function() property,
    int iterations = 100,
  }) async {
    for (int i = 0; i < iterations; i++) {
      try {
        final result = await property();
        if (!result) {
          throw PropertyTestFailure('Property failed on iteration ${i + 1}');
        }
      } catch (e) {
        if (e is PropertyTestFailure) {
          rethrow;
        }
        throw PropertyTestFailure('Property failed on iteration ${i + 1}: $e');
      }
    }
  }
  
  /// Generate random string
  static String randomString({int minLength = 1, int maxLength = 20}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(_random.nextInt(chars.length)))
    );
  }
  
  /// Generate random integer
  static int randomInt({int min = 0, int max = 100}) {
    return min + _random.nextInt(max - min + 1);
  }
  
  /// Generate random boolean
  static bool randomBool() {
    return _random.nextBool();
  }
  
  /// Generate random list of strings
  static List<String> randomStringList({int minLength = 0, int maxLength = 10}) {
    final length = minLength + _random.nextInt(maxLength - minLength + 1);
    return List.generate(length, (_) => randomString());
  }
  
  /// Generate invalid CLI arguments (for testing error handling)
  static List<String> generateInvalidCliArgs() {
    final scenarios = [
      ['--invalid-option'],
      ['--category'],  // Missing value
      ['--timeout'],   // Missing value  
      ['--timeout', 'invalid'],  // Invalid timeout value
      ['--timeout', '-5'],       // Negative timeout
      ['--category', 'invalid-category'],  // Invalid category
      ['--verbose', '--quiet'],  // Conflicting options
      ['--unknown-flag'],
      ['--file'],  // Missing file value
    ];
    
    // Return one specific invalid scenario
    return scenarios[_random.nextInt(scenarios.length)];
  }
}

/// Exception thrown when a property test fails
class PropertyTestFailure extends Error {
  final String message;
  
  PropertyTestFailure(this.message);
  
  @override
  String toString() => 'PropertyTestFailure: $message';
}