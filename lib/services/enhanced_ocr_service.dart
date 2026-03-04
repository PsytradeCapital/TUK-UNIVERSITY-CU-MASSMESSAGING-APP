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

    print('=== ENHANCED OCR DEBUG ===');
    print('Total blocks: ${recognizedText.blocks.length}');
    print('Full text length: ${recognizedText.text.length}');
    print('Full text preview: ${recognizedText.text.substring(0, recognizedText.text.length > 200 ? 200 : recognizedText.text.length)}');

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

    print('Strategy 1 (blocks): Found ${allAttendees.length} attendees');

    // Strategy 2: Process entire text as table/list
    final tableAttendees = await _extractFromTableFormat(recognizedText);
    for (final attendee in tableAttendees) {
      if (!processedPhones.contains(attendee.phoneNumber)) {
        allAttendees.add(attendee);
        processedPhones.add(attendee.phoneNumber);
      }
    }

    print('Strategy 2 (table): Found ${tableAttendees.length} new attendees');
    print('Total attendees found: ${allAttendees.length}');
    print('=== END DEBUG ===');

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
    
    print('Processing ${lines.length} lines for table format...');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Skip empty lines
      if (line.trim().isEmpty) continue;
      
      // Extract phone number
      final phone = _extractPhoneNumber(line);
      if (phone == null) continue;
      
      print('Line $i: Found phone $phone in: ${line.substring(0, line.length > 50 ? 50 : line.length)}');
      
      // Extract name (everything before phone number)
      String? name = _extractNameFromLine(line, phone);
      
      // If no name in current line, check previous/next lines
      if (name == null || name.isEmpty) {
        if (i > 0) {
          name = _extractName(lines[i - 1]);
        }
        if ((name == null || name.isEmpty) && i < lines.length - 1) {
          name = _extractName(lines[i + 1]);
        }
      }
      
      if (name == null || name.isEmpty) {
        print('  -> No name found, skipping');
        continue;
      }
      
      // Extract location (everything after phone number)
      final location = _extractLocationFromLine(line, phone) ?? 'Unknown';
      
      print('  -> Extracted: $name | $phone | $location');
      
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
    // Kenyan phone patterns - more flexible
    final patterns = [
      RegExp(r'(?:254|0)?([17]\d{8})'),  // 0712345678 or 254712345678
      RegExp(r'\+?254\s?([17]\d{8})'),   // +254 712345678
      RegExp(r'0([17]\d{8})'),            // 0712345678
      RegExp(r'([17]\d{8})'),             // 712345678 (without leading 0)
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        String phone = match.group(1) ?? match.group(0)!;
        // Normalize to 07/01 format
        if (!phone.startsWith('0')) {
          phone = '0$phone';
        }
        // Validate length
        if (phone.length == 10 && (phone.startsWith('07') || phone.startsWith('01'))) {
          return phone;
        }
      }
    }
    
    return null;
  }

  /// Extract name from text
  String? _extractName(String text) {
    // Remove numbers and special characters
    String cleaned = text.replaceAll(RegExp(r'[0-9+\-()]'), '');
    cleaned = cleaned.trim();
    
    // Must have at least 2 characters (can be single word for testing)
    if (cleaned.length < 2) return null;
    
    // Must not be too long (likely not a name)
    if (cleaned.length > 50) return null;
    
    // Split into words
    final words = cleaned.split(RegExp(r'\s+'));
    
    // Filter out empty words and very short words
    final validWords = words.where((word) => word.length >= 2).toList();
    
    if (validWords.isEmpty) return null;
    
    // Capitalize properly
    return validWords.map((word) {
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
