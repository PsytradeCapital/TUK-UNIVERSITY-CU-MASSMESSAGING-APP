import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Utility class for accessibility features
class AccessibilityUtils {
  /// Generate semantic label for attendee count
  static String getAttendeeCountSemantics(int count) {
    if (count == 0) {
      return 'No attendees registered';
    } else if (count == 1) {
      return '1 attendee registered';
    } else {
      return '$count attendees registered';
    }
  }

  /// Generate semantic label for service status
  static String getServiceStatusSemantics(bool hasActiveService, bool messageSent) {
    if (!hasActiveService) {
      return 'No active service session';
    } else if (messageSent) {
      return 'Service completed, messages sent';
    } else {
      return 'Active service session in progress';
    }
  }

  /// Generate semantic label for navigation tabs
  static String getTabSemantics(int index, String label, {bool isEnabled = true, int? badgeCount}) {
    String semantics = label;
    
    if (!isEnabled) {
      semantics += ', disabled';
    }
    
    if (badgeCount != null && badgeCount > 0) {
      semantics += ', $badgeCount notifications';
    }
    
    semantics += ', tab ${index + 1} of 4';
    
    return semantics;
  }

  /// Generate semantic label for form fields
  static String getFormFieldSemantics(String label, {bool isRequired = false, String? error}) {
    String semantics = label;
    
    if (isRequired) {
      semantics += ', required field';
    }
    
    if (error != null) {
      semantics += ', error: $error';
    }
    
    return semantics;
  }

  /// Generate semantic label for buttons
  static String getButtonSemantics(String label, {String? action, bool isEnabled = true}) {
    String semantics = label;
    
    if (action != null) {
      semantics += ', $action';
    }
    
    if (!isEnabled) {
      semantics += ', disabled';
    }
    
    semantics += ', button';
    
    return semantics;
  }

  /// Generate semantic label for progress indicators
  static String getProgressSemantics(double progress, {String? context}) {
    final percentage = (progress * 100).round();
    String semantics = '$percentage percent complete';
    
    if (context != null) {
      semantics = '$context, $semantics';
    }
    
    return semantics;
  }

  /// Generate semantic label for lists
  static String getListSemantics(int itemCount, String itemType) {
    if (itemCount == 0) {
      return 'No $itemType available';
    } else if (itemCount == 1) {
      return '1 $itemType';
    } else {
      return '$itemCount ${itemType}s';
    }
  }

  /// Generate semantic label for status indicators
  static String getStatusSemantics(String status, {String? context}) {
    String semantics = 'Status: $status';
    
    if (context != null) {
      semantics = '$context, $semantics';
    }
    
    return semantics;
  }

  /// Create semantic announcements for important events
  static void announceToScreenReader(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Get recommended minimum touch target size
  static const double minimumTouchTargetSize = 48.0;

  /// Ensure widget meets minimum touch target size
  static Widget ensureMinimumTouchTarget(Widget child, {double? width, double? height}) {
    return SizedBox(
      width: width ?? minimumTouchTargetSize,
      height: height ?? minimumTouchTargetSize,
      child: child,
    );
  }

  /// Create accessible card with proper semantics
  static Widget createAccessibleCard({
    required Widget child,
    required String semanticLabel,
    VoidCallback? onTap,
    String? hint,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: hint,
      button: onTap != null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }

  /// Create accessible list tile
  static Widget createAccessibleListTile({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    String? semanticLabel,
    String? hint,
  }) {
    return Semantics(
      label: semanticLabel ?? title,
      hint: hint,
      button: onTap != null,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  /// Create accessible icon button
  static Widget createAccessibleIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? hint,
    Color? color,
    double? size,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: IconButton(
        icon: Icon(icon, color: color, size: size),
        onPressed: onPressed,
        tooltip: label,
      ),
    );
  }

  /// Create accessible floating action button
  static Widget createAccessibleFAB({
    required Widget child,
    required String label,
    required VoidCallback onPressed,
    String? hint,
    Color? backgroundColor,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        tooltip: label,
        child: child,
      ),
    );
  }

  /// Create accessible text field
  static Widget createAccessibleTextField({
    required String label,
    TextEditingController? controller,
    String? hint,
    String? error,
    bool isRequired = false,
    TextInputType? keyboardType,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: getFormFieldSemantics(label, isRequired: isRequired, error: error),
      textField: true,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          suffixText: isRequired ? '*' : null,
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onTap: onTap,
      ),
    );
  }

  /// Create accessible dropdown
  static Widget createAccessibleDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? error,
    bool isRequired = false,
  }) {
    return Semantics(
      label: getFormFieldSemantics(label, isRequired: isRequired, error: error),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          suffixText: isRequired ? '*' : null,
        ),
      ),
    );
  }

  /// Create accessible progress indicator
  static Widget createAccessibleProgress({
    required double progress,
    String? label,
    String? context,
  }) {
    return Semantics(
      label: getProgressSemantics(progress, context: context),
      value: '${(progress * 100).round()}%',
      child: Column(
        children: [
          if (label != null) Text(label),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  /// Create accessible switch
  static Widget createAccessibleSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? description,
  }) {
    return Semantics(
      label: label,
      hint: description,
      toggled: value,
      child: SwitchListTile(
        title: Text(label),
        subtitle: description != null ? Text(description) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// Create accessible chip
  static Widget createAccessibleChip({
    required String label,
    VoidCallback? onDeleted,
    VoidCallback? onPressed,
    bool isSelected = false,
  }) {
    String semantics = label;
    if (isSelected) {
      semantics += ', selected';
    }
    if (onDeleted != null) {
      semantics += ', deletable';
    }

    return Semantics(
      label: semantics,
      button: onPressed != null,
      selected: isSelected,
      child: onPressed != null
          ? ActionChip(
              label: Text(label),
              onPressed: onPressed,
            )
          : Chip(
              label: Text(label),
              onDeleted: onDeleted,
            ),
    );
  }

  /// Create accessible alert dialog
  static Widget createAccessibleAlertDialog({
    required String title,
    required String content,
    List<Widget>? actions,
  }) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: AlertDialog(
        title: Semantics(
          header: true,
          child: Text(title),
        ),
        content: Semantics(
          child: Text(content),
        ),
        actions: actions,
      ),
    );
  }

  /// Create accessible snack bar
  static SnackBar createAccessibleSnackBar({
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration duration = const Duration(seconds: 4),
  }) {
    return SnackBar(
      content: Semantics(
        liveRegion: true,
        child: Text(message),
      ),
      action: actionLabel != null && onActionPressed != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onActionPressed,
            )
          : null,
      duration: duration,
    );
  }

  /// Provide haptic feedback for interactions
  static void provideHapticFeedback(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.lightImpact:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.mediumImpact:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavyImpact:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selectionClick:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.vibrate:
        HapticFeedback.vibrate();
        break;
    }
  }
}

/// Enum for haptic feedback types
enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
  vibrate,
}

/// Custom semantics widget for complex accessibility scenarios
class CustomSemantics extends StatelessWidget {
  final Widget child;
  final String? label;
  final String? hint;
  final String? value;
  final bool? button;
  final bool? header;
  final bool? textField;
  final bool? selected;
  final bool? toggled;
  final bool? liveRegion;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CustomSemantics({
    Key? key,
    required this.child,
    this.label,
    this.hint,
    this.value,
    this.button,
    this.header,
    this.textField,
    this.selected,
    this.toggled,
    this.liveRegion,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: button,
      header: header,
      textField: textField,
      selected: selected,
      toggled: toggled,
      liveRegion: liveRegion,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}