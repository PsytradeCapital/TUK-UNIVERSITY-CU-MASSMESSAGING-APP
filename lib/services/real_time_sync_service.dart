import 'dart:async';
import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import '../repositories/firebase_attendee_repository.dart';
import '../repositories/firebase_message_log_repository.dart';
import '../repositories/attendee_repository.dart';
import '../repositories/message_log_repository.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';

/// Real-Time Sync Service
/// Manages real-time listeners for Firestore collections and provides
/// notifications for new attendees and message logs
class RealTimeSyncService {
  // Singleton pattern
  static final RealTimeSyncService _instance = RealTimeSyncService._internal();
  factory RealTimeSyncService() => _instance;
  RealTimeSyncService._internal();

  // Repositories
  final FirebaseAttendeeRepository _firebaseAttendeeRepo = FirebaseAttendeeRepository();
  final FirebaseMessageLogRepository _firebaseMessageLogRepo = FirebaseMessageLogRepository();
  final AttendeeRepository _localAttendeeRepo = AttendeeRepository();
  final MessageLogRepository _localMessageLogRepo = MessageLogRepository();
  
  // Services
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Stream subscriptions
  StreamSubscription<List<AttendeeModel>>? _attendeesStreamSubscription;
  StreamSubscription<List<MessageLogModel>>? _messageLogsStreamSubscription;
  StreamSubscription<DateTime>? _connectivitySubscription;

  // Stream controllers for UI updates
  final StreamController<List<AttendeeModel>> _attendeeUpdatesController = 
      StreamController<List<AttendeeModel>>.broadcast();
  final StreamController<List<MessageLogModel>> _messageLogUpdatesController = 
      StreamController<List<MessageLogModel>>.broadcast();
  final StreamController<RealTimeSyncEvent> _syncEventsController = 
      StreamController<RealTimeSyncEvent>.broadcast();

  // State tracking
  bool _isListening = false;
  List<AttendeeModel> _lastKnownAttendees = [];
  List<MessageLogModel> _lastKnownMessageLogs = [];
  DateTime? _lastAttendeeUpdate;
  DateTime? _lastMessageLogUpdate;

  /// Initialize the real-time sync service
  Future<void> initialize() async {
    try {
      // Set up connectivity monitoring
      _setupConnectivityMonitoring();
      
      _emitSyncEvent(RealTimeSyncEventType.initialized, 'Real-time sync service initialized');
    } catch (e) {
      _emitSyncEvent(RealTimeSyncEventType.error, 'Failed to initialize real-time sync: $e');
    }
  }

  /// Start listening to real-time updates
  Future<void> startListening() async {
    if (_isListening) {
      return;
    }

    try {
      // Check if user is authenticated and online
      if (!_authService.isAuthenticated()) {
        _emitSyncEvent(RealTimeSyncEventType.error, 'Cannot start real-time sync: User not authenticated');
        return;
      }

      if (!_connectivityService.isOnline()) {
        _emitSyncEvent(RealTimeSyncEventType.error, 'Cannot start real-time sync: Device offline');
        return;
      }

      _isListening = true;
      _emitSyncEvent(RealTimeSyncEventType.started, 'Starting real-time sync listeners');

      // Start attendee updates listener
      await _startAttendeeUpdatesListener();

      // Start message log updates listener
      await _startMessageLogUpdatesListener();

      _emitSyncEvent(RealTimeSyncEventType.listening, 'Real-time sync listeners active');
    } catch (e) {
      _isListening = false;
      _emitSyncEvent(RealTimeSyncEventType.error, 'Failed to start real-time sync: $e');
      rethrow;
    }
  }

  /// Stop listening to real-time updates
  void stopListening() {
    if (!_isListening) {
      return;
    }

    _isListening = false;
    
    // Cancel subscriptions
    _attendeesStreamSubscription?.cancel();
    _messageLogsStreamSubscription?.cancel();
    
    _attendeesStreamSubscription = null;
    _messageLogsStreamSubscription = null;

    _emitSyncEvent(RealTimeSyncEventType.stopped, 'Real-time sync listeners stopped');
  }

