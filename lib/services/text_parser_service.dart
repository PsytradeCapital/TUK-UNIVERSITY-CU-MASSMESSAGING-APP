/// Text Parser Service
/// Parses bulk text input into attendee records
/// Supports multiple formats and validates data
class TextParserService {
  /// Parse attendee text into list of parsed attendees
  /// Supports formats:
  /// - Name, Phone, Location
  /// - Name | Phone | Location
  /// - Name  Phone  Location (tab/space separated)
  Future<List<ParsedAttendee>> parseAttendeeText(String text) async {
    final attendees = <ParsedAttendee>[];
    
    // Split into lines
    final lines = text.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      final parsed = _parseLine(trimmed);
      if (parsed != null) {
        attendees.add(parsed);
      }
    }
    
    return attendees;
  }

  /// Parse a single line
  ParsedAttendee? _parseLine(String line) {
    // Try comma-separated
    if (line.contains(',')) {
      return _parseCommaSeparated(line);
    }
    
    // Try pipe-separated
    if (line.contains('|')) {
      return _pipeSeparated(line);
    }
    
    // Try space/tab separated
    return _parseSpaceSeparated(line);
  }

  /// Parse comma-separated format: Name, Phone, Location
  ParsedAttendee? _parseCommaSeparated(String line) {
    final parts = line.split(',').map((p) => p.trim()).toList();
    
    if (parts.length < 2) return null;
    
    final name = parts[0];
    final phone = _extractPhone(parts[1]);
    final location = parts.length > 2 ? parts[2] : 'Unknown';
    
    return ParsedAttendee(
      name: name,
      phoneNumber: phone ?? '',
      location: location,
      isValid: phone != null && name.isNotEmpty,
    );
  }

  /// Parse pipe-separated format: Name | Phone | Location
  ParsedAttendee? _pipeSeparated(String line) {
    final parts = line.split('|').map((p) => p.trim()).toList();
    
    if (parts.length < 2) return null;
    
    final name = parts[0];
    final phone = _extractPhone(parts[1]);
    final location = parts.length > 2 ? parts[2] : 'Unknown';
    
    return ParsedAttendee(
      name: name,
      phoneNumber: phone ?? '',
      location: location,
      isValid: phone != null && name.isNotEmpty,
    );
  }

  /// Parse space/tab separated format: Name  Phone  Location
  ParsedAttendee? _parseSpaceSeparated(String line) {
    // Extract phone number first
    final phone = _extractPhone(line);
    if (phone == null) return null;
    
    // Split by phone to get name and location
    final phoneIndex = line.indexOf(phone);
    final beforePhone = line.substring(0, phoneIndex).trim();
    final afterPhone = line.substring(phoneIndex + phone.length).trim();
    
    final name = beforePhone.isNotEmpty ? beforePhone : 'Unknown';
    final location = afterPhone.isNotEmpty ? afterPhone : 'Unknown';
    
    return ParsedAttendee(
      name: name,
      phoneNumber: phone,
      location: location,
      isValid: name != 'Unknown',
    );
  }

  /// Extract phone number from text and return in 07/01 local format
  String? _extractPhone(String text) {
    // Kenyan phone patterns — order matters (most specific first)
    final patterns = [
      RegExp(r'\+254([17]\d{8})'),   // +254712345678
      RegExp(r'254([17]\d{8})'),     // 254712345678 (no +)
      RegExp(r'0([17]\d{8})'),       // 0712345678
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final digits = match.group(1)!;
        final phone = '0$digits'; // normalise to 07/01 format
        if (phone.length == 10) return phone;
      }
    }

    return null;
  }
}

/// Parsed attendee model
class ParsedAttendee {
  final String name;
  final String phoneNumber;
  final String location;
  final bool isValid;

  ParsedAttendee({
    required this.name,
    required this.phoneNumber,
    required this.location,
    required this.isValid,
  });
}
