import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_log_model.dart';
import '../models/attendee_model.dart';
import '../repositories/firebase_message_log_repository.dart';
import '../repositories/hybrid_attendee_repository.dart';
import '../services/auth_service.dart';
import '../services/real_time_sync_service.dart';
import '../widgets/cu_logo_widget.dart';
import '../widgets/sync_status_widget.dart';

class MessageHistoryScreen extends StatefulWidget {
  final int? serviceId;

  const MessageHistoryScreen({
    Key? key,
    this.serviceId,
  }) : super(key: key);

  @override
  State<MessageHistoryScreen> createState() => _MessageHistoryScreenState();
}

class _MessageHistoryScreenState extends State<MessageHistoryScreen> {
  final _messageLogRepository = FirebaseMessageLogRepository();
  final _attendeeRepository = HybridAttendeeRepository();
  final _authService = AuthService();
  final _realTimeSyncService = RealTimeSyncService();
  
  List<MessageLogModel> _messages = [];
  Map<int, AttendeeModel> _attendeeCache = {};
  Map<String, String> _userCache = {}; // userId -> userName
  bool _isLoading = false;
  String? _error;
  
  MessageStatus? _filterStatus;
  
  StreamSubscription<List<MessageLogModel>>? _messageStreamSubscription;
  bool _hasNewMessages = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeUpdates() {
    try {
      // Listen to real-time message log updates from the sync service
      _realTimeSyncService.messageLogUpdatesStream.listen(
        (updatedMessageLogs) {
          if (mounted) {
            // Filter messages by service if specified
            final filteredMessages = widget.serviceId != null
                ? updatedMessageLogs.where((m) => m.serviceId == widget.serviceId).toList()
                : updatedMessageLogs;

            setState(() {
              _messages = filteredMessages;
              _hasNewMessages = true;
            });
            
            _loadUserAndAttendeeDetails();
            
            // Auto-hide the new messages indicator after 5 seconds
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _hasNewMessages = false;
                });
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Real-time message log updates error: $error');
        },
      );

      // Also listen to direct Firestore streams as backup
      if (widget.serviceId != null) {
        _messageStreamSubscription = _messageLogRepository
            .messageLogsByServiceStream(widget.serviceId!)
            .listen(
          (messages) {
            if (mounted) {
              setState(() {
                _messages = messages;
              });
              _loadUserAndAttendeeDetails();
            }
          },
          onError: (error) {
            debugPrint('Direct Firestore message updates error: $error');
          },
        );
      } else {
        _messageStreamSubscription = _messageLogRepository
            .messageLogsStream()
            .listen(
          (messages) {
            if (mounted) {
              setState(() {
                _messages = messages;
              });
              _loadUserAndAttendeeDetails();
            }
          },
          onError: (error) {
            debugPrint('Direct Firestore message updates error: $error');
          },
        );
      }

      // Start the real-time sync service
      _realTimeSyncService.startListening().catchError((error) {
        debugPrint('Failed to start real-time sync: $error');
      });
    } catch (e) {
      debugPrint('Failed to setup real-time message updates: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<MessageLogModel> messages;
      
      if (widget.serviceId != null) {
        messages = await _messageLogRepository.getMessageLogsByService(widget.serviceId!);
      } else {
        messages = await _messageLogRepository.getAllMessageLogs();
      }

      setState(() {
        _messages = messages;
      });

      await _loadUserAndAttendeeDetails();
    } catch (e) {
      setState(() {
        _error = 'Failed to load messages: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserAndAttendeeDetails() async {
    // Load attendee details
    final attendeeIds = _messages.map((m) => m.attendeeId).toSet();
    for (final id in attendeeIds) {
      if (!_attendeeCache.containsKey(id)) {
        try {
          final attendee = await _attendeeRepository.getAttendeeById(id.toString());
          if (attendee != null) {
            _attendeeCache[id] = attendee;
          }
        } catch (e) {
          debugPrint('Error loading attendee $id: $e');
        }
      }
    }

    // Load user details for sentBy field
    final userIds = _messages
        .where((m) => m.sentBy != null)
        .map((m) => m.sentBy!)
        .toSet();
    
    for (final userId in userIds) {
      if (!_userCache.containsKey(userId)) {
        try {
          // For now, we'll use a placeholder. In a full implementation,
          // you'd have a UserRepository to get user details
          _userCache[userId] = 'User $userId';
        } catch (e) {
          debugPrint('Error loading user $userId: $e');
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  List<MessageLogModel> get _filteredMessages {
    if (_filterStatus == null) return _messages;
    return _messages.where((m) => m.sendStatus == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CULogoWidget(height: 40, useDarkVersion: true),
            SizedBox(width: 12),
            Text('Message History'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Sync status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SyncStatusIndicator(
              onTap: () => _showSyncStatusDialog(context),
            ),
          ),
          IconButton(
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          _buildStatusSummary(),
          _buildRealTimeIndicator(),
          Expanded(
            child: _buildMessageList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _filterStatus == null,
              onSelected: (selected) {
                setState(() => _filterStatus = null);
              },
            ),
            const SizedBox(width: 8),
            ...MessageStatus.values.map((status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_getStatusIcon(status)),
                    const SizedBox(width: 4),
                    Text(_getStatusText(status)),
                  ],
                ),
                selected: _filterStatus == status,
                onSelected: (selected) {
                  setState(() => _filterStatus = selected ? status : null);
                },
                selectedColor: _getStatusColor(status).withOpacity(0.2),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary() {
    final total = _messages.length;
    final sent = _messages.where((m) => m.sendStatus == MessageStatus.sent).length;
    final delivered = _messages.where((m) => m.sendStatus == MessageStatus.delivered).length;
    final failed = _messages.where((m) => m.sendStatus == MessageStatus.failed).length;
    final pending = _messages.where((m) => m.sendStatus == MessageStatus.pending).length;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Total', total, Colors.blue),
            _buildSummaryItem('Sent', sent, Colors.orange),
            _buildSummaryItem('Delivered', delivered, Colors.green),
            _buildSummaryItem('Failed', failed, Colors.red),
            if (pending > 0)
              _buildSummaryItem('Pending', pending, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _filterStatus == null
                  ? 'No messages found'
                  : 'No ${_getStatusText(_filterStatus!).toLowerCase()} messages',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredMessages.length,
      itemBuilder: (context, index) {
        final message = _filteredMessages[index];
        final attendee = _attendeeCache[message.attendeeId];
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(message.sendStatus).withOpacity(0.2),
              child: Text(
                _getStatusIcon(message.sendStatus),
                style: TextStyle(
                  color: _getStatusColor(message.sendStatus),
                ),
              ),
            ),
            title: Text(
              attendee?.name ?? 'Unknown Attendee',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.messageText.length > 50
                      ? '${message.messageText.substring(0, 50)}...'
                      : message.messageText,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _getStatusText(message.sendStatus),
                      style: TextStyle(
                        color: _getStatusColor(message.sendStatus),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    if (message.sentAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.sentAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                // Show who sent the message
                if (message.sentBy != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sent by: ${_userCache[message.sentBy] ?? message.sentBy}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
                if (message.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Icon(
              _getStatusIconData(message.sendStatus),
              color: _getStatusColor(message.sendStatus),
            ),
            onTap: () => _showMessageDetails(message, attendee),
          ),
        );
      },
    );
  }

  void _showMessageDetails(MessageLogModel message, AttendeeModel? attendee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Recipient', attendee?.name ?? 'Unknown'),
              if (attendee != null)
                _buildDetailRow('Phone', attendee.phoneNumber),
              _buildDetailRow('Status', _getStatusText(message.sendStatus)),
              if (message.sentBy != null)
                _buildDetailRow('Sent By', _userCache[message.sentBy] ?? message.sentBy!),
              if (message.sentAt != null)
                _buildDetailRow('Sent At', _formatDateTime(message.sentAt!)),
              if (message.errorMessage != null)
                _buildDetailRow('Error', message.errorMessage!),
              const SizedBox(height: 12),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(message.messageText),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return '⏳';
      case MessageStatus.sending:
        return '📤';
      case MessageStatus.sent:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.failed:
        return '✗';
      case MessageStatus.cancelled:
        return '⊘';
    }
  }

  IconData _getStatusIconData(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return Icons.schedule;
      case MessageStatus.sending:
        return Icons.send;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
      case MessageStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusText(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return 'Pending';
      case MessageStatus.sending:
        return 'Sending';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.failed:
        return 'Failed';
      case MessageStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return Colors.orange;
      case MessageStatus.sending:
        return Colors.blue;
      case MessageStatus.sent:
        return Colors.lightGreen;
      case MessageStatus.delivered:
        return Colors.green;
      case MessageStatus.failed:
        return Colors.red;
      case MessageStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  Widget _buildRealTimeIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _hasNewMessages ? Colors.green[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hasNewMessages ? Colors.green[200]! : Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasNewMessages ? Icons.fiber_new : Icons.update,
            size: 16,
            color: _hasNewMessages ? Colors.green[700] : Colors.blue[700],
          ),
          const SizedBox(width: 4),
          Text(
            _hasNewMessages 
                ? 'New messages received!'
                : _realTimeSyncService.isListening
                    ? 'Real-time updates enabled'
                    : 'Real-time updates disabled',
            style: TextStyle(
              fontSize: 12,
              color: _hasNewMessages ? Colors.green[700] : Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_hasNewMessages) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
        ],
      ),
    );
  }
}
