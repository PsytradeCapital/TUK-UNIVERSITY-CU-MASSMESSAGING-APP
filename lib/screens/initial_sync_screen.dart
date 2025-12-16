import 'package:flutter/material.dart';
import '../services/initial_sync_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cu_logo_widget.dart';

/// Screen shown during initial data synchronization
/// Requirements 2.2, 4.3 - Show loading screen during sync and handle sync errors
class InitialSyncScreen extends StatefulWidget {
  final VoidCallback onSyncComplete;
  final VoidCallback? onSyncFailed;

  const InitialSyncScreen({
    Key? key,
    required this.onSyncComplete,
    this.onSyncFailed,
  }) : super(key: key);

  @override
  State<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends State<InitialSyncScreen>
    with SingleTickerProviderStateMixin {
  final InitialSyncService _initialSyncService = InitialSyncService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _currentStatus = 'Preparing to sync...';
  double _progress = 0.0;
  bool _isRetrying = false;
  String? _errorMessage;
  bool _canRetry = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _startInitialSync();
    _trackScreenView();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _trackScreenView() async {
    await _analyticsService.trackScreenView(
      screenName: 'Initial Sync',
      screenClass: 'InitialSyncScreen',
    );
  }

  Future<void> _startInitialSync() async {
    setState(() {
      _currentStatus = 'Starting synchronization...';
      _progress = 0.0;
      _errorMessage = null;
      _canRetry = false;
    });

    try {
      final result = await _initialSyncService.performInitialSync(
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
            });
          }
        },
        onProgressUpdate: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        if (result.success) {
          setState(() {
            _currentStatus = 'Sync completed successfully!';
            _progress = 1.0;
          });
          
          // Wait a moment to show completion, then navigate
          await Future.delayed(const Duration(seconds: 1));
          widget.onSyncComplete();
        } else {
          _handleSyncError(result);
        }
      }
    } catch (e) {
      if (mounted) {
        _handleSyncError(InitialSyncResult(
          success: false,
          error: e.toString(),
          canRetry: true,
        ));
      }
    }
  }

  void _handleSyncError(InitialSyncResult result) {
    setState(() {
      _errorMessage = result.error;
      _canRetry = result.canRetry && _retryCount < _maxRetries;
      
      if (result.offlineMode) {
        _currentStatus = 'Working offline - sync will resume when connected';
      } else {
        _currentStatus = 'Sync failed';
      }
    });

    if (result.offlineMode) {
      // In offline mode, allow user to continue after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          widget.onSyncComplete();
        }
      });
    }
  }

  Future<void> _retrySync() async {
    if (_retryCount >= _maxRetries) {
      _showMaxRetriesDialog();
      return;
    }

    setState(() {
      _isRetrying = true;
      _retryCount++;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isRetrying = false;
    });

    await _startInitialSync();
  }

  void _showMaxRetriesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sync Failed'),
        content: const Text(
          'Unable to sync data after multiple attempts. You can continue using the app offline, or check your internet connection and restart the app.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSyncComplete(); // Continue offline
            },
            child: const Text('Continue Offline'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSyncFailed?.call();
            },
            child: const Text('Restart App'),
          ),
        ],
      ),
    );
  }

  void _skipSync() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Sync?'),
        content: const Text(
          'Are you sure you want to skip the initial sync? You may not have the latest data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSyncComplete();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Logo with animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: const CULogoWidget(
                  size: 120,
                  showText: false,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // App title
              const Text(
                'TUK CU Mass Messaging',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Raising to Serve',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Status text
                    Text(
                      _currentStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Progress percentage
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Error message and retry button
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_canRetry)
                      ElevatedButton.icon(
                        onPressed: _isRetrying ? null : _retrySync,
                        icon: _isRetrying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    
                    TextButton(
                      onPressed: _skipSync,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
              
              const Spacer(),
              
              // Retry count indicator
              if (_retryCount > 0)
                Text(
                  'Attempt ${_retryCount + 1} of ${_maxRetries + 1}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Tip text
              const Text(
                'Syncing your data for the best experience...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}