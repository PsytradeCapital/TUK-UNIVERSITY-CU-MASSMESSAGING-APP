import 'package:flutter_test/flutter_test.dart';
import '../lib/services/sms_manager.dart';

void main() {
  group('Mass Messaging Personalization Tests', () {
    late SMSManager smsManager;

    setUp(() {
      smsManager = SMSManager();
    });

    test('should replace {name} with attendee name', () {
      const message = 'Hello {name}, welcome to TUK CU service!';
      const attendeeName = 'John Doe';
      const expected = 'Hello John Doe, welcome to TUK CU service!';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should replace {Name} with attendee name', () {
      const message = 'Hi {Name}, your attendance has been recorded.';
      const attendeeName = 'Mary Smith';
      const expected = 'Hi Mary Smith, your attendance has been recorded.';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should replace {NAME} with uppercase attendee name', () {
      const message = 'URGENT {NAME}: Please check your registration status.';
      const attendeeName = 'Peter Wilson';
      const expected = 'URGENT PETER WILSON: Please check your registration status.';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should replace [name] bracket format', () {
      const message = 'Service reminder for [name] - starts at 9 AM.';
      const attendeeName = 'Sarah Johnson';
      const expected = 'Service reminder for Sarah Johnson - starts at 9 AM.';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should add greeting when no placeholders found', () {
      const message = 'Thank you for attending today\'s service.';
      const attendeeName = 'David Brown';
      const expected = 'Hi David Brown, Thank you for attending today\'s service.';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should not add greeting when name already in message', () {
      const message = 'Grace Mwangi, your registration is complete.';
      const attendeeName = 'Grace Mwangi';
      const expected = 'Grace Mwangi, your registration is complete.';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should handle multiple placeholders in one message', () {
      const message = 'Hello {name}, {Name} your seat is reserved.';
      const attendeeName = 'Alice Cooper';
      const expected = 'Hello Alice Cooper, Alice Cooper your seat is reserved.';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });

    test('should handle empty message', () {
      const message = '';
      const attendeeName = 'Test User';
      const expected = 'Hi Test User, ';
      
      final result = smsManager.personalizeMessage(message, attendeeName);
      
      expect(result, equals(expected));
    });
  });
}