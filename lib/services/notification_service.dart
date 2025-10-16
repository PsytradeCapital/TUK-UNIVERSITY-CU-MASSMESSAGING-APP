import 'package:flutter/material.dart';

enum NotificationType {
  info,
  success,
  warning,
  error,
  bundleDepletion,
  networkError,
  permissionError,
}

class NotificationMessage {
  final String title;
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? action;
  final String? actionLabel;

  NotificationMessage({
    required this.title,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
    this.action,
    this.actionLabel,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationMessage> _notifications = [];
  final List<Function(NotificationMessage)> _listeners = [];

  // Add listener for notifications
  void addListener(Function(NotificationMessage) listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(Function(NotificationMessage) listener) {
    _listeners.remove(listener);
  }

  // Show notification
  void showNotification(NotificationMessage notification) {
    _notifications.add(notification);
    
    // Notify all listeners
    for (final listener in _listeners) {
      listener(notification);
    }

    // Auto-remove after duration
    Future.delayed(notification.duration, () {
      _notifications.remove(notification);
    });
  }

  // Show bundle depletion notification
  void showBundleDepletionNotification({VoidCallback? onTopUp}) {
    showNotification(NotificationMessage(
      title: 'SMS Bundle Depleted',
      message: 'Your SMS bundle or airtime is insufficient. Please top up to continue sending messages.',
      type: NotificationType.bundleDepletion,
      duration: const Duration(seconds: 8),
      action: onTopUp,
      actionLabel: 'Top Up',
    ));
  }

  // Show network error notification
  void showNetworkErrorNotification({VoidCallback? onRetry}) {
    showNotification(NotificationMessage(
      title: 'Network Error',
      message: 'Unable to send SMS due to network issues. Please check your connection.',
      type: NotificationType.networkError,
      duration: const Duration(seconds: 6),
      action: onRetry,
      actionLabel: 'Retry',
    ));
  }

  // Show permission error notification
  void showPermissionErrorNotification({VoidCallback? onSettings}) {
    showNotification(NotificationMessage(
      title: 'SMS Permission Required',
      message: 'SMS permissions are required to send messages. Please grant permissions in settings.',
      type: NotificationType.permissionError,
      duration: const Duration(seconds: 8),
      action: onSettings,
      actionLabel: 'Settings',
    ));
  }

  // Show SMS sending paused notification
  void showSendingPausedNotification(String reason, {VoidCallback? onResume}) {
    showNotification(NotificationMessage(
      title: 'SMS Sending Paused',
      message: reason,
      type: NotificationType.warning,
      duration: const Duration(seconds: 6),
      action: onResume,
      actionLabel: 'Resume',
    ));
  }

  // Show SMS sending completed notification
  void showSendingCompletedNotification(int totalSent, int totalFailed) {
    final message = totalFailed > 0 
        ? 'Sent $totalSent messages successfully, $totalFailed failed.'
        : 'All $totalSent messages sent successfully!';
    
    showNotification(NotificationMessage(
      title: 'SMS Sending Complete',
      message: message,
      type: totalFailed > 0 ? NotificationType.warning : NotificationType.success,
      duration: const Duration(seconds: 5),
    ));
  }

  // Show generic error notification
  void showErrorNotification(String title, String message, {VoidCallback? action, String? actionLabel}) {
    showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.error,
      duration: const Duration(seconds: 6),
      action: action,
      actionLabel: actionLabel,
    ));
  }

  // Show generic success notification
  void showSuccessNotification(String title, String message) {
    showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.success,
      duration: const Duration(seconds: 3),
    ));
  }

  // Show generic info notification
  void showInfoNotification(String title, String message) {
    showNotification(NotificationMessage(
      title: title,
      message: message,
      type: NotificationType.info,
      duration: const Duration(seconds: 4),
    ));
  }

  // Get notification color based on type
  static Color getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
      case NotificationType.permissionError:
        return Colors.red;
      case NotificationType.warning:
      case NotificationType.bundleDepletion:
        return Colors.orange;
      case NotificationType.networkError:
        return Colors.blue;
      case NotificationType.info:
      default:
        return Colors.grey;
    }
  }

  // Get notification icon based on type
  static IconData getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
      case NotificationType.permissionError:
        return Icons.error;
      case NotificationType.warning:
      case NotificationType.bundleDepletion:
        return Icons.warning;
      case NotificationType.networkError:
        return Icons.wifi_off;
      case NotificationType.info:
      default:
        return Icons.info;
    }
  }

  // Clear all notifications
  void clearAll() {
    _notifications.clear();
  }

  // Get current notifications
  List<NotificationMessage> get notifications => List.unmodifiable(_notifications);
}