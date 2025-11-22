import '../models/attendee_model.dart';
import '../repositories/attendee_repository.dart';
import '../providers/service_session_provider.dart';

class RegistrationService {
  final AttendeeRepository _attendeeRepository = AttendeeRepository();
  final ServiceSessionProvider _sessionProvider = ServiceSessionProvider();

  // Register a new attendee with full validation and duplicate checking
  Future<RegistrationResult> registerAttendee({
    required String name,
    required String phoneNumber,
    required String yearOfStudy,
    required String location,
  }) async {
    try {
      // Create attendee model for validation
      final attendee = AttendeeModel(
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
        yearOfStudy: yearOfStudy,
        location: location.trim(),
      );

      // Validate all fields
      final validationError = attendee.validateFields();
      if (validationError != null) {
        return RegistrationResult.failure(validationError);
      }

      // Check for duplicate phone number
      final existingAttendee = await _attendeeRepository.getAttendeeByPhone(phoneNumber);
      if (existingAttendee != null) {
        return RegistrationResult.duplicate(existingAttendee);
      }

      // Register new attendee
      final attendeeId = await _attendeeRepository.createAttendee(attendee);
      final registeredAttendee = attendee.copyWith(id: attendeeId);

      // Add to current service session if one is active
      if (_sessionProvider.hasActiveService) {
        await _sessionProvider.addAttendeeToSession(registeredAttendee);
      }

      return RegistrationResult.success(registeredAttendee);
    } catch (e) {
      return RegistrationResult.failure('Registration failed: $e');
    }
  }

  // Register returning attendee (increment attendance count)
  Future<RegistrationResult> registerReturningAttendee(AttendeeModel existingAttendee) async {
    try {
      if (existingAttendee.id == null) {
        return RegistrationResult.failure('Invalid attendee data');
      }

      // Increment attendance count
      await _attendeeRepository.incrementAttendanceCount(existingAttendee.id!);
      
      // Get updated attendee data
      final updatedAttendee = await _attendeeRepository.getAttendeeById(existingAttendee.id!);
      if (updatedAttendee == null) {
        return RegistrationResult.failure('Failed to retrieve updated attendee data');
      }

      // Add to current service session if one is active and not already in session
      if (_sessionProvider.hasActiveService && !_sessionProvider.isAttendeeInSession(updatedAttendee)) {
        await _sessionProvider.addAttendeeToSession(updatedAttendee);
      }

      return RegistrationResult.success(updatedAttendee);
    } catch (e) {
      return RegistrationResult.failure('Failed to register returning attendee: $e');
    }
  }

  // Update existing attendee information
  Future<RegistrationResult> updateAttendee({
    required int attendeeId,
    required String name,
    required String phoneNumber,
    required String yearOfStudy,
    required String location,
  }) async {
    try {
      // Get existing attendee
      final existingAttendee = await _attendeeRepository.getAttendeeById(attendeeId);
      if (existingAttendee == null) {
        return RegistrationResult.failure('Attendee not found');
      }

      // Create updated attendee model
      final updatedAttendee = existingAttendee.copyWith(
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
        yearOfStudy: yearOfStudy,
        location: location.trim(),
        lastUpdated: DateTime.now(),
      );

      // Validate updated fields
      final validationError = updatedAttendee.validateFields();
      if (validationError != null) {
        return RegistrationResult.failure(validationError);
      }

      // Check for duplicate phone number (excluding current attendee)
      if (phoneNumber.trim() != existingAttendee.phoneNumber) {
        final duplicateAttendee = await _attendeeRepository.getAttendeeByPhone(phoneNumber);
        if (duplicateAttendee != null && duplicateAttendee.id != attendeeId) {
          return RegistrationResult.duplicate(duplicateAttendee);
        }
      }

      // Update attendee
      await _attendeeRepository.updateAttendee(updatedAttendee);

      return RegistrationResult.success(updatedAttendee);
    } catch (e) {
      return RegistrationResult.failure('Update failed: $e');
    }
  }

