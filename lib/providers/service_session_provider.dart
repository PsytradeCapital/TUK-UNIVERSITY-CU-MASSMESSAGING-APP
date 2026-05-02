import 'package:flutter/foundation.dart';
import '../models/attendee_model.dart';
import '../models/service_model.dart';
import '../repositories/service_repository.dart';

class ServiceSessionProvider extends ChangeNotifier {
  static final ServiceSessionProvider _instance = ServiceSessionProvider._internal();
  factory ServiceSessionProvider() => _instance;
  ServiceSessionProvider._internal();

  final ServiceRepository _serviceRepository = ServiceRepository();
  
  ServiceModel? _currentService;
  List<AttendeeModel> _currentAttendees = [];
  bool _isLoading = false;
  List<ServiceModel> _sessionHistory = [];
  DateTime? _lastSessionTransition;

  // Getters
  ServiceModel? get currentService => _currentService;
  List<AttendeeModel> get currentAttendees => List.unmodifiable(_currentAttendees);
  bool get isLoading => _isLoading;
  bool get hasActiveService => _currentService != null;
  int get attendeeCount => _currentAttendees.length;
  List<ServiceModel> get sessionHistory => List.unmodifiable(_sessionHistory);
  DateTime? get lastSessionTransition => _lastSessionTransition;

