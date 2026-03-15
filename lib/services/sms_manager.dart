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

    // CRITICAL: Validate and filter attendees before sending
    final validAttendees = <AttendeeModel>[];
    final invalidAttendees = <String>[];
    
    debugPrint('🔍 Starting phone number validation for ${attendees.length} attendees...');
    
    for (final attendee in attendees) {
      final originalPhone = attendee.phoneNumber;
      final phone = originalPhone.trim().replaceAll(RegExp(r'\s+'), '');
      
      debugPrint('   Checking: ${attendee.name} - Original: "$originalPhone" - Cleaned: "$phone"');
      
      // Validate phone number format - accept both 07/01 and +254 formats
      bool isValid = false;
      String reason = '';
      
      if (phone.isEmpty) {
        reason = 'Empty phone number';
      }
      // Check +254 format (13 characters: +254xxxxxxxxx)
      else if (phone.startsWith('+254')) {
        if (phone.length == 13 && RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)) {
          isValid = true;
          debugPrint('      ✅ Valid +254 format');
        } else {
          reason = 'Invalid +254 format (length: ${phone.length}, expected 13)';
          debugPrint('      ❌ $reason');
        }
      }
      // Check 07 format (10 digits)
      else if (phone.startsWith('07')) {
        if (phone.length == 10 && RegExp(r'^07\d{8}$').hasMatch(phone)) {
          isValid = true;
          debugPrint('      ✅ Valid 07 format');
        } else {
          reason = 'Invalid 07 format (length: ${phone.length}, expected 10)';
          debugPrint('      ❌ $reason');
        }
      }
      // Check 01 format (10 digits)
      else if (phone.startsWith('01')) {
        if (phone.length == 10 && RegExp(r'^01\d{8}$').hasMatch(phone)) {
          isValid = true;
          debugPrint('      ✅ Valid 01 format');
        } else {
          reason = 'Invalid 01 format (length: ${phone.length}, expected 10)';
          debugPrint('      ❌ $reason');
        }
      }
      else {
        reason = 'Invalid format (starts with: ${phone.substring(0, phone.length > 4 ? 4 : phone.length)})';
        debugPrint('      ❌ $reason');
      }
      
      if (isValid) {
        validAttendees.add(attendee);
      } else {
        invalidAttendees.add('${attendee.name}: $reason');
      }
    }
    
    // Log validation results
    debugPrint('📊 SMS Validation Results:');
    debugPrint('   ✅ Valid attendees: ${validAttendees.length}');
    debugPrint('   ❌ Invalid attendees: ${invalidAttendees.length}');
    
    if (invalidAttendees.isNotEmpty) {
      debugPrint('   Invalid phone numbers:');
      for (final invalid in invalidAttendees) {
        debugPrint('      - $invalid');
      }
    }
    
    if (validAttendees.isEmpty) {
      final errorMsg = 'No valid phone numbers found. All ${attendees.length} attendees have invalid phone numbers.';
      debugPrint('❌ CRITICAL ERROR: $errorMsg');
      throw Exception(errorMsg);
    }
    
    // Show warning if some attendees were filtered out
    if (invalidAttendees.isNotEmpty) {
      debugPrint('⚠️  WARNING: ${invalidAttendees.length} attendees will be skipped due to invalid phone numbers');
    }

    // Show warning if some attendees were filtered out
    if (invalidAttendees.isNotEmpty) {
      debugPrint('⚠️  WARNING: ${invalidAttendees.length} attendees will be skipped due to invalid phone numbers');
    }

    // Initialize sending state with VALID attendees only
    _isSending = true;
    _isPaused = false;
    _isCancelled = false;
    _currentRecipients = validAttendees; // Use validated list
    _currentMessage = message;
    _currentIndex = 0;

    _currentProgress = SMSProgress(
      totalMessages: validAttendees.length, // Use validated count
      sentMessages: 0,
      failedMessages: 0,
      currentIndex: 0,
      state: SMSSendingState.sending,
    );
    _progressController.add(_currentProgress);

    try {
      await _sendMessagesSequentially(validAttendees, message, onMessageSent, onMessageFailed);
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
        // Mark as sending
        if (onMessageSent != null) {
          final sendingLog = MessageLogModel(
            serviceId: 0,
            attendeeId: attendee.id ?? 0,
            messageText: personalizedMessage,
            sendStatus: MessageStatus.sending,
          );
          onMessageSent(sendingLog);
        }
        
        // Attempt to send SMS
        await _sendSingleSMS(attendee.phoneNumber, personalizedMessage);
        
        // Success - update progress
        _currentProgress = _currentProgress.copyWith(
          sentMessages: _currentProgress.sentMessages + 1,
        );
        _progressController.add(_currentProgress);

        // Notify callback if provided - mark as sent
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
      // Get the phone number in the format needed for SMS sending
      // SMS in Kenya works with both 07xxxxxxxx and +254xxxxxxxxx formats
      String smsPhone = phoneNumber.trim();
      
      // Remove any whitespace
      smsPhone = smsPhone.replaceAll(RegExp(r'\s+'), '');
      
      // CRITICAL VALIDATION: Ensure phone number is valid
      if (smsPhone.isEmpty) {
        throw Exception('Phone number is empty');
      }
      
      // Validate phone number format - accept both 07/01 and +254 formats
      bool isValid = false;
      String displayFormat = smsPhone;
      
      // Check +254 format (13 characters: +254xxxxxxxxx)
      if (smsPhone.startsWith('+254')) {
        if (smsPhone.length == 13 && RegExp(r'^\+254[17]\d{8}$').hasMatch(smsPhone)) {
          isValid = true;
          displayFormat = smsPhone;
        }
      }
      // Check 07 format (10 digits)
      else if (smsPhone.startsWith('07')) {
        if (smsPhone.length == 10 && RegExp(r'^07\d{8}$').hasMatch(smsPhone)) {
          isValid = true;
          displayFormat = smsPhone;
        }
      }
      // Check 01 format (10 digits)
      else if (smsPhone.startsWith('01')) {
        if (smsPhone.length == 10 && RegExp(r'^01\d{8}$').hasMatch(smsPhone)) {
          isValid = true;
          displayFormat = smsPhone;
        }
      }
      
      if (!isValid) {
        throw Exception('Invalid phone number format: $smsPhone (must be 07xxxxxxxx, 01xxxxxxxx, or +254xxxxxxxxx)');
      }
      
      debugPrint('📱 Sending SMS to: $displayFormat (original: $phoneNumber)');
      
      // Check message length - SMS standard is 160 chars for single message
      if (message.length > 160) {
        debugPrint('⚠️  Message length ${message.length} exceeds 160 chars. Will send as multipart.');
      }
      
      // Send SMS using telephony plugin
      // The plugin accepts both 07xxxxxxxx and +254xxxxxxxxx formats
      await _telephony.sendSms(
        to: smsPhone,
        message: message,
        isMultipart: message.length > 160,
      );
      
      debugPrint('✅ SMS sent successfully to $displayFormat (${message.length} chars)');
    } catch (e) {
      debugPrint('❌ Failed to send SMS to $phoneNumber: $e');
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

    // No automatic greeting added - only replace explicit placeholders

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

  /// Setup SMS delivery status listener
  /// This listens for delivery receipts from the telephony system
  void setupDeliveryStatusListener(Function(String phoneNumber, bool delivered) onDeliveryStatus) {
    try {
      // Note: The telephony plugin has limited delivery receipt support on Android
      // Most carriers don't reliably send delivery receipts
      // This is a placeholder for when/if delivery receipts become available
      
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          // Check if this is a delivery report
          // Delivery reports typically come from specific short codes
          debugPrint('Received SMS from: ${message.address}');
        },
        listenInBackground: false,
      );
    } catch (e) {
      debugPrint('Error setting up delivery status listener: $e');
    }
  }

  /// Manually mark a message as delivered
  /// This can be called from the UI or after a certain time period
  Future<void> markMessageAsDelivered(
    int messageId,
    Function(MessageLogModel) onStatusUpdate,
  ) async {
    try {
      // In a real implementation, this would check with the SMS provider
      // For now, we assume messages marked as "sent" are delivered after a delay
      await Future.delayed(const Duration(seconds: 2));
      
      final deliveredLog = MessageLogModel(
        messageId: messageId,
        serviceId: 0,
        attendeeId: 0,
        messageText: '',
        sendStatus: MessageStatus.delivered,
        sentAt: DateTime.now(),
      );
      
      onStatusUpdate(deliveredLog);
    } catch (e) {
      debugPrint('Error marking message as delivered: $e');
    }
  }

  /// Auto-update sent messages to delivered after a delay
  /// This simulates delivery confirmation when actual delivery receipts aren't available
  Future<void> autoUpdateSentToDelivered({
    required List<int> messageIds,
    required Function(int messageId) onDelivered,
    Duration delay = const Duration(seconds: 5),
  }) async {
    try {
      await Future.delayed(delay);
      
      for (final messageId in messageIds) {
        onDelivered(messageId);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('Error auto-updating messages to delivered: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}