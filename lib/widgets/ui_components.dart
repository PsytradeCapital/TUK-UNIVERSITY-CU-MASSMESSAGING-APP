import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/accessibility_utils.dart';
import '../utils/responsive_utils.dart';

/// Collection of reusable UI components with consistent styling and accessibility
class UIComponents {
  
  /// Create a primary button with consistent styling
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    bool isEnabled = true,
    String? semanticLabel,
    String? hint,
  }) {
    return Builder(
      builder: (context) {
        final buttonHeight = ResponsiveUtils.getResponsiveButtonHeight(context);
        
        return Semantics(
          label: semanticLabel ?? AccessibilityUtils.getButtonSemantics(
            text, 
            isEnabled: isEnabled && !isLoading
          ),
          hint: hint,
          button: true,
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton.icon(
              onPressed: isEnabled && !isLoading ? onPressed : null,
              icon: isLoading 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.textOnPrimary,
                      ),
                    ),
                  )
                : icon != null 
                  ? Icon(icon) 
                  : const SizedBox.shrink(),
              label: Text(text),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled ? AppTheme.primaryBlue : AppTheme.textHint,
                foregroundColor: AppTheme.textOnPrimary,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Create a secondary button with consistent styling
  static Widget secondaryButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isEnabled = true,
    String? semanticLabel,
    String? hint,
  }) {
    return Builder(
      builder: (context) {
        final buttonHeight = ResponsiveUtils.getResponsiveButtonHeight(context);
        
        return Semantics(
          label: semanticLabel ?? AccessibilityUtils.getButtonSemantics(
            text, 
            isEnabled: isEnabled
          ),
          hint: hint,
          button: true,
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton.icon(
              onPressed: isEnabled ? onPressed : null,
              icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
              label: Text(text),
              style: OutlinedButton.styleFrom(
                foregroundColor: isEnabled ? AppTheme.primaryBlue : AppTheme.textHint,
                side: BorderSide(
                  color: isEnabled ? AppTheme.primaryBlue : AppTheme.textHint,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Create a text button with consistent styling
  static Widget textButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isEnabled = true,
    String? semanticLabel,
    String? hint,
  }) {
    return Semantics(
      label: semanticLabel ?? AccessibilityUtils.getButtonSemantics(
        text, 
        isEnabled: isEnabled
      ),
      hint: hint,
      button: true,
      child: TextButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(text),
        style: TextButton.styleFrom(
          foregroundColor: isEnabled ? AppTheme.primaryBlue : AppTheme.textHint,
        ),
      ),
    );
  }

  /// Create a form field with consistent styling and accessibility
  static Widget formField({
    required String label,
    TextEditingController? controller,
    String? hint,
    String? error,
    bool isRequired = false,
    bool isEnabled = true,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLines,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? semanticLabel,
  }) {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                child: Text(
                  label + (isRequired ? ' *' : ''),
                  style: AppTheme.getTextStyle('subtitle'),
                ),
              ),
            AccessibilityUtils.createAccessibleTextField(
              label: semanticLabel ?? label,
              controller: controller,
              hint: hint,
              error: error,
              isRequired: isRequired,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onChanged: onChanged,
              onTap: onTap,
            ),
          ],
        );
      },
    );
  }

  /// Create a dropdown field with consistent styling
  static Widget dropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? error,
    bool isRequired = false,
    bool isEnabled = true,
    String? semanticLabel,
  }) {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                child: Text(
                  label + (isRequired ? ' *' : ''),
                  style: AppTheme.getTextStyle('subtitle'),
                ),
              ),
            AccessibilityUtils.createAccessibleDropdown<T>(
              label: semanticLabel ?? label,
              value: value,
              items: items,
              onChanged: isEnabled ? onChanged : null,
              hint: hint,
              error: error,
              isRequired: isRequired,
            ),
          ],
        );
      },
    );
  }

  /// Create a card with consistent styling
  static Widget card({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? elevation,
    VoidCallback? onTap,
    String? semanticLabel,
    String? hint,
  }) {
    return Builder(
      builder: (context) {
        final responsivePadding = padding ?? ResponsiveUtils.getResponsivePadding(context);
        final responsiveMargin = margin ?? ResponsiveUtils.getResponsiveMargin(context);
        final responsiveElevation = elevation ?? ResponsiveUtils.getResponsiveCardElevation(context);
        
        return AccessibilityUtils.createAccessibleCard(
          semanticLabel: semanticLabel ?? 'Card',
          hint: hint,
          onTap: onTap,
          child: Padding(
            padding: responsivePadding,
            child: child,
          ),
        );
      },
    );
  }

  /// Create a list tile with consistent styling
  static Widget listTile({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    String? semanticLabel,
    String? hint,
  }) {
    return Builder(
      builder: (context) {
        final tileHeight = ResponsiveUtils.getResponsiveListTileHeight(context);
        
        return SizedBox(
          height: tileHeight,
          child: AccessibilityUtils.createAccessibleListTile(
            title: title,
            subtitle: subtitle,
            leading: leading,
            trailing: trailing,
            onTap: onTap,
            semanticLabel: semanticLabel,
            hint: hint,
          ),
        );
      },
    );
  }

  /// Create a section header with consistent styling
  static Widget sectionHeader({
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: ResponsiveUtils.getResponsiveTextStyle(
                          context,
                          baseStyle: AppTheme.getTextStyle('title'),
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        subtitle,
                        style: ResponsiveUtils.getResponsiveTextStyle(
                          context,
                          baseStyle: AppTheme.getTextStyle('subtitle'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
        );
      },
    );
  }

  /// Create a status chip with consistent styling
  static Widget statusChip({
    required String label,
    required String status,
    VoidCallback? onTap,
  }) {
    final color = AppTheme.getStatusColor(status);
    
    return AccessibilityUtils.createAccessibleChip(
      label: label,
      onPressed: onTap,
      isSelected: status == 'active' || status == 'completed',
    );
  }

  /// Create a progress indicator with consistent styling
  static Widget progressIndicator({
    required double progress,
    String? label,
    String? context,
  }) {
    return AccessibilityUtils.createAccessibleProgress(
      progress: progress,
      label: label,
      context: context,
    );
  }

  /// Create an empty state widget
  static Widget emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Builder(
      builder: (context) {
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context) * 2;
        
        return Center(
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: AppTheme.textHint,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 16)),
                Text(
                  title,
                  style: ResponsiveUtils.getResponsiveTextStyle(
                    context,
                    baseStyle: AppTheme.getTextStyle('title'),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 8)),
                Text(
                  message,
                  style: ResponsiveUtils.getResponsiveTextStyle(
                    context,
                    baseStyle: AppTheme.getTextStyle('body'),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (actionText != null && onAction != null) ...[
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 24)),
                  primaryButton(
                    text: actionText,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Create a loading state widget
  static Widget loadingState({
    String? message,
  }) {
    return Builder(
      builder: (context) {
        return Center(
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 16)),
                  Text(
                    message,
                    style: ResponsiveUtils.getResponsiveTextStyle(
                      context,
                      baseStyle: AppTheme.getTextStyle('body'),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Create an error state widget
  static Widget errorState({
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Builder(
      builder: (context) {
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context) * 2;
        
        return Center(
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: iconSize,
                  color: AppTheme.errorRed,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 16)),
                Text(
                  title,
                  style: ResponsiveUtils.getResponsiveTextStyle(
                    context,
                    baseStyle: AppTheme.getTextStyle('title'),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 8)),
                Text(
                  message,
                  style: ResponsiveUtils.getResponsiveTextStyle(
                    context,
                    baseStyle: AppTheme.getTextStyle('body'),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (actionText != null && onAction != null) ...[
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, baseSpacing: 24)),
                  primaryButton(
                    text: actionText,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Create a success message widget
  static Widget successMessage({
    required String message,
    VoidCallback? onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.secondaryGreenLight.withOpacity(0.1),
        border: Border.all(color: AppTheme.secondaryGreen),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppTheme.secondaryGreen,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppTheme.getTextStyle('body').copyWith(
                color: AppTheme.secondaryGreenDark,
              ),
            ),
          ),
          if (onDismiss != null)
            AccessibilityUtils.createAccessibleIconButton(
              icon: Icons.close,
              label: 'Dismiss success message',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }

  /// Create an error message widget
  static Widget errorMessage({
    required String message,
    VoidCallback? onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.errorRedLight.withOpacity(0.1),
        border: Border.all(color: AppTheme.errorRed),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: AppTheme.errorRed,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppTheme.getTextStyle('body').copyWith(
                color: AppTheme.errorRedDark,
              ),
            ),
          ),
          if (onDismiss != null)
            AccessibilityUtils.createAccessibleIconButton(
              icon: Icons.close,
              label: 'Dismiss error message',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }

  /// Create a warning message widget
  static Widget warningMessage({
    required String message,
    VoidCallback? onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.warningOrangeLight.withOpacity(0.1),
        border: Border.all(color: AppTheme.warningOrange),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: AppTheme.warningOrange,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppTheme.getTextStyle('body').copyWith(
                color: AppTheme.warningOrangeDark,
              ),
            ),
          ),
          if (onDismiss != null)
            AccessibilityUtils.createAccessibleIconButton(
              icon: Icons.close,
              label: 'Dismiss warning message',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}