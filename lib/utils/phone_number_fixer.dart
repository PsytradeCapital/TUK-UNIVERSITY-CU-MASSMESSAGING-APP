import 'package:flutter/foundation.dart';
import '../repositories/attendee_repository.dart';
import '../models/attendee_model.dart';

/// Utility to fix phone numbers in the database
/// Run this once to normalize all existing phone numbers
class PhoneNumberFixer {
  final AttendeeRepository _repository = AttendeeRepository();

  /// Fix all phone numbers in the database
  Future<Map<String, dynamic>> fixAllPhoneNumbers() async {
    debugPrint('🔧 Starting phone number fix...');
    
    int totalCount = 0;
    int fixedCount = 0;
    int alreadyValidCount = 0;
    int unfixableCount = 0;
    final List<String> unfixableNumbers = [];
    
    try {
      // Get all attendees
      final attendees = await _repository.getAllAttendees();
      totalCount = attendees.length;
      
      debugPrint('   Found $totalCount attendees to check');
      
      for (final attendee in attendees) {
        final originalPhone = attendee.phoneNumber;
        final fixedPhone = _fixPhoneNumber(originalPhone);
        
        if (fixedPhone == null) {
          // Could not fix
          unfixableCount++;
          unfixableNumbers.add('${attendee.name}: $originalPhone');
          debugPrint('   ❌ Could not fix: ${attendee.name} - $originalPhone');
          continue;
        }
        
        if (fixedPhone == originalPhone) {
          // Already valid
          alreadyValidCount++;
          debugPrint('   ✅ Already valid: ${attendee.name} - $originalPhone');
          continue;
        }
        
        // Update the phone number
        try {
          final updatedAttendee = attendee.copyWith(phoneNumber: fixedPhone);
          await _repository.updateAttendee(updatedAttendee);
          fixedCount++;
          debugPrint('   🔧 Fixed: ${attendee.name} - $originalPhone → $fixedPhone');
        } catch (e) {
          debugPrint('   ❌ Failed to update: ${attendee.name} - $e');
          unfixableCount++;
          unfixableNumbers.add('${attendee.name}: $originalPhone (update failed)');
        }
      }
      
      debugPrint('');
      debugPrint('📊 Phone Number Fix Results:');
      debugPrint('   Total attendees: $totalCount');
      debugPrint('   Already valid: $alreadyValidCount');
      debugPrint('   Fixed: $fixedCount');
      debugPrint('   Unfixable: $unfixableCount');
      
      if (unfixableNumbers.isNotEmpty) {
        debugPrint('');
        debugPrint('   Unfixable numbers:');
        for (final number in unfixableNumbers) {
          debugPrint('      - $number');
        }
      }
      
      return {
        'success': true,
        'total': totalCount,
        'alreadyValid': alreadyValidCount,
        'fixed': fixedCount,
        'unfixable': unfixableCount,
        'unfixableNumbers': unfixableNumbers,
      };
      
    } catch (e) {
      debugPrint('❌ Error fixing phone numbers: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Fix a single phone number
  /// Returns null if cannot be fixed
  /// Returns the fixed number if successful
  String? _fixPhoneNumber(String phone) {
    // Remove all whitespace
    phone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    
    if (phone.isEmpty) {
      return null;
    }
    
    // Check if already in valid format
    if (_isValidFormat(phone)) {
      return phone;
    }
    
    // Try to extract digits only
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Try different patterns
    
    // Pattern 1: +254xxxxxxxxx (13 chars)
    if (digitsOnly.startsWith('+254')) {
      if (digitsOnly.length == 13 && RegExp(r'^\+254[17]\d{8}$').hasMatch(digitsOnly)) {
        return digitsOnly;
      }
    }
    
    // Pattern 2: 254xxxxxxxxx (12 digits) - missing +
    if (digitsOnly.startsWith('254') && !digitsOnly.startsWith('+')) {
      if (digitsOnly.length == 12 && RegExp(r'^254[17]\d{8}$').hasMatch(digitsOnly)) {
        return '+$digitsOnly';
      }
    }
    
    // Pattern 3: 07xxxxxxxx or 01xxxxxxxx (10 digits)
    if (digitsOnly.startsWith('07') || digitsOnly.startsWith('01')) {
      if (digitsOnly.length == 10 && RegExp(r'^0[17]\d{8}$').hasMatch(digitsOnly)) {
        // Convert to +254 format
        return '+254${digitsOnly.substring(1)}';
      }
    }
    
    // Pattern 4: 7xxxxxxxx or 1xxxxxxxx (9 digits) - missing leading 0
    if (digitsOnly.length == 9 && RegExp(r'^[17]\d{8}$').hasMatch(digitsOnly)) {
      return '+254$digitsOnly';
    }
    
    // Could not fix
    return null;
  }

  /// Check if phone number is in valid format
  bool _isValidFormat(String phone) {
    // +254 format (13 characters)
    if (phone.startsWith('+254')) {
      return phone.length == 13 && RegExp(r'^\+254[17]\d{8}$').hasMatch(phone);
    }
    
    // 07 format (10 digits)
    if (phone.startsWith('07')) {
      return phone.length == 10 && RegExp(r'^07\d{8}$').hasMatch(phone);
    }
    
    // 01 format (10 digits)
    if (phone.startsWith('01')) {
      return phone.length == 10 && RegExp(r'^01\d{8}$').hasMatch(phone);
    }
    
    return false;
  }
}
