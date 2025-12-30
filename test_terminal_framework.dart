import 'lib/terminal_testing/cli/main.dart' as terminal_main;

void main() async {
  print('Testing Terminal Testing Framework...');
  
  try {
    // Test with help flag
    await terminal_main.main(['--help']);
  } catch (e) {
    print('Error running terminal framework: $e');
  }
}