  /// Start listening to attendee updates
  Future<void> _startAttendeeUpdatesListener() async {
    try {
      // Get initial state
      _lastKnownAttendees = await _localAttendeeRepo.getAllAttendees();
      _lastAttendeeUpdate = DateTime.now();

      // Listen to Firestore attendees stream
      _attendeesStreamSubscription = _firebaseAttendeeRepo.attendeesStream().listen(
        (cloudAttendees) async {
          try {
            await _handleAttendeeUpdates(cloudAttendees);
          } catch (e) {
            _emitSyncEvent(RealTimeSyncEventType.error, 'Error handling attendee updates: $e');
          }
        },
        onError: (error) {
          _emitSyncEvent(RealTimeSyncEventType.error, 'Attendee stream error: $error');
        },
      );

      _emitSyncEvent(RealTimeSyncEventType.listening, 'Attendee real-time listener started');
    } catch (e) {
      _emitSyncEvent(RealTimeSyncEventType.error, 'Failed to start attendee listener: $e');
      rethrow;
    }
  }

  /// Start listening to message log updates
  Future<void> _startMessageLogUpdatesListener() async {
    try {
      // Get initial state
      _lastKnownMessageLogs = await _localMessageLogRepo.getAllMessageLogs();
      _lastMessageLogUpdate = DateTime.now();

      // Listen to Firestore message logs stream
      _messageLogsStreamSubscription = _firebaseMessageLogRepo.messageLogsStream().listen(
        (cloudMessageLogs) async {
          try {
            await _handleMessageLogUpdates(cloudMessageLogs);
          } catch (e) {
            _emitSyncEvent(RealTimeSyncEventType.error, 'Error handling message log updates: $e');
          }
        },
        onError: (error) {
          _emitSyncEvent(RealTimeSyncEventType.error, 'Message log stream error: $error');
        },
      );

      _emitSyncEvent(RealTimeSyncEventType.listening, 'Message log real-time listener started');
    } catch (e) {
      _emitSyncEvent(RealTimeSyncEventType.error, 'Failed to start message log listener: $e');
      rethrow;
    }
  }

  /// Handle attendee updates from Firestore
  Future<void> _handleAttendeeUpdates(List<AttendeeModel> cloudAttendees) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return;

      // Find new attendees (not created by current user)
      final newAttendees = <AttendeeModel>[];
      final updatedAttendees = <AttendeeModel>[];

      for (final cloudAttendee in cloudAttendees) {
        // Skip attendees created by current user to avoid self-notifications
        if (cloudAttendee.createdBy == currentUser.uid) {
          continue;
        }

        // Check if this is a new attendee
        final existingAttendee = _lastKnownAttendees.firstWhere(
          (a) => a.firestoreId == cloudAttendee.firestoreId,
          orElse: () => AttendeeModel(name: '', phoneNumber: '', yearOfStudy: '', location: ''),
        );

        if (existingAttendee.name.isEmpty) {
          // New attendee
          newAttendees.add(cloudAttendee);
        } else if (cloudAttendee.version > existingAttendee.version) {
          // Updated attendee
          updatedAttendees.add(cloudAttendee);
        }

        // Update local database
        final localAttendee = cloudAttendee.id != null
            ? await _localAttendeeRepo.getAttendeeById(cloudAttendee.id!)
            : null;

        if (localAttendee == null) {
          // Create new local record
          await _localAttendeeRepo.createAttendee(
            cloudAttendee.copyWith(isSynced: true),
          );
        } else if (cloudAttendee.version > localAttendee.version) {
          // Update local record
          await _localAttendeeRepo.updateAttendee(
            cloudAttendee.copyWith(
              id: localAttendee.id,
              isSynced: true,
            ),
          );
        }
      }

      // Show notifications for new attendees
      if (newAttendees.isNotEmpty) {
        _showNewAttendeesNotification(newAttendees);
      }

