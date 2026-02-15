import '../models/scanned_attendee_model.dart';
import '../models/attendee_model.dart';
import '../repositories/attendee_repository.dart';

/// Service for smart matching of scanned attendees with existing database records
class SmartMatchingService {
  final AttendeeRepository _attendeeRepository = AttendeeRepository();

  /// Match scanned attendees with existing members in the database
  Future<MatchingResult> matchAttendees({
    required List<ScannedAttendee> scannedAttendees,
    double confidenceThreshold = 0.8,
  }) async {
    final matches = <AttendeeMatch>[];
    final unmatchedAttendees = <ScannedAttendee>[];

    // Get all existing members from database
    final existingMembers = await _attendeeRepository.getAllAttendees();

    // Match each scanned attendee
    for (final attendee in scannedAttendees) {
      final match = _findBestMatch(attendee, existingMembers);
      
      if (match != null && match.confidence >= confidenceThreshold) {
        matches.add(AttendeeMatch(
          scannedAttendee: attendee,
          existingMember: match.member,
          matchConfidence: match.confidence,
          matchType: _getMatchType(match.confidence),
        ));
      } else {
        unmatchedAttendees.add(attendee);
      }
    }

    return MatchingResult(
      matches: matches,
      unmatchedAttendees: unmatchedAttendees,
      totalScanned: scannedAttendees.length,
      totalMatched: matches.length,
    );
  }

  /// Find the best matching member for a scanned attendee
  MemberMatch? _findBestMatch(ScannedAttendee attendee, List<AttendeeModel> members) {
    MemberMatch? bestMatch;
    double highestScore = 0.0;

    for (final member in members) {
      final match = _calculateMatchScore(attendee, member);
      
      if (match.confidence > highestScore) {
        highestScore = match.confidence;
        bestMatch = match;
      }
    }

    // Only return matches with confidence above 0.7
    return (bestMatch != null && bestMatch.confidence >= 0.7) ? bestMatch : null;
  }

  /// Calculate match score between scanned attendee and existing member
  MemberMatch _calculateMatchScore(ScannedAttendee attendee, AttendeeModel member) {
    double totalScore = 0.0;
    int factors = 0;

    // Name matching (fuzzy)
    final nameScore = _calculateNameSimilarity(
      attendee.name.toLowerCase(),
      member.name.toLowerCase(),
    );
    totalScore += nameScore * 0.6; // 60% weight
    factors++;

    // Phone number matching (exact)
    final phoneScore = _calculatePhoneSimilarity(
      attendee.phoneNumber,
      member.phoneNumber,
    );
    totalScore += phoneScore * 0.4; // 40% weight
    factors++;

    final confidence = factors > 0 ? totalScore / factors : 0.0;

    return MemberMatch(
      member: member,
      confidence: confidence,
    );
  }

  /// Calculate name similarity using Levenshtein distance
  double _calculateNameSimilarity(String name1, String name2) {
    if (name1 == name2) return 1.0;
    if (name1.isEmpty || name2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(name1, name2);
    final maxLength = name1.length > name2.length ? name1.length : name2.length;
    
    return 1.0 - (distance / maxLength);
  }

  /// Calculate phone number similarity
  double _calculatePhoneSimilarity(String phone1, String phone2) {
    // Normalize phone numbers (remove spaces, dashes, country codes)
    final normalized1 = _normalizePhoneNumber(phone1);
    final normalized2 = _normalizePhoneNumber(phone2);

    if (normalized1 == normalized2) return 1.0;
    
    // Check if one ends with the other (handles country code differences)
    if (normalized1.endsWith(normalized2) || normalized2.endsWith(normalized1)) {
      return 0.9;
    }

    return 0.0;
  }

  /// Normalize phone number for comparison
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    String normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading country codes (254 for Kenya, 1 for US, etc.)
    if (normalized.startsWith('254') && normalized.length > 10) {
      normalized = normalized.substring(3);
    } else if (normalized.startsWith('1') && normalized.length == 11) {
      normalized = normalized.substring(1);
    } else if (normalized.startsWith('0') && normalized.length > 9) {
      normalized = normalized.substring(1);
    }
    
    return normalized;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Get match type based on confidence score
  MatchType _getMatchType(double confidence) {
    if (confidence >= 0.95) return MatchType.exact;
    if (confidence >= 0.9) return MatchType.high;
    if (confidence >= 0.8) return MatchType.medium;
    if (confidence >= 0.7) return MatchType.low;
    return MatchType.none;
  }
}

/// Result of matching operation
class MatchingResult {
  final List<AttendeeMatch> matches;
  final List<ScannedAttendee> unmatchedAttendees;
  final int totalScanned;
  final int totalMatched;

  MatchingResult({
    required this.matches,
    required this.unmatchedAttendees,
    required this.totalScanned,
    required this.totalMatched,
  });

  double get matchRate => totalScanned > 0 ? totalMatched / totalScanned : 0.0;
}

/// A matched attendee with confidence score
class AttendeeMatch {
  final ScannedAttendee scannedAttendee;
  final AttendeeModel existingMember;
  final double matchConfidence;
  final MatchType matchType;

  AttendeeMatch({
    required this.scannedAttendee,
    required this.existingMember,
    required this.matchConfidence,
    required this.matchType,
  });
}

/// Internal match result
class MemberMatch {
  final AttendeeModel member;
  final double confidence;

  MemberMatch({
    required this.member,
    required this.confidence,
  });
}

/// Type of match
enum MatchType {
  exact,   // 95%+ confidence
  high,    // 90-95% confidence
  medium,  // 80-90% confidence
  low,     // 70-80% confidence
  none,    // <70% confidence
}
