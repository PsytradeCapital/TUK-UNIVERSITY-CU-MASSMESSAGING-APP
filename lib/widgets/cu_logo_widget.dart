import 'package:flutter/material.dart';

/// Widget to display the TUK CU logo
class CULogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final bool useDarkVersion;
  final bool showText;

  const CULogoWidget({
    Key? key,
    this.width,
    this.height,
    this.useDarkVersion = false,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = (useDarkVersion || isDarkMode)
        ? 'assets/cu_logo_new_dark.png'
        : 'assets/cu_logo_new_light.png';

    return Image.asset(
      logoAsset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback if logo fails to load
        return Icon(
          Icons.church,
          size: height ?? 100,
          color: Theme.of(context).primaryColor,
        );
      },
    );
  }
}

/// Branded header with CU logo and title
class CUBrandedHeader extends StatelessWidget {
  final String? title;
  final double logoHeight;
  final bool showMotto;

  const CUBrandedHeader({
    Key? key,
    this.title,
    this.logoHeight = 120,
    this.showMotto = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CULogoWidget(
          height: logoHeight,
        ),
        if (showMotto) ...[
          const SizedBox(height: 8),
          Text(
            'Raising to Serve',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
        if (title != null) ...[
          const SizedBox(height: 16),
          Text(
            title!,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