      // Show notifications for updated attendees
      if (updatedAttendees.isNotEmpty) {
        _showUpdatedAttendeesNotification(updatedAttendees);
      }

      // Update state and emit to UI
      _lastKnownAttendees = cloudAttendees;
      _lastAttendeeUpdate = DateTime.now();
      _attendeeUpdatesController.add(cloudAttendees);

      _emitSyncEvent(
        RealTimeSyncEventType.updated,
        'Processed ${cloudAttendees.length} attendee updates (${newAttendees.length} new, ${updatedAttendees.length} updated)',
      );
    } catch (e) {
      _emitSyncEvent(RealTimeSyncEventType.error, 'Failed to handle attendee updates: $e');
    }
  }

  /// Handle message log updates from Firestore
  Future<void> _handleMessageLogUpdates(List<MessageLogModel> cloudMessageLogs) async {
    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) return;

      // Find new message logs (not sent by current user)
      final newMessageLogs = <MessageLogModel>[];
      final updatedMessageLogs = <MessageLogModel>[];

      for (final cloudMessageLog in cloudMessageLogs) {
        // Skip messages sent by current user to avoid self-notifications
        if (cloudMessageLog.sentBy == currentUser.uid) {
          continue;
        }

        // Check if this is a new message log
        final existingMessageLog = _lastKnownMessageLogs.firstWhere(
          (m) => m.firestoreId == cloudMessageLog.firestoreId,
          orElse: () => MessageLogModel(serviceId: 0, attendeeId: 0, messageText: ''),
        );

        if (existingMessageLog.messageText.isEmpty) {
          // New message log
          newMessageLogs.add(cloudMessageLog);
        } else if (cloudMessageLog.version > existingMessageLog.version) {
          // Updated message log
          updatedMessageLogs.add(cloudMessageLog);
        }

        // Update local database
        final localMessageLog = cloudMessageLog.messageId != null
            ? await _localMessageLogRepo.getMessageLogById(cloudMessageLog.messageId!)
            : null;

        if (localMessageLog == null) {
          // Create new local record
          await _localMessageLogRepo.createMessageLog(
            cloudMessageLog.copyWith(isSynced: true),
          );
        } else if (cloudMessageLog.version > localMessageLog.version) {
          // Update local record
          await _localMessageLogRepo.updateMessageLog(
            cloudMessageLog.copyWith(
              messageId: localMessageLog.messageId,
              isSynced: true,
            ),
          );
        }
      }

      // Show notifications for new messages
      if (newMessageLogs.isNotEmpty) {
        _showNewMessagesNotification(newMessageLogs);
      }

      // Show notifications for updated messages
      if (updatedMessageLogs.isNotEmpty) {
        _showUpdatedMessagesNotification(updatedMessageLogs);
      }

      // Update state and emit to UI
      _lastKnownMessageLogs = cloudMessageLogs;
      _lastMessageLogUpdate = DateTime.now();
      _messageLogUpdatesController.add(cloudMessageLogs);

      _emitSyncEvent(
        RealTimeSyncEventType.updated,
        'Processed ${cloudMessageLogs.length} message log updates (${newMessageLogs.length} new, ${updatedMessageLogs.length} updated)',
      );
    } catch (e) {
      _emitSyncEvent(RealTimeSyncEventType.error, 'Failed to handle message log updates: $e');
    }
  }

  /// Show notification for new attendees
  void _showNewAttendeesNotification(List<AttendeeModel> newAttendees) {
    final count = newAttendees.length;
    final title = count == 1 ? 'New Attendee Registered' : '$count New Attendees Registered';
    
    String message;
    if (count == 1) {
      final attendee = newAttendees.first;
      message = '${attendee.name} (${attendee.categoryDisplayName}) has been registered by another user.';
    } else {
      message = '$count new attendees have been registered by other users.';
    }

    _notificationService.showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.info,
      duration: const Duration(seconds: 5),
    ));
  }

  /// Show notification for updated attendees
  void _showUpdatedAttendeesNotification(List<AttendeeModel> updatedAttendees) {
    final count = updatedAttendees.length;
    final title = count == 1 ? 'Attendee Updated' : '$count Attendees Updated';
    
    String message;
    if (count == 1) {
      final attendee = updatedAttendees.first;
      message = '${attendee.name}\'s information has been updated by another user.';
    } else {
      message = '$count attendees have been updated by other users.';
    }

    _notificationService.showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.info,
      duration: const Duration(seconds: 4),
    ));
  }

  /// Show notification for new messages
  void _showNewMessagesNotification(List<MessageLogModel> newMessageLogs) {
    final count = newMessageLogs.length;
    final title = count == 1 ? 'New Message Sent' : '$count New Messages Sent';
    
    String message;
    if (count == 1) {
      message = 'A message has been sent by another user.';
    } else {
      message = '$count messages have been sent by other users.';
    }

    _notificationService.showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.info,
      duration: const Duration(seconds: 4),
    ));
  }

  /// Show notification for updated messages
  void _showUpdatedMessagesNotification(List<MessageLogModel> updatedMessageLogs) {
    final count = updatedMessageLogs.length;
    final title = count == 1 ? 'Message Status Updated' : '$count Message Statuses Updated';
    
    String message;
    if (count == 1) {
      final messageLog = updatedMessageLogs.first;
      message = 'Message status changed to ${messageLog.statusDisplayText}.';
    } else {
      message = '$count message statuses have been updated.';
    }

    _notificationService.showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.info,
      duration: const Duration(seconds: 4),
    ));
  }

  /// Set up connectivity monitoring to restart listeners when online
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivityService.connectionRestoredStream().listen((restoredAt) async {
        _emitSyncEvent(
          RealTimeSyncEventType.reconnected,
          'Connection restored at $restoredAt - restarting real-time listeners',
        );

        // Restart listeners if they were active
        if (_isListening) {
          stopListening();
          await Future.delayed(const Duration(seconds: 2)); // Wait for connection to stabilize
          await startListening();
        }
      },
      onError: (error) {
        _emitSyncEvent(RealTimeSyncEventType.error, 'Connectivity monitoring error: $error');
      },
    );
  }

  /// Emit sync event
  void _emitSyncEvent(RealTimeSyncEventType type, String message) {
    _syncEventsController.add(RealTimeSyncEvent(
      type: type,
      message: message,
      timestamp: DateTime.now(),
    ));
  }

  /// Get attendee updates stream
  Stream<List<AttendeeModel>> get attendeeUpdatesStream => _attendeeUpdatesController.stream;

  /// Get message log updates stream
  Stream<List<MessageLogModel>> get messageLogUpdatesStream => _messageLogUpdatesController.stream;

  /// Get sync events stream
  Stream<RealTimeSyncEvent> get syncEventsStream => _syncEventsController.stream;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Get last attendee update time
  DateTime? get lastAttendeeUpdate => _lastAttendeeUpdate;

  /// Get last message log update time
  DateTime? get lastMessageLogUpdate => _lastMessageLogUpdate;

  /// Get current attendee count
  int get currentAttendeeCount => _lastKnownAttendees.length;

  /// Get current message log count
  int get currentMessageLogCount => _lastKnownMessageLogs.length;

  /// Dispose resources
  void dispose() {
    stopListening();
    _connectivitySubscription?.cancel();
    _attendeeUpdatesController.close();
    _messageLogUpdatesController.close();
    _syncEventsController.close();
  }
}

/// Real-time sync event model
class RealTimeSyncEvent {
  final RealTimeSyncEventType type;
  final String message;
  final DateTime timestamp;
  final dynamic data;

  RealTimeSyncEvent({
    required this.type,
    required this.message,
    required this.timestamp,
    this.data,
  });

  @override
  String toString() {
    return 'RealTimeSyncEvent(type: $type, message: $message, timestamp: $timestamp)';
  }
}

/// Real-time sync event types
enum RealTimeSyncEventType {
  initialized,
  started,
  listening,
  updated,
  stopped,
  reconnected,
  error,
}