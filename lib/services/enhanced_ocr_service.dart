import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scanned_attendee_model.dart';
import 'dart:ui';

/// Enhanced OCR Service
/// Extracts ALL attendees from an image, not just one
/// Uses multiple strategies to find names and phone numbers
class EnhancedOCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract all attendees from recognized text
  /// Returns list of all found attendees (can be 38+ from one image)
  Future<List<ScannedAttendee>> extractAllAttendees(RecognizedText recognizedText) async {
    final allAttendees = <ScannedAttendee>[];
    final processedPhones = <String>{};

    // Strategy 1: Process each text block independently
    for (final block in recognizedText.blocks) {
      final attendees = await _extractAttendeesFromBlock(block);
      for (final attendee in attendees) {
        // Avoid duplicates based on phone number
        if (!processedPhones.contains(attendee.phoneNumber)) {
          allAttendees.add(attendee);
          processedPhones.add(attendee.phoneNumber);
        }
      }
    }

    // Strategy 2: Process entire text as table/list
    if (allAttendees.isEmpty) {
      final tableAttendees = await _extractFromTableFormat(recognizedText);
      allAttendees.addAll(tableAttendees);
    }

    return allAttendees;
  }

  /// Extract attendees from a single text block
  Future<List<ScannedAttendee>> _extractAttendeesFromBlock(TextBlock block) async {
    final attendees = <ScannedAttendee>[];
    
    // Collect all lines in the block
    final lines = block.lines.map((line) => line.text).toList();
    
    // Try to find name-phone pairs
    for (int i = 0; i < lines.length; i++) {
      final currentLine = lines[i];
      
      // Check if this line contains a phone number
      final phone = _extractPhoneNumber(currentLine);
      
      if (phone != null) {
        // Look for name in current line or previous lines
        String? name;
        String location = 'Unknown';
        
        // Try current line first
        name = _extractName(currentLine);
        
        // If no name in current line, check previous line
        if ((name == null || name.isEmpty) && i > 0) {
          name = _extractName(lines[i - 1]);
        }
        
        // If still no name, check next line
        if ((name == null || name.isEmpty) && i < lines.length - 1) {
          name = _extractName(lines[i + 1]);
        }
        
        // Try to extract location
        for (int j = i - 1; j <= i + 1 && j < lines.length; j++) {
          if (j >= 0) {
            final loc = _extractLocation(lines[j]);
            if (loc != null) {
              location = loc;
              break;
            }
          }
        }
        
        if (name != null && name.isNotEmpty) {
          attendees.add(ScannedAttendee(
            name: name,
            phoneNumber: phone,
            location: location,
            confidence: 0.8,
            sourceText: currentLine,
            boundingBox: block.boundingBox,
          ));
        }
      }
    }
    
    return attendees;
  }

  /// Extract attendees from table/list format
  /// Handles formats like:
  /// 1. John Doe    0712345678    Nairobi
  /// 2. Jane Smith  0723456789    Mombasa
  Future<List<ScannedAttendee>> _extractFromTableFormat(RecognizedText recognizedText) async {
    final attendees = <ScannedAttendee>[];
    final allText = recognizedText.text;
    
    // Split into lines
    final lines = allText.split('\n');
    
    for (final line in lines) {
      // Skip empty lines
      if (line.trim().isEmpty) continue;
      
      // Extract phone number
      final phone = _extractPhoneNumber(line);
      if (phone == null) continue;
      
      // Extract name (everything before phone number)
      final name = _extractNameFromLine(line, phone);
      if (name == null || name.isEmpty) continue;
      
      // Extract location (everything after phone number)
      final location = _extractLocationFromLine(line, phone) ?? 'Unknown';
      
      attendees.add(ScannedAttendee(
        name: name,
        phoneNumber: phone,
        location: location,
        confidence: 0.75,
        sourceText: line,
      ));
    }
    
    return attendees;
  }

  /// Extract phone number from text
  String? _extractPhoneNumber(String text) {
    // Kenyan phone patterns
    final patterns = [
      RegExp(r'(?:254|0)?([17]\d{8})'),  // 0712345678 or 254712345678
      RegExp(r'\+?254\s?([17]\d{8})'),   // +254 712345678
      RegExp(r'0([17]\d{8})'),            // 0712345678
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        String phone = match.group(1) ?? match.group(0)!;
        // Normalize to 07/01 format
        if (!phone.startsWith('0')) {
          phone = '0$phone';
        }
        return phone;
      }
    }
    
    return null;
  }

  /// Extract name from text
  String? _extractName(String text) {
    // Remove numbers and special characters
    String cleaned = text.replaceAll(RegExp(r'[0-9+\-()]'), '');
    cleaned = cleaned.trim();
    
    // Must have at least 2 words (first and last name)
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.length < 2) return null;
    
    // Must not be too long (likely not a name)
    if (cleaned.length > 50) return null;
    
    // Capitalize properly
    return words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Extract location from text
  String? _extractLocation(String text) {
    // Common Kenyan locations
    final locations = [
      'Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret',
      'Thika', 'Malindi', 'Kitale', 'Garissa', 'Kakamega',
      'Nyeri', 'Meru', 'Machakos', 'Kiambu', 'Kajiado',
    ];
    
    final textLower = text.toLowerCase();
    for (final location in locations) {
      if (textLower.contains(location.toLowerCase())) {
        return location;
      }
    }
    
    return null;
  }

  /// Extract name from line (before phone number)
  String? _extractNameFromLine(String line, String phone) {
    final phoneIndex = line.indexOf(phone);
    if (phoneIndex == -1) return null;
    
    final beforePhone = line.substring(0, phoneIndex).trim();
    
    // Remove leading numbers (like "1.", "2.", etc.)
    String cleaned = beforePhone.replaceAll(RegExp(r'^\d+\.?\s*'), '');
    
    return _extractName(cleaned);
  }

  /// Extract location from line (after phone number)
  String? _extractLocationFromLine(String line, String phone) {
    final phoneIndex = line.indexOf(phone);
    if (phoneIndex == -1) return null;
    
    final afterPhone = line.substring(phoneIndex + phone.length).trim();
    
    return _extractLocation(afterPhone);
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}
