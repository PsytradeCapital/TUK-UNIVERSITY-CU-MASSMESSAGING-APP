import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import '../models/pending_message_model.dart';
import '../repositories/pending_message_repository.dart';
import 'notification_service.dart';

enum SMSPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  unknown
}

enum SMSSendingState {
  idle,
  sending,
  paused,
  completed,
  cancelled
}

class SMSProgress {
  final int totalMessages;
  final int sentMessages;
  final int failedMessages;
  final int currentIndex;
  final SMSSendingState state;
  final String? currentRecipient;
  final String? lastError;

  SMSProgress({
    required this.totalMessages,
    required this.sentMessages,
    required this.failedMessages,
    required this.currentIndex,
    required this.state,
    this.currentRecipient,
    this.lastError,
  });

  double get progress {
    if (totalMessages == 0) return 0.0;
    return (sentMessages + failedMessages) / totalMessages;
  }

  bool get isCompleted => state == SMSSendingState.completed;
  bool get isPaused => state == SMSSendingState.paused;
  bool get isSending => state == SMSSendingState.sending;
  bool get hasErrors => failedMessages > 0;

  SMSProgress copyWith({
    int? totalMessages,
    int? sentMessages,
    int? failedMessages,
    int? currentIndex,
    SMSSendingState? state,
    String? currentRecipient,
    String? lastError,
  }) {
    return SMSProgress(
      totalMessages: totalMessages ?? this.totalMessages,
      sentMessages: sentMessages ?? this.sentMessages,
      failedMessages: failedMessages ?? this.failedMessages,
      currentIndex: currentIndex ?? this.currentIndex,
      state: state ?? this.state,
      currentRecipient: currentRecipient ?? this.currentRecipient,
      lastError: lastError ?? this.lastError,
    );
  }
}

class SMSManager {
  static final SMSManager _instance = SMSManager._internal();
  factory SMSManager() => _instance;
  SMSManager._internal();

  final Telephony _telephony = Telephony.instance;
  final StreamController<SMSProgress> _progressController = StreamController<SMSProgress>.broadcast();
  final NotificationService _notificationService = NotificationService();
  final PendingMessageRepository _pendingMessageRepo = PendingMessageRepository();
  
  SMSProgress _currentProgress = SMSProgress(
    totalMessages: 0,
    sentMessages: 0,
    failedMessages: 0,
    currentIndex: 0,
    state: SMSSendingState.idle,
  );

  // Sending state management
  bool _isSending = false;
  bool _isPaused = false;
  bool _isCancelled = false;
  List<AttendeeModel>? _currentRecipients;
  String? _currentMessage;
  int _currentIndex = 0;

  // Getters
  Stream<SMSProgress> get progressStream => _progressController.stream;
  SMSProgress get currentProgress => _currentProgress;
  bool get isSending => _isSending;
  bool get isPaused => _isPaused;

  /// Check and request SMS permissions
  Future<SMSPermissionStatus> checkSMSPermission() async {
    try {
      bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;
      
      if (permissionsGranted == true) {
        return SMSPermissionStatus.granted;
      } else if (permissionsGranted == false) {
        return SMSPermissionStatus.denied;
      } else {
        return SMSPermissionStatus.unknown;
      }
    } catch (e) {
      debugPrint('Error checking SMS permissions: $e');
      return SMSPermissionStatus.unknown;
    }
  }

  /// Request SMS permissions explicitly
  Future<SMSPermissionStatus> requestSMSPermission() async {
    try {
      bool? permissionsGranted = await _telephony.requestSmsPermissions;
      
      if (permissionsGranted == true) {
        return SMSPermissionStatus.granted;
      } else {
        return SMSPermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('Error requesting SMS permissions: $e');
      return SMSPermissionStatus.unknown;
    }
  }

  /// Send bulk SMS to multiple attendees with progress tracking
  Future<void> sendBulkSMS(
    List<AttendeeModel> attendees, 
    String message, {
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  }) async {
    if (_isSending) {
      throw Exception('SMS sending is already in progress');
    }

    if (attendees.isEmpty) {
      throw Exception('No attendees provided for SMS sending');
    }

    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }

    // Check permissions first
    final permissionStatus = await checkSMSPermission();
    if (permissionStatus != SMSPermissionStatus.granted) {
      throw Exception('SMS permissions not granted');
    }

    // Initialize sending state
    _isSending = true;
    _isPaused = false;
    _isCancelled = false;
    _currentRecipients = attendees;
    _currentMessage = message;
    _currentIndex = 0;

    _currentProgress = SMSProgress(
      totalMessages: attendees.length,
      sentMessages: 0,
      failedMessages: 0,
      currentIndex: 0,
      state: SMSSendingState.sending,
    );
    _progressController.add(_currentProgress);

    try {
      await _sendMessagesSequentially(attendees, message, onMessageSent, onMessageFailed);
    } finally {
      _isSending = false;
      _currentRecipients = null;
      _currentMessage = null;
    }
  }