  // Search for attendees by name (for returning attendee lookup)
  Future<List<AttendeeModel>> searchAttendees(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      return await _attendeeRepository.searchAttendeesByName(query.trim());
    } catch (e) {
      throw RegistrationServiceException('Search failed: $e');
    }
  }

  // Enhanced registration for returning attendee with validation
  Future<RegistrationResult> registerReturningAttendeeWithValidation({
    required AttendeeModel existingAttendee,
    String? updatedName,
    String? updatedPhone,
    String? updatedYear,
    String? updatedLocation,
  }) async {
    try {
      if (existingAttendee.id == null) {
        return RegistrationResult.failure('Invalid attendee data');
      }

      // Check if any details were updated
      bool hasUpdates = false;
      AttendeeModel updatedAttendee = existingAttendee;

      if (updatedName != null && updatedName.trim() != existingAttendee.name) {
        updatedAttendee = updatedAttendee.copyWith(name: updatedName.trim());
        hasUpdates = true;
      }

      if (updatedPhone != null && updatedPhone.trim() != existingAttendee.phoneNumber) {
        // Validate new phone number
        final phoneError = validatePhoneNumber(updatedPhone);
        if (phoneError != null) {
          return RegistrationResult.failure(phoneError);
        }
        
        // Check for duplicate phone number
        final duplicateAttendee = await _attendeeRepository.getAttendeeByPhone(updatedPhone);
        if (duplicateAttendee != null && duplicateAttendee.id != existingAttendee.id) {
          return RegistrationResult.duplicate(duplicateAttendee);
        }
        
        updatedAttendee = updatedAttendee.copyWith(phoneNumber: updatedPhone.trim());
        hasUpdates = true;
      }

      if (updatedYear != null && updatedYear != existingAttendee.yearOfStudy) {
        final yearError = validateYearOfStudy(updatedYear);
        if (yearError != null) {
          return RegistrationResult.failure(yearError);
        }
        updatedAttendee = updatedAttendee.copyWith(yearOfStudy: updatedYear);
        hasUpdates = true;
      }

      if (updatedLocation != null && updatedLocation.trim() != existingAttendee.location) {
        final locationError = validateLocation(updatedLocation);
        if (locationError != null) {
          return RegistrationResult.failure(locationError);
        }
        updatedAttendee = updatedAttendee.copyWith(location: updatedLocation.trim());
        hasUpdates = true;
      }

      // Update attendee details if there are changes
      if (hasUpdates) {
        await _attendeeRepository.updateAttendee(updatedAttendee);
      }

      // Increment attendance count
      await _attendeeRepository.incrementAttendanceCount(existingAttendee.id!);
      
      // Get updated attendee data with new attendance count
      final finalAttendee = await _attendeeRepository.getAttendeeById(existingAttendee.id!);
      if (finalAttendee == null) {
        return RegistrationResult.failure('Failed to retrieve updated attendee data');
      }

      // Add to current service session if one is active and not already in session
      if (_sessionProvider.hasActiveService && !_sessionProvider.isAttendeeInSession(finalAttendee)) {
        await _sessionProvider.addAttendeeToSession(finalAttendee);
      }

      return RegistrationResult.success(finalAttendee);
    } catch (e) {
      return RegistrationResult.failure('Failed to register returning attendee: $e');
    }
  }

  // Get attendee by phone number
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    try {
      return await _attendeeRepository.getAttendeeByPhone(phoneNumber);
    } catch (e) {
      throw RegistrationServiceException('Failed to get attendee by phone: $e');
    }
  }

  // Check if phone number is already registered
  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    try {
      return await _attendeeRepository.phoneNumberExists(phoneNumber);
    } catch (e) {
      throw RegistrationServiceException('Failed to check phone number: $e');
    }
  }

  // Get all attendees
  Future<List<AttendeeModel>> getAllAttendees() async {
    try {
      return await _attendeeRepository.getAllAttendees();
    } catch (e) {
      throw RegistrationServiceException('Failed to get all attendees: $e');
    }
  }

  // Delete attendee
  Future<bool> deleteAttendee(int attendeeId) async {
    try {
      await _attendeeRepository.deleteAttendee(attendeeId);
      return true;
    } catch (e) {
      throw RegistrationServiceException('Failed to delete attendee: $e');
    }
  }

  // Get attendees by year of study
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    try {
      return await _attendeeRepository.getAttendeesByYear(yearOfStudy);
    } catch (e) {
      throw RegistrationServiceException('Failed to get attendees by year: $e');
    }
  }

  // Get attendees by location
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    try {
      return await _attendeeRepository.getAttendeesByLocation(location);
    } catch (e) {
      throw RegistrationServiceException('Failed to get attendees by location: $e');
    }
  }

  // Get attendance statistics
  Future<AttendanceStatistics> getAttendanceStatistics() async {
    try {
      final stats = await _attendeeRepository.getAttendanceStatistics();
      return AttendanceStatistics.fromMap(stats);
    } catch (e) {
      throw RegistrationServiceException('Failed to get attendance statistics: $e');
    }
  }

  // Validate individual fields (for real-time validation)
  String? validateName(String name) {
    if (name.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  String? validatePhoneNumber(String phoneNumber) {
    if (!AttendeeModel.isValidKenyanPhone(phoneNumber)) {
      return 'Invalid phone number format. Use +2547xxxxxxxx or 07xxxxxxxx';
    }
    return null;
  }

  String? validateYearOfStudy(String yearOfStudy) {
    if (yearOfStudy.isEmpty) {
      return 'Year of study is required';
    }
    
    List<String> validYears = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', '6th Year'];
    if (!validYears.contains(yearOfStudy)) {
      return 'Invalid year of study';
    }
    
    return null;
  }

  String? validateLocation(String location) {
    if (location.trim().isEmpty) {
      return 'Location is required';
    }
    return null;
  }

  // Get predefined location options
  List<String> getPredefinedLocations() {
    return [
      'Kitengela',
      'Athi River',
      'Sukari',
      'Mlolongo',
      'Syokimau',
      'Juja',
      'Kaloleni',
      'Rongai',
      'Thika',
      'Githurai',
      'Makongeni',
      'Ngara',
      'Langata',
      'Mlango',
      'South B',
      'Upper Hill',
      'South C',
      'Landi Mawe',
      'Pipeline',
      'Shauri Moyo',
      'Embakasi',
      'Kasarani',
      'Ruiru',
      'Kahawa',
      'Zimmerman',
      'Other',
    ];
  }

  // Get year of study options
  List<String> getYearOfStudyOptions() {
    return ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', '6th Year'];
  }
}

// Registration result class to handle different outcomes
class RegistrationResult {
  final bool isSuccess;
  final AttendeeModel? attendee;
  final String? errorMessage;
  final bool isDuplicate;

  RegistrationResult._({
    required this.isSuccess,
    this.attendee,
    this.errorMessage,
    this.isDuplicate = false,
  });

  factory RegistrationResult.success(AttendeeModel attendee) {
    return RegistrationResult._(
      isSuccess: true,
      attendee: attendee,
    );
  }

  factory RegistrationResult.failure(String errorMessage) {
    return RegistrationResult._(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }

  factory RegistrationResult.duplicate(AttendeeModel existingAttendee) {
    return RegistrationResult._(
      isSuccess: false,
      attendee: existingAttendee,
      errorMessage: 'Phone number already registered',
      isDuplicate: true,
    );
  }
}

// Attendance statistics model
class AttendanceStatistics {
  final int totalAttendees;
  final double averageAttendance;
  final int maxAttendance;
  final int minAttendance;
  final int totalAttendanceCount;

  AttendanceStatistics({
    required this.totalAttendees,
    required this.averageAttendance,
    required this.maxAttendance,
    required this.minAttendance,
    required this.totalAttendanceCount,
  });

  factory AttendanceStatistics.fromMap(Map<String, dynamic> map) {
    return AttendanceStatistics(
      totalAttendees: map['totalAttendees'] ?? 0,
      averageAttendance: (map['averageAttendance'] ?? 0.0).toDouble(),
      maxAttendance: map['maxAttendance'] ?? 0,
      minAttendance: map['minAttendance'] ?? 0,
      totalAttendanceCount: map['totalAttendanceCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAttendees': totalAttendees,
      'averageAttendance': averageAttendance,
      'maxAttendance': maxAttendance,
      'minAttendance': minAttendance,
      'totalAttendanceCount': totalAttendanceCount,
    };
  }

  @override
  String toString() {
    return 'AttendanceStatistics(total: $totalAttendees, avg: ${averageAttendance.toStringAsFixed(1)}, max: $maxAttendance, min: $minAttendance, totalCount: $totalAttendanceCount)';
  }
}

// Custom exception for registration service operations
class RegistrationServiceException implements Exception {
  final String message;
  
  RegistrationServiceException(this.message);
  
  @override
  String toString() => 'RegistrationServiceException: $message';
}