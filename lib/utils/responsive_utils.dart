import 'package:flutter/material.dart';

/// Utility class for responsive design
class ResponsiveUtils {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }

  /// Get responsive value based on device type
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  /// Get responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.all(8),
      tablet: const EdgeInsets.all(12),
      desktop: const EdgeInsets.all(16),
    );
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseFontSize,
  }) {
    return getResponsiveValue(
      context,
      mobile: baseFontSize,
      tablet: baseFontSize * 1.1,
      desktop: baseFontSize * 1.2,
    );
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );
  }

  /// Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 48.0,
      tablet: 52.0,
      desktop: 56.0,
    );
  }

  /// Get responsive card elevation
  static double getResponsiveCardElevation(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 2.0,
      tablet: 4.0,
      desktop: 6.0,
    );
  }

  /// Get responsive grid columns
  static int getResponsiveGridColumns(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }

  /// Get responsive list tile height
  static double getResponsiveListTileHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 72.0,
      tablet: 80.0,
      desktop: 88.0,
    );
  }

  /// Get responsive dialog width
  static double getResponsiveDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return getResponsiveValue(
      context,
      mobile: screenWidth * 0.9,
      tablet: screenWidth * 0.7,
      desktop: screenWidth * 0.5,
    ).clamp(300.0, 600.0);
  }

  /// Get responsive bottom sheet height
  static double getResponsiveBottomSheetHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return getResponsiveValue(
      context,
      mobile: screenHeight * 0.6,
      tablet: screenHeight * 0.5,
      desktop: screenHeight * 0.4,
    );
  }

  /// Get responsive app bar height
  static double getResponsiveAppBarHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: kToolbarHeight,
      tablet: kToolbarHeight + 8,
      desktop: kToolbarHeight + 16,
    );
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(
    BuildContext context, {
    required double baseSpacing,
  }) {
    return getResponsiveValue(
      context,
      mobile: baseSpacing,
      tablet: baseSpacing * 1.25,
      desktop: baseSpacing * 1.5,
    );
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 8.0,
      tablet: 12.0,
      desktop: 16.0,
    );
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return getKeyboardHeight(context) > 0;
  }

  /// Get text scale factor
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.3);
  }

  /// Get responsive text style
  static TextStyle getResponsiveTextStyle(
    BuildContext context, {
    required TextStyle baseStyle,
  }) {
    final scaleFactor = getTextScaleFactor(context);
    final responsiveFontSize = getResponsiveFontSize(
      context,
      baseFontSize: baseStyle.fontSize ?? 14,
    );
    
    return baseStyle.copyWith(
      fontSize: responsiveFontSize * scaleFactor,
    );
  }

  /// Create responsive layout
  static Widget createResponsiveLayout({
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    return Builder(
      builder: (context) {
        return getResponsiveValue(
          context,
          mobile: mobile,
          tablet: tablet,
          desktop: desktop,
        );
      },
    );
  }

  /// Create responsive grid
  static Widget createResponsiveGrid({
    required List<Widget> children,
    double? spacing,
    double? runSpacing,
  }) {
    return Builder(
      builder: (context) {
        final columns = getResponsiveGridColumns(context);
        final responsiveSpacing = spacing ?? getResponsiveSpacing(context, baseSpacing: 16);
        
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: responsiveSpacing,
          mainAxisSpacing: runSpacing ?? responsiveSpacing,
          children: children,
        );
      },
    );
  }

  /// Create responsive wrap
  static Widget createResponsiveWrap({
    required List<Widget> children,
    double? spacing,
    double? runSpacing,
  }) {
    return Builder(
      builder: (context) {
        final responsiveSpacing = spacing ?? getResponsiveSpacing(context, baseSpacing: 8);
        
        return Wrap(
          spacing: responsiveSpacing,
          runSpacing: runSpacing ?? responsiveSpacing,
          children: children,
        );
      },
    );
  }

  /// Create responsive container
  static Widget createResponsiveContainer({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? borderRadius,
  }) {
    return Builder(
      builder: (context) {
        return Container(
          padding: padding ?? getResponsivePadding(context),
          margin: margin ?? getResponsiveMargin(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              borderRadius ?? getResponsiveBorderRadius(context),
            ),
          ),
          child: child,
        );
      },
    );
  }

  /// Create responsive card
  static Widget createResponsiveCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? elevation,
  }) {
    return Builder(
      builder: (context) {
        return Card(
          margin: margin ?? getResponsiveMargin(context),
          elevation: elevation ?? getResponsiveCardElevation(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              getResponsiveBorderRadius(context),
            ),
          ),
          child: Padding(
            padding: padding ?? getResponsivePadding(context),
            child: child,
          ),
        );
      },
    );
  }

  /// Create responsive list view
  static Widget createResponsiveListView({
    required List<Widget> children,
    EdgeInsets? padding,
    double? itemSpacing,
  }) {
    return Builder(
      builder: (context) {
        final responsivePadding = padding ?? getResponsivePadding(context);
        final spacing = itemSpacing ?? getResponsiveSpacing(context, baseSpacing: 8);
        
        return ListView.separated(
          padding: responsivePadding,
          itemCount: children.length,
          separatorBuilder: (context, index) => SizedBox(height: spacing),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  /// Get responsive constraints
  static BoxConstraints getResponsiveConstraints(BuildContext context) {
    return BoxConstraints(
      maxWidth: getResponsiveValue(
        context,
        mobile: double.infinity,
        tablet: 600,
        desktop: 800,
      ),
    );
  }
}

/// Device type enumeration
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Responsive widget that rebuilds based on screen size changes
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveUtils.getResponsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

/// Responsive builder widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    return builder(context, deviceType);
  }
}