  /// Resume sending from where it was paused
  Future<void> resumeSending({
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  }) async {
    if (!_isPaused || _currentRecipients == null || _currentMessage == null) {
      throw Exception('No paused sending session to resume');
    }

    _isPaused = false;
    _isSending = true;

    _currentProgress = _currentProgress.copyWith(state: SMSSendingState.sending);
    _progressController.add(_currentProgress);

    try {
      final remainingAttendees = _currentRecipients!.sublist(_currentIndex);
      await _sendMessagesSequentially(remainingAttendees, _currentMessage!, onMessageSent, onMessageFailed);
    } finally {
      _isSending = false;
    }
  }

  /// Pause the current sending process
  void pauseSending() {
    if (!_isSending) return;
    
    _isPaused = true;
    _isSending = false;
    
    _currentProgress = _currentProgress.copyWith(state: SMSSendingState.paused);
    _progressController.add(_currentProgress);
  }

  /// Cancel the current sending process
  void cancelSending() {
    _isCancelled = true;
    _isPaused = false;
    _isSending = false;
    
    _currentProgress = _currentProgress.copyWith(state: SMSSendingState.cancelled);
    _progressController.add(_currentProgress);
    
    // Clear current session
    _currentRecipients = null;
    _currentMessage = null;
    _currentIndex = 0;
  }

  /// Send messages sequentially with error handling
  Future<void> _sendMessagesSequentially(
    List<AttendeeModel> attendees,
    String message,
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  ) async {
    for (int i = 0; i < attendees.length; i++) {
      // Check if sending was paused or cancelled
      if (_isPaused || _isCancelled) {
        break;
      }

      final attendee = attendees[i];
      final personalizedMessage = personalizeMessage(message, attendee.name);
      
      // Update progress with current recipient
      _currentProgress = _currentProgress.copyWith(
        currentIndex: _currentIndex + i,
        currentRecipient: attendee.name,
      );
      _progressController.add(_currentProgress);

      try {
        // Attempt to send SMS
        await _sendSingleSMS(attendee.phoneNumber, personalizedMessage);
        
        // Success - update progress
        _currentProgress = _currentProgress.copyWith(
          sentMessages: _currentProgress.sentMessages + 1,
        );
        _progressController.add(_currentProgress);

        // Notify callback if provided
        if (onMessageSent != null) {
          final messageLog = MessageLogModel(
            serviceId: 0, // Will be set by the calling service
            attendeeId: attendee.id ?? 0,
            messageText: personalizedMessage,
            sendStatus: MessageStatus.sent,
            sentAt: DateTime.now(),
          );
          onMessageSent(messageLog);
        }

        // Small delay between messages to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 500));

      } catch (e) {
        // Handle SMS sending failure
        final errorMessage = e.toString();
        
        // Check if this is a balance/credit issue
        final isBalanceIssue = _isBalanceError(errorMessage);
        
        if (isBalanceIssue) {
          // Save as pending message for auto-retry later
          try {
            final pendingMessage = PendingMessageModel(
              serviceId: 0, // Will be set by calling service
              attendeeId: attendee.id ?? 0,
              phoneNumber: attendee.phoneNumber,
              attendeeName: attendee.name,
              messageText: personalizedMessage,
              status: PendingMessageStatus.pending,
              lastError: 'Insufficient SMS balance',
            );
            await _pendingMessageRepo.addPendingMessage(pendingMessage);
            
            debugPrint('Message saved as pending for ${attendee.name}');
          } catch (pendingError) {
            debugPrint('Failed to save pending message: $pendingError');
          }
        }
        
        // Update progress with failure
        _currentProgress = _currentProgress.copyWith(
          failedMessages: _currentProgress.failedMessages + 1,
          lastError: isBalanceIssue ? 'Saved as pending - will retry when balance available' : errorMessage,
        );
        _progressController.add(_currentProgress);

        // Notify callback if provided
        if (onMessageFailed != null) {
          final messageLog = MessageLogModel(
            serviceId: 0, // Will be set by the calling service
            attendeeId: attendee.id ?? 0,
            messageText: personalizedMessage,
            sendStatus: isBalanceIssue ? MessageStatus.pending : MessageStatus.failed,
            errorMessage: errorMessage,
          );
          onMessageFailed(messageLog);
        }

        // Check if this is a critical error that should pause sending
        if (_isCriticalError(errorMessage)) {
          _handleCriticalError(errorMessage);
          pauseSending();
          break;
        }
      }
    }

    // Update final state if not paused or cancelled
    if (!_isPaused && !_isCancelled) {
      _currentProgress = _currentProgress.copyWith(
        state: SMSSendingState.completed,
        currentRecipient: null,
      );
      _progressController.add(_currentProgress);
      
      // Show completion notification
      _notificationService.showSendingCompletedNotification(
        _currentProgress.sentMessages,
        _currentProgress.failedMessages,
      );
    }
  }

