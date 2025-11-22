import 'dart:async';
import '../models/attendee_model.dart';
import '../repositories/attendee_repository.dart';

// AttendeeCategory is exported from attendee_model.dart

class SearchEngine {
  final AttendeeRepository _attendeeRepository = AttendeeRepository();
  Timer? _debounceTimer;
  
  // Debounce duration for real-time search performance
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  // Perform fuzzy search with debouncing for real-time search
  Future<List<AttendeeSearchResult>> fuzzySearchWithDebounce(
    String query,
    Function(List<AttendeeSearchResult>) onResults,
  ) async {
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();
    
    // Set up new timer for debounced search
    _debounceTimer = Timer(_debounceDuration, () async {
      final results = await fuzzySearch(query);
      onResults(results);
    });
    
    return [];
  }

  // Main fuzzy search method
  Future<List<AttendeeSearchResult>> fuzzySearch(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // Get all attendees from database
      final allAttendees = await _attendeeRepository.getAllAttendees();
      
      if (allAttendees.isEmpty) {
        return [];
      }

      // Calculate similarity scores for each attendee
      final List<AttendeeSearchResult> searchResults = [];
      
      for (final attendee in allAttendees) {
        final similarity = calculateSimilarity(attendee.name, query);
        
        // Only include results with reasonable similarity (threshold: 0.3)
        if (similarity >= 0.3) {
          searchResults.add(AttendeeSearchResult(
            attendee: attendee,
            similarity: similarity,
            matchedText: _getMatchedText(attendee.name, query),
          ));
        }
      }

      // Rank and return results
      return rankResults(searchResults, query);
    } catch (e) {
      throw SearchEngineException('Fuzzy search failed: $e');
    }
  }

  // Calculate similarity between two strings using multiple algorithms
  double calculateSimilarity(String name1, String name2) {
    if (name1.isEmpty || name2.isEmpty) return 0.0;
    
    // Normalize strings for comparison
    final normalizedName1 = name1.toLowerCase().trim();
    final normalizedName2 = name2.toLowerCase().trim();
    
    // Exact match gets highest score
    if (normalizedName1 == normalizedName2) return 1.0;
    
    // Calculate different similarity metrics and combine them
    final levenshteinSim = _levenshteinSimilarity(normalizedName1, normalizedName2);
    final jaccardSim = _jaccardSimilarity(normalizedName1, normalizedName2);
    final substringBonus = _substringBonus(normalizedName1, normalizedName2);
    final startsWithBonus = _startsWithBonus(normalizedName1, normalizedName2);
    
    // Weighted combination of different similarity measures
    final combinedScore = (levenshteinSim * 0.4) + 
                         (jaccardSim * 0.3) + 
                         (substringBonus * 0.2) + 
                         (startsWithBonus * 0.1);
    
    return combinedScore.clamp(0.0, 1.0);
  }

  // Rank search results based on similarity and other factors
  List<AttendeeSearchResult> rankResults(List<AttendeeSearchResult> results, String query) {
    // Sort by similarity score (descending), then by attendance count (descending)
    results.sort((a, b) {
      // Primary sort: similarity score
      final similarityComparison = b.similarity.compareTo(a.similarity);
      if (similarityComparison != 0) return similarityComparison;
      
      // Secondary sort: attendance count (higher attendance = more frequent attendee)
      final attendanceComparison = b.attendee.attendanceCount.compareTo(a.attendee.attendanceCount);
      if (attendanceComparison != 0) return attendanceComparison;
      
      // Tertiary sort: alphabetical by name
      return a.attendee.name.compareTo(b.attendee.name);
    });
    
    // Limit results to top 10 for performance
    return results.take(10).toList();
  }

  // Levenshtein distance-based similarity
  double _levenshteinSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    
    if (maxLength == 0) return 1.0;
    
    return 1.0 - (distance / maxLength);
  }

  // Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );
    
    // Initialize first row and column
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    
    // Fill the matrix
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[s1.length][s2.length];
  }

  // Jaccard similarity based on character n-grams
  double _jaccardSimilarity(String s1, String s2) {
    final set1 = _generateNGrams(s1, 2).toSet();
    final set2 = _generateNGrams(s2, 2).toSet();
    
    if (set1.isEmpty && set2.isEmpty) return 1.0;
    if (set1.isEmpty || set2.isEmpty) return 0.0;
    
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    
    return intersection / union;
  }

  // Generate n-grams from a string
  List<String> _generateNGrams(String text, int n) {
    if (text.length < n) return [text];
    
    final List<String> ngrams = [];
    for (int i = 0; i <= text.length - n; i++) {
      ngrams.add(text.substring(i, i + n));
    }
    return ngrams;
  }

  // Bonus for substring matches
  double _substringBonus(String name, String query) {
    if (name.contains(query)) {
      // Longer matches get higher bonus
      return (query.length / name.length) * 0.5;
    }
    return 0.0;
  }

  // Bonus for names that start with the query
  double _startsWithBonus(String name, String query) {
    if (name.startsWith(query)) {
      return 0.3; // Fixed bonus for starts-with matches
    }
    return 0.0;
  }

  // Get highlighted/matched text for display
  String _getMatchedText(String name, String query) {
    final normalizedName = name.toLowerCase();
    final normalizedQuery = query.toLowerCase();
    
    // Find the best matching substring
    int bestStart = -1;
    int bestLength = 0;
    
    // Look for exact substring match first
    final exactIndex = normalizedName.indexOf(normalizedQuery);
    if (exactIndex != -1) {
      bestStart = exactIndex;
      bestLength = query.length;
    } else {
      // Look for partial matches
      for (int i = 0; i < normalizedName.length; i++) {
        for (int j = 1; j <= normalizedQuery.length && i + j <= normalizedName.length; j++) {
          final substring = normalizedName.substring(i, i + j);
          if (normalizedQuery.startsWith(substring) && j > bestLength) {
            bestStart = i;
            bestLength = j;
          }
        }
      }
    }
    
    if (bestStart != -1) {
      return name.substring(bestStart, bestStart + bestLength);
    }
    
    return name; // Return full name if no specific match found
  }

  // Search attendees by phone number (exact match)
  Future<AttendeeModel?> searchByPhoneNumber(String phoneNumber) async {
    try {
      return await _attendeeRepository.getAttendeeByPhone(phoneNumber);
    } catch (e) {
      throw SearchEngineException('Phone number search failed: $e');
    }
  }

  // Search attendees by multiple criteria
  Future<List<AttendeeSearchResult>> advancedSearch({
    String? nameQuery,
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
    int? minAttendance,
  }) async {
    try {
      // Use repository filter if we have year/location/category filters
      List<AttendeeModel> candidates;
      if (years != null || locations != null || categories != null) {
        candidates = await _attendeeRepository.getAttendeesWithFilters(
          years: years,
          locations: locations,
          categories: categories,
        );
      } else {
        candidates = await _attendeeRepository.getAllAttendees();
      }
      
      // Filter by minimum attendance
      if (minAttendance != null) {
        candidates = candidates.where((a) => a.attendanceCount >= minAttendance).toList();
      }
      
      // Apply name-based fuzzy search if provided
      if (nameQuery != null && nameQuery.trim().isNotEmpty) {
        final List<AttendeeSearchResult> searchResults = [];
        
        for (final attendee in candidates) {
          final similarity = calculateSimilarity(attendee.name, nameQuery);
          
          if (similarity >= 0.3) {
            searchResults.add(AttendeeSearchResult(
              attendee: attendee,
              similarity: similarity,
              matchedText: _getMatchedText(attendee.name, nameQuery),
            ));
          }
        }
        
        return rankResults(searchResults, nameQuery);
      } else {
        // Return all candidates as search results with similarity 1.0
        return candidates.map((attendee) => AttendeeSearchResult(
          attendee: attendee,
          similarity: 1.0,
          matchedText: attendee.name,
        )).toList();
      }
    } catch (e) {
      throw SearchEngineException('Advanced search failed: $e');
    }
  }

  // Cancel any pending debounced search
  void cancelPendingSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // Dispose resources
  void dispose() {
    cancelPendingSearch();
  }
}

// Search result class that includes similarity score and matched text
class AttendeeSearchResult {
  final AttendeeModel attendee;
  final double similarity;
  final String matchedText;

  AttendeeSearchResult({
    required this.attendee,
    required this.similarity,
    required this.matchedText,
  });

  // Get masked phone number for display (show only last 4 digits)
  String get maskedPhoneNumber {
    final phone = attendee.phoneNumber;
    if (phone.length <= 4) return phone;
    
    final visiblePart = phone.substring(phone.length - 4);
    final maskedPart = '*' * (phone.length - 4);
    return '$maskedPart$visiblePart';
  }

  @override
  String toString() {
    return 'AttendeeSearchResult(name: ${attendee.name}, similarity: ${similarity.toStringAsFixed(2)}, attendance: ${attendee.attendanceCount})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendeeSearchResult &&
        other.attendee.id == attendee.id &&
        other.similarity == similarity;
  }

  @override
  int get hashCode => Object.hash(attendee.id, similarity);
}

// Custom exception for search engine operations
class SearchEngineException implements Exception {
  final String message;
  
  SearchEngineException(this.message);
  
  @override
  String toString() => 'SearchEngineException: $message';
}