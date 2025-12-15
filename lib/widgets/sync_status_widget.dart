import 'package:flutter/material.dart';
import '../services/cloud_sync_service.dart';
import '../services/connectivity_service.dart';

/// Widget that displays sync status and connectivity information
class SyncStatusWidget extends StatefulWidget {
  final bool showDetails;
  final bool showLastSyncTime;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  
  const SyncStatusWidget({
    Key? key,
    this.showDetails = true,
    this.showLastSyncTime = true,
    this.padding,
    this.backgroundColor,
  }) : super(key: key);

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final CloudSyncService _syncService = CloudSyncService();
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _connectivityService.connectivityStream(),
      initialData: _connectivityService.isOnline(),
      builder: (context, connectivitySnapshot) {
        return StreamBuilder<SyncEvent>(
          stream: _syncService.syncEvents(),
          builder: (context, syncSnapshot) {
            final isOnline = connectivitySnapshot.data ?? true;
            final syncStatus = _syncService.getSyncStatus();
            final connectivityStatus = _connectivityService.getConnectivityStatus();
            
            return Container(
              padding: widget.padding ?? const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? _getStatusColor(isOnline, syncStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(isOnline, syncStatus).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildStatusIcon(isOnline, syncStatus),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getStatusText(isOnline, syncStatus, connectivityStatus),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(isOnline, syncStatus),
                          ),
                        ),
                      ),
                      if (syncStatus.isSyncing)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getStatusColor(isOnline, syncStatus),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.showDetails) ...[
                    const SizedBox(height: 8),
                    _buildDetailsSection(isOnline, syncStatus, connectivityStatus),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusIcon(bool isOnline, SyncStatus syncStatus) {
    if (syncStatus.isSyncing) {
      return Icon(
        Icons.sync,
        size: 16,
        color: _getStatusColor(isOnline, syncStatus),
      );
    }
    
    if (!isOnline) {
      return Icon(
        Icons.wifi_off,
        size: 16,
        color: _getStatusColor(isOnline, syncStatus),
      );
    }
    
    if (syncStatus.pendingChanges > 0) {
      return Icon(
        Icons.cloud_upload,
        size: 16,
        color: _getStatusColor(isOnline, syncStatus),
      );
    }
    
    return Icon(
      Icons.cloud_done,
      size: 16,
      color: _getStatusColor(isOnline, syncStatus),
    );
  }

  Widget _buildDetailsSection(bool isOnline, SyncStatus syncStatus, ConnectivityStatus connectivityStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (syncStatus.pendingChanges > 0)
          Text(
            '${syncStatus.pendingChanges} changes pending sync',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        if (widget.showLastSyncTime && syncStatus.lastSyncAt != null)
          Text(
            'Last sync: ${_formatLastSyncTime(syncStatus.lastSyncAt!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        if (!isOnline)
          Text(
            connectivityStatus.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(bool isOnline, SyncStatus syncStatus) {
    if (syncStatus.isSyncing) {
      return Colors.blue;
    }
    
    if (!isOnline) {
      return Colors.orange;
    }
    
    if (syncStatus.pendingChanges > 0) {
      return Colors.amber;
    }
    
    return Colors.green;
  }

  String _getStatusText(bool isOnline, SyncStatus syncStatus, ConnectivityStatus connectivityStatus) {
    if (syncStatus.isSyncing) {
      return 'Syncing...';
    }
    
    if (!isOnline) {
      return 'Offline';
    }
    
    if (syncStatus.pendingChanges > 0) {
      return 'Sync pending';
    }
    
    return 'Synced';
  }

  String _formatLastSyncTime(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Compact sync status indicator for app bars
class SyncStatusIndicator extends StatelessWidget {
  final VoidCallback? onTap;
  
  const SyncStatusIndicator({
    Key? key,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CloudSyncService syncService = CloudSyncService();
    final ConnectivityService connectivityService = ConnectivityService();
    
    return StreamBuilder<bool>(
      stream: connectivityService.connectivityStream(),
      initialData: connectivityService.isOnline(),
      builder: (context, connectivitySnapshot) {
        return StreamBuilder<SyncEvent>(
          stream: syncService.syncEvents(),
          builder: (context, syncSnapshot) {
            final isOnline = connectivitySnapshot.data ?? true;
            final syncStatus = syncService.getSyncStatus();
            
            return GestureDetector(
              onTap: onTap ?? () => _showSyncStatusDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(isOnline, syncStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(isOnline, syncStatus).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (syncStatus.isSyncing)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(isOnline, syncStatus),
                          ),
                        ),
                      )
                    else
                      Icon(
                        _getStatusIcon(isOnline, syncStatus),
                        size: 12,
                        color: _getStatusColor(isOnline, syncStatus),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _getCompactStatusText(isOnline, syncStatus),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(isOnline, syncStatus),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getStatusIcon(bool isOnline, SyncStatus syncStatus) {
    if (!isOnline) return Icons.wifi_off;
    if (syncStatus.pendingChanges > 0) return Icons.cloud_upload;
    return Icons.cloud_done;
  }

  Color _getStatusColor(bool isOnline, SyncStatus syncStatus) {
    if (syncStatus.isSyncing) return Colors.blue;
    if (!isOnline) return Colors.orange;
    if (syncStatus.pendingChanges > 0) return Colors.amber;
    return Colors.green;
  }

  String _getCompactStatusText(bool isOnline, SyncStatus syncStatus) {
    if (syncStatus.isSyncing) return 'Sync';
    if (!isOnline) return 'Offline';
    if (syncStatus.pendingChanges > 0) return '${syncStatus.pendingChanges}';
    return 'OK';
  }

  void _showSyncStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: const SyncStatusWidget(
          showDetails: true,
          showLastSyncTime: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final syncService = CloudSyncService();
              try {
                await syncService.syncFromCloud();
                await syncService.syncToCloud();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sync failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }
}

/// Widget for manual sync trigger
class ManualSyncButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool showLabel;
  
  const ManualSyncButton({
    Key? key,
    this.label,
    this.icon,
    this.showLabel = true,
  }) : super(key: key);

  @override
  State<ManualSyncButton> createState() => _ManualSyncButtonState();
}

class _ManualSyncButtonState extends State<ManualSyncButton> {
  final CloudSyncService _syncService = CloudSyncService();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncEvent>(
      stream: _syncService.syncEvents(),
      builder: (context, snapshot) {
        final syncStatus = _syncService.getSyncStatus();
        final isOnline = _connectivityService.isOnline();
        
        return ElevatedButton.icon(
          onPressed: (isOnline && !syncStatus.isSyncing) ? _performSync : null,
          icon: syncStatus.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(widget.icon ?? Icons.sync),
          label: widget.showLabel
              ? Text(widget.label ?? (syncStatus.isSyncing ? 'Syncing...' : 'Sync Now'))
              : const SizedBox.shrink(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isOnline ? null : Colors.grey,
          ),
        );
      },
    );
  }

  Future<void> _performSync() async {
    if (!_connectivityService.isOnline()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sync while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      // Perform bidirectional sync
      await _syncService.syncFromCloud();
      await _syncService.syncToCloud();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}