  /// Start a new service session
  Future<void> startNewService({String serviceName = 'Sunday Service'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final service = ServiceModel(
        serviceName: serviceName,
        serviceDate: DateTime.now(),
        totalAttendees: 0,
        messageSent: false,
        attendees: [],
      );

      final serviceId = await _serviceRepository.insertService(service);
      
      _currentService = service.copyWith(serviceId: serviceId);
      _currentAttendees = [];
      _lastSessionTransition = DateTime.now();
      
      await _loadSessionHistory();
      
      debugPrint('Started new service session "$serviceName" with ID: $serviceId');
    } catch (e) {
      debugPrint('Error starting new service: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add attendee to current service session
  Future<void> addAttendeeToSession(AttendeeModel attendee) async {
    if (_currentService == null) {
      throw Exception('No active service session');
    }

    try {
      // Add attendee to service_attendees table
      await _serviceRepository.addAttendeeToService(
        _currentService!.serviceId!,
        attendee.id!,
      );

      // Update local state
      _currentAttendees.add(attendee);
      
      // Update service total count
      _currentService = _currentService!.copyWith(
        totalAttendees: _currentAttendees.length,
      );

      await _serviceRepository.updateService(_currentService!);
      
      notifyListeners();
      debugPrint('Added attendee ${attendee.name} to service session');
    } catch (e) {
      debugPrint('Error adding attendee to session: $e');
      rethrow;
    }
  }

  /// Remove attendee from current service session
  Future<void> removeAttendeeFromSession(AttendeeModel attendee) async {
    if (_currentService == null) {
      throw Exception('No active service session');
    }

    try {
      // Remove from service_attendees table
      await _serviceRepository.removeAttendeeFromService(
        _currentService!.serviceId!,
        attendee.id!,
      );

      // Update local state
      _currentAttendees.removeWhere((a) => a.id == attendee.id);
      
      // Update service total count
      _currentService = _currentService!.copyWith(
        totalAttendees: _currentAttendees.length,
      );

      await _serviceRepository.updateService(_currentService!);
      
      notifyListeners();
      debugPrint('Removed attendee ${attendee.name} from service session');
    } catch (e) {
      debugPrint('Error removing attendee from session: $e');
      rethrow;
    }
  }

  /// Load existing service session (for app restart recovery)
  /// Restores ANY unsent service — not just today's
  Future<void> loadActiveService() async {
    // If we already have a session loaded, don't wipe it
    if (_currentService != null) {
      await _loadSessionHistory();
      return;
    }

    try {
      // Get the most recent service that hasn't sent messages yet
      final services = await _serviceRepository.getRecentServices(limit: 5);

      for (final service in services) {
        if (!service.messageSent) {
          _currentService = service;
          _currentAttendees = await _serviceRepository.getServiceAttendees(service.serviceId!);
          _lastSessionTransition = service.serviceDate;
          debugPrint('Restored service session ${service.serviceId} with ${_currentAttendees.length} attendees');
          break;
        }
      }

      await _loadSessionHistory();
    } catch (e) {
      debugPrint('Error loading active service: $e');
    } finally {
      // Never set _isLoading here — it causes the spinner on every app resume
      notifyListeners();
    }
  }

  /// Mark service as message sent and clear session
  Future<void> markMessagesSent(String messageText) async {
    if (_currentService == null) {
      throw Exception('No active service session');
    }

    try {
      // Update service as message sent
      _currentService = _currentService!.copyWith(
        messageSent: true,
        messageText: messageText,
      );

      await _serviceRepository.updateService(_currentService!);
      
      debugPrint('Marked service ${_currentService!.serviceId} as messages sent');
    } catch (e) {
      debugPrint('Error marking messages as sent: $e');
      rethrow;
    }
  }

  /// Clear current service session (but keep in database)
  void clearSession() {
    _currentService = null;
    _currentAttendees = [];
    _lastSessionTransition = DateTime.now();
    notifyListeners();
    debugPrint('Cleared current service session');
  }

  /// Get service session summary
  Map<String, dynamic> getSessionSummary() {
    return {
      'hasActiveService': hasActiveService,
      'serviceId': _currentService?.serviceId,
      'serviceDate': _currentService?.serviceDate,
      'attendeeCount': attendeeCount,
      'messageSent': _currentService?.messageSent ?? false,
    };
  }

  /// Check if attendee is already in current session
  bool isAttendeeInSession(AttendeeModel attendee) {
    return _currentAttendees.any((a) => a.id == attendee.id);
  }

  /// Get attendee from current session by ID
  AttendeeModel? getAttendeeFromSession(int attendeeId) {
    try {
      return _currentAttendees.firstWhere((a) => a.id == attendeeId);
    } catch (e) {
      return null;
    }
  }

  /// Update attendee in current session
  void updateAttendeeInSession(AttendeeModel updatedAttendee) {
    final index = _currentAttendees.indexWhere((a) => a.id == updatedAttendee.id);
    if (index != -1) {
      _currentAttendees[index] = updatedAttendee;
      notifyListeners();
    }
  }

  /// Load session history from database
  Future<void> _loadSessionHistory() async {
    try {
      _sessionHistory = await _serviceRepository.getRecentServices(limit: 10);
      debugPrint('Loaded ${_sessionHistory.length} recent services');
    } catch (e) {
      debugPrint('Error loading session history: $e');
      _sessionHistory = [];
    }
  }

  /// Get session state information
  Map<String, dynamic> getSessionState() {
    return {
      'hasActiveService': hasActiveService,
      'serviceId': _currentService?.serviceId,
      'serviceDate': _currentService?.serviceDate?.toIso8601String(),
      'attendeeCount': attendeeCount,
      'messageSent': _currentService?.messageSent ?? false,
      'messageText': _currentService?.messageText,
      'lastTransition': _lastSessionTransition?.toIso8601String(),
      'historyCount': _sessionHistory.length,
    };
  }

  /// Transition to a new service session (end current and start new)
  Future<void> transitionToNewService() async {
    _isLoading = true;
    notifyListeners();

    try {
      // If there's an active service, mark it as completed
      if (_currentService != null && !_currentService!.messageSent) {
        await markMessagesSent('Service completed without message');
      }

      // Clear current session
      clearSession();

      // Start new service
      await startNewService();
      
      debugPrint('Successfully transitioned to new service session');
    } catch (e) {
      debugPrint('Error transitioning to new service: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// End current service session without starting a new one
  Future<void> endCurrentService({String? finalMessage}) async {
    if (_currentService == null) {
      throw Exception('No active service session to end');
    }

    try {
      // Mark service as completed
      if (!_currentService!.messageSent) {
        await markMessagesSent(finalMessage ?? 'Service ended');
      }

      // Clear session
      clearSession();
      
      // Reload history to include the ended service
      await _loadSessionHistory();
      
      debugPrint('Successfully ended service session');
    } catch (e) {
      debugPrint('Error ending service session: $e');
      rethrow;
    }
  }

  /// Get session duration (if active)
  Duration? getSessionDuration() {
    if (_currentService == null) return null;
    return DateTime.now().difference(_currentService!.serviceDate);
  }

  /// Check if session is stale (older than specified hours)
  bool isSessionStale({int maxHours = 6}) {
    if (_currentService == null) return false;
    final duration = getSessionDuration();
    return duration != null && duration.inHours > maxHours;
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStatistics() {
    final recentServices = _sessionHistory.take(5).toList();
    
    if (recentServices.isEmpty) {
      return {
        'averageAttendees': 0.0,
        'totalServices': 0,
        'servicesWithMessages': 0,
        'lastServiceDate': null,
      };
    }

    final totalAttendees = recentServices.fold<int>(0, (sum, service) => sum + service.totalAttendees);
    final servicesWithMessages = recentServices.where((s) => s.messageSent).length;
    
    return {
      'averageAttendees': totalAttendees / recentServices.length,
      'totalServices': recentServices.length,
      'servicesWithMessages': servicesWithMessages,
      'lastServiceDate': recentServices.first.serviceDate.toIso8601String(),
    };
  }

  /// Refresh session data (reload from database) — no loading spinner
  Future<void> refreshSession() async {
    try {
      if (_currentService != null) {
        final updatedService = await _serviceRepository.getServiceById(_currentService!.serviceId!);
        if (updatedService != null) {
          _currentService = updatedService;
          _currentAttendees = await _serviceRepository.getServiceAttendees(_currentService!.serviceId!);
        }
      }
      await _loadSessionHistory();
      notifyListeners();
      debugPrint('Session data refreshed: ${_currentAttendees.length} attendees');
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }
  }

  /// Validate session state consistency
  Future<bool> validateSessionState() async {
    try {
      if (_currentService == null) return true;

      // Check if service exists in database
      final dbService = await _serviceRepository.getServiceById(_currentService!.serviceId!);
      if (dbService == null) {
        debugPrint('Warning: Current service not found in database');
        clearSession();
        return false;
      }

      // Check if attendee count matches
      final dbAttendees = await _serviceRepository.getServiceAttendees(_currentService!.serviceId!);
      if (dbAttendees.length != _currentAttendees.length) {
        debugPrint('Warning: Attendee count mismatch, refreshing session');
        _currentAttendees = dbAttendees;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error validating session state: $e');
      return false;
    }
  }

  /// Get session persistence data for app state restoration
  Map<String, dynamic> getSessionPersistenceData() {
    return {
      'currentServiceId': _currentService?.serviceId,
      'lastTransition': _lastSessionTransition?.toIso8601String(),
      'attendeeCount': attendeeCount,
    };
  }

  /// Restore session from persistence data
  Future<void> restoreSessionFromPersistence(Map<String, dynamic> data) async {
    try {
      final serviceId = data['currentServiceId'] as int?;
      final lastTransitionStr = data['lastTransition'] as String?;
      
      if (serviceId != null) {
        final service = await _serviceRepository.getServiceById(serviceId);
        if (service != null && !service.messageSent) {
          _currentService = service;
          _currentAttendees = await _serviceRepository.getServiceAttendees(serviceId);
          
          if (lastTransitionStr != null) {
            _lastSessionTransition = DateTime.parse(lastTransitionStr);
          }
          
          await _loadSessionHistory();
          notifyListeners();
          
          debugPrint('Session restored from persistence data');
        }
      }
    } catch (e) {
      debugPrint('Error restoring session from persistence: $e');
    }
  }
}