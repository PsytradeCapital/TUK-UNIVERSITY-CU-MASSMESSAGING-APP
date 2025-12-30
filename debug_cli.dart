import 'lib/terminal_testing/cli/cli_parser.dart';

void main() {
  try {
    final config = CliParser.parseArguments(['--file', 'not_a_test.dart']);
    print('Config created: $config');
  } catch (e) {
    print('Error caught: $e');
    print('Error type: ${e.runtimeType}');
  }
}