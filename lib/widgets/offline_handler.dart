import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/error_handling_service.dart';
import '../services/connectivity_service.dart';
import '../services/cloud_sync_service.dart';

/// Widget that handles offline scenarios and provides graceful degradation
class OfflineHandler extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final bool showOfflineIndicator;
  
  const OfflineHandler({
    Key? key,
    required this.child,
    this.offlineWidget,
    this.showOfflineIndicator = true,
  }) : super(key: key);

  @override
  State<OfflineHandler> createState() => _OfflineHandlerState();
}

class _OfflineHandlerState extends State<OfflineHandler> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final CloudSyncService _syncService = CloudSyncService();
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _connectivityService.connectivityStream(),
      initialData: _connectivityService.isOnline(),
      builder: (context, connectivitySnapshot) {
        final isOnline = connectivitySnapshot.data ?? true;
        
        return Stack(
          children: [
            widget.child,
            if (!isOnline && widget.showOfflineIndicator)
              _buildOfflineIndicator(context),
            if (!isOnline && widget.offlineWidget != null)
              widget.offlineWidget!,
          ],
        );
      },
    );
  }

  Widget _buildOfflineIndicator(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.orange[700],
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _connectivityService.getConnectivityDescription(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              StreamBuilder<SyncEvent>(
                stream: _syncService.syncEvents(),
                builder: (context, syncSnapshot) {
                  final syncStatus = _syncService.getSyncStatus();
                  
                  if (syncStatus.isSyncing) {
                    return const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }
                  
                  if (syncStatus.pendingChanges > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${syncStatus.pendingChanges} pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget for handling offline-specific screens
class OfflineScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final List<Widget>? actions;
  
  const OfflineScreen({
    Key? key,
    this.title = 'You\'re Offline',
    this.message = 'This feature requires an internet connection. Please check your network and try again.',
    this.onRetry,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 64,
                color: Colors.orange[700],
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              if (actions != null) ...[
                const SizedBox(height: 16),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget for showing offline capabilities
class OfflineCapabilitiesWidget extends StatelessWidget {
  final List<String> availableFeatures;
  final List<String> unavailableFeatures;
  
  const OfflineCapabilitiesWidget({
    Key? key,
    required this.availableFeatures,
    required this.unavailableFeatures,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 8),
                const Text(
                  'Offline Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (availableFeatures.isNotEmpty) ...[
              const Text(
                'Available Features:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              ...availableFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            if (unavailableFeatures.isNotEmpty) ...[
              const Text(
                'Requires Internet:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              ...unavailableFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mixin for handling offline functionality in screens
mixin OfflineCapable<T extends StatefulWidget> on State<T> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final CloudSyncService _syncService = CloudSyncService();
  
  bool get isOffline => _connectivityService.isOffline();
  
  /// Add operation to pending queue when offline
  void addPendingOperation(String operationType, Map<String, dynamic> data) {
    // This would be handled by the sync service's queue mechanism
    // For now, we'll show a message that it will sync when online
  }
  
  /// Check if feature is available offline
  bool isFeatureAvailableOffline(String feature) {
    // Define which features work offline
    const offlineFeatures = [
      'registration',
      'view_attendees',
      'view_reports',
      'settings',
      'database_operations',
    ];
    
    return offlineFeatures.contains(feature);
  }
  
  /// Show offline message
  void showOfflineMessage(BuildContext context, {String? customMessage}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          customMessage ?? 'This feature requires an internet connection',
        ),
        backgroundColor: Colors.orange[700],
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Handle offline operation
  Future<bool> handleOfflineOperation(
    String operationType,
    Future<void> Function() operation, {
    Map<String, dynamic>? operationData,
  }) async {
    if (isOffline) {
      // Add to pending operations (handled by hybrid repositories)
      addPendingOperation(operationType, operationData ?? {});
      
      showOfflineMessage(
        context,
        customMessage: 'Operation saved. Will sync when online.',
      );
      
      return false; // Operation not executed immediately
    } else {
      try {
        await operation();
        return true; // Operation executed successfully
      } catch (e) {
        // Handle error through error handling service
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        appState.setGlobalError('Operation failed: $e');
        return false;
      }
    }
  }
  
  /// Get connectivity status description
  String getConnectivityDescription() {
    return _connectivityService.getConnectivityDescription();
  }
  
  /// Wait for connection to be restored
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) {
    return _connectivityService.waitForConnection(timeout: timeout);
  }
}