  /// Send a single SMS message
  Future<void> _sendSingleSMS(String phoneNumber, String message) async {
    try {
      // Normalize phone number to ensure proper format
      final normalizedPhone = AttendeeModel.normalizePhoneNumber(phoneNumber);
      
      // Send SMS using telephony plugin
      await _telephony.sendSms(
        to: normalizedPhone,
        message: message,
      );
      
      debugPrint('SMS sent successfully to $normalizedPhone');
    } catch (e) {
      debugPrint('Failed to send SMS to $phoneNumber: $e');
      rethrow;
    }
  }

  /// Personalize message with attendee name
  String personalizeMessage(String message, String attendeeName) {
    // Replace common placeholders with attendee name
    String personalizedMessage = message
        .replaceAll('{name}', attendeeName)
        .replaceAll('{Name}', attendeeName)
        .replaceAll('{NAME}', attendeeName.toUpperCase())
        .replaceAll('[name]', attendeeName)
        .replaceAll('[Name]', attendeeName)
        .replaceAll('[NAME]', attendeeName.toUpperCase());

    // If no placeholders found, add a personal greeting
    if (personalizedMessage == message && !message.toLowerCase().contains(attendeeName.toLowerCase())) {
      personalizedMessage = 'Hi $attendeeName, $message';
    }

    return personalizedMessage;
  }

  /// Check if an error is critical and should pause sending
  bool _isCriticalError(String errorMessage) {
    final criticalErrors = [
      'insufficient credit',
      'no credit',
      'bundle depleted',
      'airtime',
      'balance',
      'network error',
      'service unavailable',
      'sms limit exceeded',
      'rate limit',
      'quota exceeded',
      'permission denied',
      'unauthorized',
    ];

    final lowerError = errorMessage.toLowerCase();
    return criticalErrors.any((error) => lowerError.contains(error));
  }

  /// Check if error is due to insufficient SMS balance
  bool _isBalanceError(String errorMessage) {
    final balanceErrors = [
      'insufficient credit',
      'no credit',
      'bundle depleted',
      'airtime',
      'balance',
      'sms limit exceeded',
      'quota exceeded',
    ];

    final lowerError = errorMessage.toLowerCase();
    return balanceErrors.any((error) => lowerError.contains(error));
  }

  /// Get user-friendly error message for display
  String getUserFriendlyErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    
    if (lowerError.contains('insufficient credit') || 
        lowerError.contains('no credit') || 
        lowerError.contains('bundle depleted') ||
        lowerError.contains('airtime') ||
        lowerError.contains('balance')) {
      return 'Insufficient airtime or SMS bundle. Please top up your account and resume sending.';
    }
    
    if (lowerError.contains('network error') || 
        lowerError.contains('service unavailable')) {
      return 'Network connection issue. Please check your signal and try again.';
    }
    
    if (lowerError.contains('sms limit exceeded') || 
        lowerError.contains('rate limit') ||
        lowerError.contains('quota exceeded')) {
      return 'SMS sending limit reached. Please wait a moment before resuming.';
    }
    
    if (lowerError.contains('permission denied') || 
        lowerError.contains('unauthorized')) {
      return 'SMS permissions are required. Please grant SMS permissions in settings.';
    }
    
    if (lowerError.contains('invalid number') || 
        lowerError.contains('invalid phone')) {
      return 'Invalid phone number format detected.';
    }
    
