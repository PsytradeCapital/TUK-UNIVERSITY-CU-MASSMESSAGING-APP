// Test script to verify mass messaging personalization functionality
import 'lib/services/sms_manager.dart';

void main() {
  final smsManager = SMSManager();
  
  print('=== TUK CU Mass Messaging Personalization Test ===\n');
  
  // Test cases for personalization
  final testCases = [
    {
      'name': 'John Doe',
      'message': 'Hello {name}, welcome to TUK CU service!',
      'expected': 'Hello John Doe, welcome to TUK CU service!'
    },
    {
      'name': 'Mary Smith', 
      'message': 'Hi {Name}, your attendance has been recorded.',
      'expected': 'Hi Mary Smith, your attendance has been recorded.'
    },
    {
      'name': 'Peter Wilson',
      'message': 'URGENT {NAME}: Please check your registration status.',
      'expected': 'URGENT PETER WILSON: Please check your registration status.'
    },
    {
      'name': 'Sarah Johnson',
      'message': 'Service reminder for [name] - starts at 9 AM.',
      'expected': 'Service reminder for Sarah Johnson - starts at 9 AM.'
    },
    {
      'name': 'David Brown',
      'message': 'Thank you for attending today\'s service.',
      'expected': 'Hi David Brown, Thank you for attending today\'s service.'
    },
    {
      'name': 'Grace Mwangi',
      'message': 'Grace Mwangi, your registration is complete.',
      'expected': 'Grace Mwangi, your registration is complete.'
    }
  ];
  
  bool allTestsPassed = true;
  
  for (int i = 0; i < testCases.length; i++) {
    final testCase = testCases[i];
    final result = smsManager.personalizeMessage(
      testCase['message']!, 
      testCase['name']!
    );
    
    final passed = result == testCase['expected'];
    allTestsPassed = allTestsPassed && passed;
    
    print('Test ${i + 1}: ${passed ? "✅ PASS" : "❌ FAIL"}');
    print('Name: ${testCase['name']}');
    print('Template: ${testCase['message']}');
    print('Expected: ${testCase['expected']}');
    print('Got:      $result');
    print('');
  }
  
  print('=== SUMMARY ===');
  print('Overall Result: ${allTestsPassed ? "✅ ALL TESTS PASSED" : "❌ SOME TESTS FAILED"}');
  
  if (allTestsPassed) {
    print('\n🎉 Mass messaging personalization is working correctly!');
    print('✅ {name} placeholders are replaced with attendee names');
    print('✅ Multiple placeholder formats supported: {name}, {Name}, {NAME}, [name], etc.');
    print('✅ Auto-greeting added when no placeholders found');
    print('✅ Name detection prevents duplicate greetings');
  }
}