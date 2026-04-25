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
  final StreamController<SMSProgress> _progressController =
      StreamController<SMSProgress>.broadcast();
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

  // ---------------------------------------------------------------------------
  // Phone number helpers
  // ---------------------------------------------------------------------------

  /// Normalise any Kenyan phone number to the 07/01 local format used by SMS.
  /// Accepts: 07xxxxxxxx, 01xxxxxxxx, +2547xxxxxxxx, +2541xxxxxxxx, 2547xxxxxxxx
  static String _normalisePhone(String raw) {
    final phone = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.startsWith('+254') && phone.length == 13) {
      return '0${phone.substring(4)}'; // +254712345678 → 0712345678
    }
    if (phone.startsWith('254') && phone.length == 12) {
      return '0${phone.substring(3)}'; // 254712345678 → 0712345678
    }
    return phone; // already 07/01 format or unknown
  }

  /// Returns true if the phone (after normalisation) is a valid Kenyan number.
  static bool _isValidPhone(String phone) {
    final p = _normalisePhone(phone);
    return (p.startsWith('07') || p.startsWith('01')) &&
        p.length == 10 &&
        RegExp(r'^0[71]\d{8}$').hasMatch(p);
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Check and request SMS permissions
  Future<SMSPermissionStatus> checkSMSPermission() async {
    try {
      final granted = await _telephony.requestPhoneAndSmsPermissions;
      if (granted == true) return SMSPermissionStatus.granted;
      if (granted == false) return SMSPermissionStatus.denied;
      return SMSPermissionStatus.unknown;
    } catch (e) {
      debugPrint('Error checking SMS permissions: $e');
      return SMSPermissionStatus.unknown;
    }
  }

  /// Request SMS permissions explicitly
  Future<SMSPermissionStatus> requestSMSPermission() async {
    try {
      final granted = await _telephony.requestSmsPermissions;
      if (granted == true) return SMSPermissionStatus.granted;
      return SMSPermissionStatus.denied;
    } catch (e) {
      debugPrint('Error requesting SMS permissions: $e');
      return SMSPermissionStatus.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Bulk send
  // ---------------------------------------------------------------------------

  /// Send bulk SMS to multiple attendees with progress tracking.
  /// Phone numbers are normalised before sending so both 07xxx and +254xxx
  /// stored formats work correctly.
  Future<void> sendBulkSMS(
    List<AttendeeModel> attendees,
    String message, {
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  }) async {
    if (_isSending) throw Exception('SMS sending is already in progress');
    if (attendees.isEmpty) throw Exception('No attendees provided for SMS sending');
    if (message.trim().isEmpty) throw Exception('Message cannot be empty');

    // Check permissions first
    final permissionStatus = await checkSMSPermission();
    if (permissionStatus != SMSPermissionStatus.granted) {
      throw Exception('SMS permissions not granted');
    }

    // Validate and normalise phone numbers
    final validAttendees = <AttendeeModel>[];
    final invalidAttendees = <String>[];

    debugPrint('🔍 Validating ${attendees.length} phone numbers...');

    for (final attendee in attendees) {
      if (_isValidPhone(attendee.phoneNumber)) {
        // Store a copy with the normalised phone so _sendSingleSMS always gets
        // a clean 07/01 format regardless of how it was saved.
        final normalised = _normalisePhone(attendee.phoneNumber);
        validAttendees.add(
          normalised == attendee.phoneNumber
              ? attendee
              : attendee.copyWith(phoneNumber: normalised),
        );
        debugPrint('   ✅ ${attendee.name}: ${attendee.phoneNumber} → $normalised');
      } else {
        invalidAttendees.add('${attendee.name}: ${attendee.phoneNumber}');
        debugPrint('   ❌ ${attendee.name}: ${attendee.phoneNumber} (invalid)');
      }
    }

    debugPrint('📊 Valid: ${validAttendees.length}  Invalid: ${invalidAttendees.length}');

    if (validAttendees.isEmpty) {
      throw Exception(
        'No valid phone numbers found. '
        'All ${attendees.length} attendees have invalid phone numbers.\n'
        'Invalid: ${invalidAttendees.join(", ")}',
      );
    }

    // Initialise sending state
    _isSending = true;
    _isPaused = false;
    _isCancelled = false;
    _currentRecipients = validAttendees;
    _currentMessage = message;
    _currentIndex = 0;

    _currentProgress = SMSProgress(
      totalMessages: validAttendees.length,
      sentMessages: 0,
      failedMessages: 0,
      currentIndex: 0,
      state: SMSSendingState.sending,
    );
    _progressController.add(_currentProgress);

    try {
      await _sendMessagesSequentially(
          validAttendees, message, onMessageSent, onMessageFailed);
    } finally {
      _isSending = false;
      _currentRecipients = null;
      _currentMessage = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Resume / Pause / Cancel
  // ---------------------------------------------------------------------------

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
      final remaining = _currentRecipients!.sublist(_currentIndex);
      await _sendMessagesSequentially(
          remaining, _currentMessage!, onMessageSent, onMessageFailed);
    } finally {
      _isSending = false;
    }
  }

  void pauseSending() {
    if (!_isSending) return;
    _isPaused = true;
    _isSending = false;
    _currentProgress = _currentProgress.copyWith(state: SMSSendingState.paused);
    _progressController.add(_currentProgress);
  }

  void cancelSending() {
    _isCancelled = true;
    _isPaused = false;
    _isSending = false;
    _currentProgress = _currentProgress.copyWith(state: SMSSendingState.cancelled);
    _progressController.add(_currentProgress);
    _currentRecipients = null;
    _currentMessage = null;
    _currentIndex = 0;
  }

  // ---------------------------------------------------------------------------
  // Internal sequential send
  // ---------------------------------------------------------------------------

  Future<void> _sendMessagesSequentially(
    List<AttendeeModel> attendees,
    String message,
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  ) async {
    for (int i = 0; i < attendees.length; i++) {
      if (_isPaused || _isCancelled) break;

      final attendee = attendees[i];
      final personalizedMessage = personalizeMessage(message, attendee.name);

      _currentProgress = _currentProgress.copyWith(
        currentIndex: _currentIndex + i,
        currentRecipient: attendee.name,
      );
      _progressController.add(_currentProgress);

      try {
        if (onMessageSent != null) {
          onMessageSent(MessageLogModel(
            serviceId: 0,
            attendeeId: attendee.id ?? 0,
            messageText: personalizedMessage,
            sendStatus: MessageStatus.sending,
          ));
        }

        await _sendSingleSMS(attendee.phoneNumber, personalizedMessage);

        _currentProgress = _currentProgress.copyWith(
          sentMessages: _currentProgress.sentMessages + 1,
        );
        _progressController.add(_currentProgress);

        if (onMessageSent != null) {
          onMessageSent(MessageLogModel(
            serviceId: 0,
            attendeeId: attendee.id ?? 0,
            messageText: personalizedMessage,
            sendStatus: MessageStatus.sent,
            sentAt: DateTime.now(),
          ));
        }

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        final errorMessage = e.toString();
        final isBalanceIssue = _isBalanceError(errorMessage);

        if (isBalanceIssue) {
          try {
            await _pendingMessageRepo.addPendingMessage(PendingMessageModel(
              serviceId: 0,
              attendeeId: attendee.id ?? 0,
              phoneNumber: attendee.phoneNumber,
              attendeeName: attendee.name,
              messageText: personalizedMessage,
              status: PendingMessageStatus.pending,
              lastError: 'Insufficient SMS balance',
            ));
            debugPrint('Message saved as pending for ${attendee.name}');
          } catch (pendingError) {
            debugPrint('Failed to save pending message: $pendingError');
          }
        }

        _currentProgress = _currentProgress.copyWith(
          failedMessages: _currentProgress.failedMessages + 1,
          lastError: isBalanceIssue
              ? 'Saved as pending – will retry when balance available'
              : errorMessage,
        );
        _progressController.add(_currentProgress);

        if (onMessageFailed != null) {
          onMessageFailed(MessageLogModel(
            serviceId: 0,
            attendeeId: attendee.id ?? 0,
            messageText: personalizedMessage,
            sendStatus:
                isBalanceIssue ? MessageStatus.pending : MessageStatus.failed,
            errorMessage: errorMessage,
          ));
        }

        if (_isCriticalError(errorMessage)) {
          _handleCriticalError(errorMessage);
          pauseSending();
          break;
        }
      }
    }

    if (!_isPaused && !_isCancelled) {
      _currentProgress = _currentProgress.copyWith(
        state: SMSSendingState.completed,
        currentRecipient: null,
      );
      _progressController.add(_currentProgress);

      _notificationService.showSendingCompletedNotification(
        _currentProgress.sentMessages,
        _currentProgress.failedMessages,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Single SMS send
  // ---------------------------------------------------------------------------

  /// Send a single SMS. Normalises the phone number before sending.
  Future<void> _sendSingleSMS(String phoneNumber, String message) async {
    // Normalise to 07/01 format
    final smsPhone = _normalisePhone(phoneNumber);

    if (smsPhone.isEmpty) throw Exception('Phone number is empty');

    if (!_isValidPhone(smsPhone)) {
      throw Exception(
          'Invalid phone number: $smsPhone (must be 07xxxxxxxx or 01xxxxxxxx)');
    }

    debugPrint('📱 Sending SMS to: $smsPhone (original: $phoneNumber)');

    if (message.length > 160) {
      debugPrint(
          '⚠️  Message length ${message.length} > 160 chars – sending as multipart.');
    }

    await _telephony.sendSms(
      to: smsPhone,
      message: message,
      isMultipart: message.length > 160,
    );

    debugPrint('✅ SMS sent to $smsPhone (${message.length} chars)');
  }

  // ---------------------------------------------------------------------------
  // Personalisation
  // ---------------------------------------------------------------------------

  String personalizeMessage(String message, String attendeeName) {
    return message
        .replaceAll('{name}', attendeeName)
        .replaceAll('{Name}', attendeeName)
        .replaceAll('{NAME}', attendeeName.toUpperCase())
        .replaceAll('[name]', attendeeName)
        .replaceAll('[Name]', attendeeName)
        .replaceAll('[NAME]', attendeeName.toUpperCase());
  }

  // ---------------------------------------------------------------------------
  // Error classification
  // ---------------------------------------------------------------------------

  bool _isCriticalError(String errorMessage) {
    final lower = errorMessage.toLowerCase();
    return [
      'insufficient credit', 'no credit', 'bundle depleted', 'airtime',
      'balance', 'network error', 'service unavailable', 'sms limit exceeded',
      'rate limit', 'quota exceeded', 'permission denied', 'unauthorized',
    ].any(lower.contains);
  }

  bool _isBalanceError(String errorMessage) {
    final lower = errorMessage.toLowerCase();
    return [
      'insufficient credit', 'no credit', 'bundle depleted', 'airtime',
      'balance', 'sms limit exceeded', 'quota exceeded',
    ].any(lower.contains);
  }

  bool isBundleDepletionError(String errorMessage) => _isBalanceError(errorMessage);

  String getUserFriendlyErrorMessage(String errorMessage) {
    final lower = errorMessage.toLowerCase();

    if (lower.contains('insufficient credit') ||
        lower.contains('no credit') ||
        lower.contains('bundle depleted') ||
        lower.contains('airtime') ||
        lower.contains('balance')) {
      return 'Insufficient airtime or SMS bundle. Please top up and resume.';
    }
    if (lower.contains('network error') || lower.contains('service unavailable')) {
      return 'Network issue. Check your signal and try again.';
    }
    if (lower.contains('sms limit exceeded') ||
        lower.contains('rate limit') ||
        lower.contains('quota exceeded')) {
      return 'SMS sending limit reached. Wait a moment before resuming.';
    }
    if (lower.contains('permission denied') || lower.contains('unauthorized')) {
      return 'SMS permissions required. Grant SMS permissions in settings.';
    }
    if (lower.contains('invalid number') || lower.contains('invalid phone')) {
      return 'Invalid phone number format detected.';
    }
    return 'SMS sending failed. Check your connection and try again.';
  }

  Duration getRetryDelay(String errorMessage) {
    final lower = errorMessage.toLowerCase();
    if (lower.contains('rate limit') || lower.contains('sms limit')) {
      return const Duration(minutes: 5);
    }
    if (lower.contains('network') || lower.contains('service unavailable')) {
      return const Duration(seconds: 30);
    }
    return const Duration(seconds: 10);
  }

  void _handleCriticalError(String errorMessage) {
    if (isBundleDepletionError(errorMessage)) {
      _notificationService.showBundleDepletionNotification(
        onTopUp: () => debugPrint('User requested to top up airtime'),
      );
    } else if (errorMessage.toLowerCase().contains('network') ||
        errorMessage.toLowerCase().contains('service unavailable')) {
      _notificationService.showNetworkErrorNotification(
        onRetry: () {
          if (_currentRecipients != null && _currentMessage != null) {
            resumeSending();
          }
        },
      );
    } else if (errorMessage.toLowerCase().contains('permission')) {
      _notificationService.showPermissionErrorNotification(
        onSettings: () =>
            debugPrint('User should grant SMS permissions in settings'),
      );
    } else {
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

  // ---------------------------------------------------------------------------
  // Pending messages retry
  // ---------------------------------------------------------------------------

  Future<void> retryPendingMessages({
    Function(MessageLogModel)? onMessageSent,
    Function(MessageLogModel)? onMessageFailed,
  }) async {
    try {
      final pendingMessages = await _pendingMessageRepo.getAllPendingMessages();
      if (pendingMessages.isEmpty) return;

      debugPrint('Retrying ${pendingMessages.length} pending messages');

      for (final pending in pendingMessages) {
        if (!pending.canRetry) continue;

        try {
          await _sendSingleSMS(pending.phoneNumber, pending.messageText);

          await _pendingMessageRepo.updatePendingMessage(
            pending.copyWith(
              status: PendingMessageStatus.sent,
              lastAttemptAt: DateTime.now(),
              attemptCount: pending.attemptCount + 1,
            ),
          );

          if (onMessageSent != null) {
            onMessageSent(MessageLogModel(
              serviceId: pending.serviceId,
              attendeeId: pending.attendeeId,
              messageText: pending.messageText,
              sendStatus: MessageStatus.sent,
              sentAt: DateTime.now(),
            ));
          }

          debugPrint('Sent pending message to ${pending.attendeeName}');
        } catch (e) {
          final errorMessage = e.toString();
          final isStillBalance = _isBalanceError(errorMessage);

          await _pendingMessageRepo.updatePendingMessage(
            pending.copyWith(
              status: isStillBalance
                  ? PendingMessageStatus.pending
                  : PendingMessageStatus.failed,
              lastAttemptAt: DateTime.now(),
              attemptCount: pending.attemptCount + 1,
              lastError: errorMessage,
            ),
          );

          if (!isStillBalance && onMessageFailed != null) {
            onMessageFailed(MessageLogModel(
              serviceId: pending.serviceId,
              attendeeId: pending.attendeeId,
              messageText: pending.messageText,
              sendStatus: MessageStatus.failed,
              errorMessage: errorMessage,
            ));
          }

          debugPrint(
              'Failed pending message to ${pending.attendeeName}: $errorMessage');

          if (isStillBalance) break; // Stop if still no balance
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      await _pendingMessageRepo.clearSentMessages();
    } catch (e) {
      debugPrint('Error retrying pending messages: $e');
    }
  }

  Future<int> getPendingMessagesCount() async {
    return await _pendingMessageRepo.getPendingCount();
  }

  // ---------------------------------------------------------------------------
  // Stats / Reset
  // ---------------------------------------------------------------------------

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

  void setupDeliveryStatusListener(
      Function(String phoneNumber, bool delivered) onDeliveryStatus) {
    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          debugPrint('Received SMS from: ${message.address}');
        },
        listenInBackground: false,
      );
    } catch (e) {
      debugPrint('Error setting up delivery status listener: $e');
    }
  }

  Future<void> markMessageAsDelivered(
    int messageId,
    Function(MessageLogModel) onStatusUpdate,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      onStatusUpdate(MessageLogModel(
        messageId: messageId,
        serviceId: 0,
        attendeeId: 0,
        messageText: '',
        sendStatus: MessageStatus.delivered,
        sentAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('Error marking message as delivered: $e');
    }
  }

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

  void dispose() {
    _progressController.close();
  }
}