    // Default generic message
    return 'SMS sending failed. Please check your connection and try again.';
  }

  /// Check if error suggests bundle depletion
  bool isBundleDepletionError(String errorMessage) {
    final bundleErrors = [
      'insufficient credit',
      'no credit',
      'bundle depleted',
      'airtime',
      'balance',
      'quota exceeded',
    ];
    
    final lowerError = errorMessage.toLowerCase();
    return bundleErrors.any((error) => lowerError.contains(error));
  }

  /// Get retry delay based on error type
  Duration getRetryDelay(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    
    if (lowerError.contains('rate limit') || lowerError.contains('sms limit')) {
      return const Duration(minutes: 5); // Wait 5 minutes for rate limits
    }
    
    if (lowerError.contains('network') || lowerError.contains('service unavailable')) {
      return const Duration(seconds: 30); // Wait 30 seconds for network issues
    }
    
    // Default retry delay
    return const Duration(seconds: 10);
  }

  /// Handle critical errors with appropriate notifications
  void _handleCriticalError(String errorMessage) {
    if (isBundleDepletionError(errorMessage)) {
      _notificationService.showBundleDepletionNotification(
        onTopUp: () {
          // User can resume sending after topping up
          debugPrint('User requested to top up airtime');
        },
      );
    } else if (errorMessage.toLowerCase().contains('network') || 
               errorMessage.toLowerCase().contains('service unavailable')) {
      _notificationService.showNetworkErrorNotification(
        onRetry: () {
          // User can retry sending
          if (_currentRecipients != null && _currentMessage != null) {
            resumeSending();
          }
        },
      );
    } else if (errorMessage.toLowerCase().contains('permission')) {
      _notificationService.showPermissionErrorNotification(
        onSettings: () {
          // User should go to settings to grant permissions
          debugPrint('User should grant SMS permissions in settings');
        },
      );
    } else {
      // Generic critical error
      _notificationService.showSendingPausedNotification(
        getUserFriendlyErrorMessage(errorMessage),
        onResume: () {
          if (_currentRecipients != null && _currentMessage != null) {
            resumeSending();
          }
        },
      );
    }
  }

  /// Get sending statistics
  Map<String, dynamic> getSendingStats() {
    return {
      'totalMessages': _currentProgress.totalMessages,
      'sentMessages': _currentProgress.sentMessages,
      'failedMessages': _currentProgress.failedMessages,
      'progress': _currentProgress.progress,
      'state': _currentProgress.state.toString(),
      'hasErrors': _currentProgress.hasErrors,
    };
  }

  /// Reset sending state
  void resetSendingState() {
    _isSending = false;
    _isPaused = false;
    _isCancelled = false;
    _currentRecipients = null;
    _currentMessage = null;
    _currentIndex = 0;
    
    _currentProgress = SMSProgress(
      totalMessages: 0,
      sentMessages: 0,
      failedMessages: 0,
      currentIndex: 0,
      state: SMSSendingState.idle,
    );
    _progressController.add(_currentProgress);
  }

  /// Retry all pending messages
  Future<void> retryPendingMessages({
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  }) async {
    try {
      final pendingMessages = await _pendingMessageRepo.getAllPendingMessages();
      
      if (pendingMessages.isEmpty) {
        debugPrint('No pending messages to retry');
        return;
      }

      debugPrint('Retrying ${pendingMessages.length} pending messages');
      
      for (final pending in pendingMessages) {
        if (!pending.canRetry) {
          continue;
        }

        try {
          // Attempt to send the message
          await _sendSingleSMS(pending.phoneNumber, pending.messageText);
          
          // Success - update status to sent
          await _pendingMessageRepo.updatePendingMessage(
            pending.copyWith(
              status: PendingMessageStatus.sent,
              lastAttemptAt: DateTime.now(),
              attemptCount: pending.attemptCount + 1,
            ),
          );

          // Notify success callback
          if (onMessageSent != null) {
            final messageLog = MessageLogModel(
              serviceId: pending.serviceId,
              attendeeId: pending.attendeeId,
              messageText: pending.messageText,
              sendStatus: MessageStatus.sent,
              sentAt: DateTime.now(),
            );
            onMessageSent(messageLog);
          }

          debugPrint('Successfully sent pending message to ${pending.attendeeName}');
          
        } catch (e) {
          // Failed - update attempt count
          final errorMessage = e.toString();
          final isStillBalanceIssue = _isBalanceError(errorMessage);
          
          await _pendingMessageRepo.updatePendingMessage(
            pending.copyWith(
              status: isStillBalanceIssue ? PendingMessageStatus.pending : PendingMessageStatus.failed,
              lastAttemptAt: DateTime.now(),
              attemptCount: pending.attemptCount + 1,
              lastError: errorMessage,
            ),
          );

          if (!isStillBalanceIssue && onMessageFailed != null) {
            final messageLog = MessageLogModel(
              serviceId: pending.serviceId,
              attendeeId: pending.attendeeId,
              messageText: pending.messageText,
              sendStatus: MessageStatus.failed,
              errorMessage: errorMessage,
            );
            onMessageFailed(messageLog);
          }

          debugPrint('Failed to send pending message to ${pending.attendeeName}: $errorMessage');
          
          // If still balance issue, stop retrying
          if (isStillBalanceIssue) {
            break;
          }
        }

        // Small delay between retries
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Clean up sent messages
      await _pendingMessageRepo.clearSentMessages();
      
    } catch (e) {
      debugPrint('Error retrying pending messages: $e');
    }
  }

  /// Get count of pending messages
  Future<int> getPendingMessagesCount() async {
    return await _pendingMessageRepo.getPendingCount();
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}