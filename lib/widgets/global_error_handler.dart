import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

/// Global error handler widget that displays errors and provides recovery options
class GlobalErrorHandler extends StatelessWidget {
  final Widget child;
  
  const GlobalErrorHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Stack(
          children: [
            this.child,
            if (appState.globalError != null)
              _buildErrorOverlay(context, appState),
          ],
        );
      },
    );
  }

  Widget _buildErrorOverlay(BuildContext context, AppStateProvider appState) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.globalError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          appState.clearGlobalError();
                        },
                        child: const Text('Dismiss'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          appState.clearGlobalError();
                          // Could add retry logic here
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen-level error handler widget
class ScreenErrorHandler extends StatelessWidget {
  final String screenName;
  final Widget child;
  final VoidCallback? onRetry;
  
  const ScreenErrorHandler({
    Key? key,
    required this.screenName,
    required this.child,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final screenError = appState.getScreenError(screenName);
        
        if (screenError != null) {
          return _buildErrorScreen(context, appState, screenError);
        }
        
        return this.child;
      },
    );
  }

  Widget _buildErrorScreen(BuildContext context, AppStateProvider appState, String error) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$screenName Error'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error occurred',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      appState.clearScreenError(screenName);
                    },
                    child: const Text('Dismiss'),
                  ),
                  if (onRetry != null)
                    ElevatedButton(
                      onPressed: () {
                        appState.clearScreenError(screenName);
                        onRetry!();
                      },
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading overlay widget
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final String? loadingText;
  
  const LoadingOverlay({
    Key? key,
    required this.child,
    this.loadingText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Stack(
          children: [
            this.child,
            if (appState.isGlobalLoading)
              _buildLoadingOverlay(context),
          ],
        );
      },
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (loadingText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      loadingText!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen loading indicator widget
class ScreenLoadingIndicator extends StatelessWidget {
  final String screenName;
  final Widget child;
  final String? loadingText;
  
  const ScreenLoadingIndicator({
    Key? key,
    required this.screenName,
    required this.child,
    this.loadingText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (appState.isScreenLoading(screenName)) {
          return Scaffold(
            appBar: AppBar(
              title: Text(screenName),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (loadingText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      loadingText!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        
        return this.child;
      },
    );
  }
}

/// Error boundary widget for catching and handling widget errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? context;
  
  const ErrorBoundary({
    Key? key,
    required this.child,
    this.context,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = details.exception.toString();
        });
        
        // Report to app state provider
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        appState.handleUnhandledException(details.exception, details.stack);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Widget Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.context != null)
                  Text(
                    'Context: ${widget.context}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error occurred',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}