import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import '../services/sms_manager.dart';
import '../services/notification_service.dart';
import '../repositories/hybrid_message_log_repository.dart';
import '../repositories/hybrid_attendee_repository.dart';
import '../providers/service_session_provider.dart';
import '../widgets/cu_logo_widget.dart';
import '../widgets/message_filter_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets/offline_handler.dart';
import 'message_history_screen.dart';

class MessagingScreen extends StatefulWidget {
  final List<AttendeeModel> attendees;
  final int serviceId;

  const MessagingScreen({
    Key? key,
    required this.attendees,
    required this.serviceId,
  }) : super(key: key);

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> with OfflineCapable {
  final _messageController = TextEditingController();
  final _smsManager = SMSManager();
  final _messageLogRepository = HybridMessageLogRepository();
  final _notificationService = NotificationService();
  final _attendeeRepository = HybridAttendeeRepository();
  
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  SMSProgress? _currentProgress;
  
  // Message composition state
  int _characterCount = 0;
  final int _maxCharacters = 1600; // SMS limit
  bool _showPreview = false;
  String _previewMessage = '';
  
  // Filter state
  MessageFilters? _activeFilters;
  List<AttendeeModel> _filteredAttendees = [];
  bool _isLoadingFilters = false;
  
  // Available filter options
  List<String> _availableYears = [];
  List<String> _availableLocations = [];

  @override
  void initState() {
    super.initState();
    _filteredAttendees = widget.attendees;
    _messageController.addListener(_updateCharacterCount);
    _loadFilterOptions();
    
    // Listen to SMS progress updates
    _smsManager.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
          _isSending = progress.isSending;
        });
      }
    });
    
    // Listen to notifications
    _notificationService.addListener(_handleNotification);
    
    // Listen to real-time attendee updates when online
    _setupRealTimeUpdates();
  }

  void _setupRealTimeUpdates() {
    try {
      // Listen to attendee changes from cloud
      _attendeeRepository.attendeesStream().listen(
        (updatedAttendees) {
          if (mounted) {
            setState(() {
              // Update the filtered attendees with real-time data
              final sessionAttendeeIds = widget.attendees.map((a) => a.id).toSet();
              _filteredAttendees = updatedAttendees
                  .where((a) => sessionAttendeeIds.contains(a.id))
                  .toList();
            });
          }
        },
        onError: (error) {
          debugPrint('Real-time attendee updates error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to setup real-time updates: $e');
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_updateCharacterCount);
    _messageController.dispose();
    _notificationService.removeListener(_handleNotification);
    super.dispose();
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _messageController.text.length;
    });
  }

  Future<void> _loadFilterOptions() async {
    try {
      // Use all possible years (1st through 8th for extended programs)
      final allYears = [
        '1st Year', 
        '2nd Year', 
        '3rd Year', 
        '4th Year', 
        '5th Year', 
        '6th Year',
        '7th Year',
        '8th Year',
      ];
      
      // Get all unique locations from database (including custom "Other" locations)
      final dbLocations = await _attendeeRepository.getUniqueLocations();
      
      // Combine predefined locations with database locations
      final predefinedLocations = [
        'Kitengela',
        'Athi River',
        'Sukari',
        'Mlolongo',
        'Syokimau',
        'Juja',
        'Kaloleni',
        'Rongai',
        'Thika',
        'Githurai',
        'Makongeni',
        'Ngara',
        'Langata',
        'Mlango',
        'South B',
        'Upper Hill',
        'South C',
        'Landi Mawe',
        'Pipeline',
        'Shauri Moyo',
        'Embakasi',
        'Kasarani',
        'Ruiru',
        'Kahawa',
        'Zimmerman',
        'Other',
      ];
      
      // Merge and deduplicate locations
      final allLocationsSet = <String>{...predefinedLocations, ...dbLocations};
      final allLocations = allLocationsSet.toList()..sort();
      
      if (mounted) {
        setState(() {
          _availableYears = allYears;
          _availableLocations = allLocations;
        });
      }
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  Future<void> _applyFilters(MessageFilters filters) async {
    setState(() {
      _activeFilters = filters;
      _isLoadingFilters = true;
    });

    try {
      if (!filters.hasFilters) {
        // No filters - use all attendees
        setState(() {
          _filteredAttendees = widget.attendees;
          _isLoadingFilters = false;
        });
        return;
      }

      // Apply filters using repository
      final filtered = await _attendeeRepository.getAttendeesWithFilters(
        years: filters.years,
        locations: filters.locations,
        categories: filters.categories,
      );

      // Only include attendees that are in the current service session
      final sessionAttendeeIds = widget.attendees.map((a) => a.id).toSet();
      final filteredInSession = filtered
          .where((a) => sessionAttendeeIds.contains(a.id))
          .toList();

      if (mounted) {
        setState(() {
          _filteredAttendees = filteredInSession;
          _isLoadingFilters = false;
        });
      }
    } catch (e) {
      debugPrint('Error applying filters: $e');
      setState(() {
        _isLoadingFilters = false;
      });
      _notificationService.showErrorNotification(
        'Filter Error',
        'Failed to apply filters: $e',
      );
    }
  }

  void _handleNotification(NotificationMessage notification) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(notification.message),
            ],
          ),
          backgroundColor: NotificationService.getNotificationColor(notification.type),
          duration: notification.duration,
          action: notification.action != null && notification.actionLabel != null
              ? SnackBarAction(
                  label: notification.actionLabel!,
                  onPressed: notification.action!,
                )
              : null,
        ),
      );
    }
  }

  void _generatePreview() {
    if (widget.attendees.isEmpty) {
      setState(() {
        _previewMessage = _messageController.text;
      });
      return;
    }

    // Use first attendee for preview
    final firstAttendee = widget.attendees.first;
    setState(() {
      _previewMessage = _smsManager.personalizeMessage(_messageController.text, firstAttendee.name);
    });
  }

  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
      if (_showPreview) {
        _generatePreview();
      }
    });
  }

  Future<void> _sendMessages() async {
    if (_messageController.text.trim().isEmpty) {
      _notificationService.showErrorNotification(
        'Message Required',
        'Please enter a message before sending.',
      );
      return;
    }

    if (_filteredAttendees.isEmpty) {
      _notificationService.showErrorNotification(
        'No Recipients',
        _activeFilters?.hasFilters ?? false
            ? 'No attendees match the selected filters.'
            : 'No attendees found for this service session.',
      );
      return;
    }

    if (widget.serviceId == 0) {
      _notificationService.showErrorNotification(
        'No Active Service',
        'Please start a new service session first.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Handle offline messaging
    final success = await handleOfflineOperation(
      'messaging',
      () async {
        await _smsManager.sendBulkSMS(
          _filteredAttendees,
          _messageController.text,
          onMessageSent: (messageLog) async {
            // Save successful message log
            await _messageLogRepository.createMessageLog(
              messageLog.copyWith(serviceId: widget.serviceId),
            );
          },
          onMessageFailed: (messageLog) async {
            // Save failed message log
            await _messageLogRepository.createMessageLog(
              messageLog.copyWith(serviceId: widget.serviceId),
            );
          },
        );

        // Mark messages as sent in the service session
        if (mounted) {
          final sessionProvider = Provider.of<ServiceSessionProvider>(context, listen: false);
          await sessionProvider.markMessagesSent(_messageController.text);
        }
      },
      operationData: {
        'message': _messageController.text,
        'recipientCount': _filteredAttendees.length,
        'serviceId': widget.serviceId,
      },
    );

    if (!success) {
      setState(() {
        _errorMessage = isOffline 
            ? 'Messages queued for sending when online'
            : 'Failed to send messages';
      });
      
      if (isOffline) {
        _notificationService.showErrorNotification(
          'Offline Mode',
          'Messages will be sent when connection is restored.',
        );
      } else {
        _notificationService.showErrorNotification(
          'Sending Failed',
          'Failed to send messages. Please try again.',
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _resumeSending() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _smsManager.resumeSending(
        onMessageSent: (messageLog) async {
          await _messageLogRepository.createMessageLog(
            messageLog.copyWith(serviceId: widget.serviceId),
          );
        },
        onMessageFailed: (messageLog) async {
          await _messageLogRepository.createMessageLog(
            messageLog.copyWith(serviceId: widget.serviceId),
          );
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _notificationService.showErrorNotification(
        'Resume Failed',
        _smsManager.getUserFriendlyErrorMessage(e.toString()),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _pauseSending() {
    _smsManager.pauseSending();
  }

  void _cancelSending() {
    _smsManager.cancelSending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CULogoWidget(height: 48, useDarkVersion: true),
            SizedBox(width: 12),
            Text('Send Messages'),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        toolbarHeight: 70,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Message History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MessageHistoryScreen(
                    serviceId: widget.serviceId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: widget.attendees.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter section
                  if (_availableYears.isNotEmpty || _availableLocations.isNotEmpty)
                    MessageFilterWidget(
                      onFiltersChanged: _applyFilters,
                      availableYears: _availableYears,
                      availableLocations: _availableLocations,
                    ),
                  
                  if (_availableYears.isNotEmpty || _availableLocations.isNotEmpty)
                    const SizedBox(height: 16),
                  
                  // Sync Status section
                  _buildSyncStatusSection(),
                  const SizedBox(height: 16),
                  
                  // Recipients section
                  _buildRecipientsSection(),
                  const SizedBox(height: 16),
                  
                  // Message composition section
                  _buildMessageCompositionSection(),
                  const SizedBox(height: 16),
                  
                  // Progress section (shown when sending)
                  if (_currentProgress != null && _currentProgress!.totalMessages > 0)
                    _buildProgressSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Send controls section
                  _buildSendControlsSection(),
                  
                  const SizedBox(height: 32), // Extra padding at bottom
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Attendees Registered',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Register attendees in the Registration tab first, then return here to send messages.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Show a message to guide user to registration tab
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please go to the Registration tab to add attendees first.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Need to Register Attendees'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsSection() {
    final recipientCount = _filteredAttendees.length;
    final totalCount = widget.attendees.length;
    final hasFilters = _activeFilters?.hasFilters ?? false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Recipients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingFilters)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Recipient count with filter info
            if (hasFilters) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Filtered: $recipientCount of $totalCount attendees',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeFilters.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                '$recipientCount attendees will receive this message',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Show first few attendees
            if (_filteredAttendees.isNotEmpty) ...[
              const Divider(),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: _filteredAttendees.length,
                  itemBuilder: (context, index) {
                    final attendee = _filteredAttendees[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(
                          attendee.name.isNotEmpty ? attendee.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(attendee.name),
                      subtitle: Text(
                        '${attendee.categoryDisplayName} • ${attendee.yearOfStudy.isNotEmpty ? attendee.yearOfStudy : attendee.location}',
                      ),
                      trailing: Text(
                        '${attendee.attendanceCount} visits',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ] else if (hasFilters) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.filter_alt_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No attendees match the selected filters',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCompositionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.message, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Message',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _togglePreview,
                  icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
                  label: Text(_showPreview ? 'Hide Preview' : 'Preview'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Message input
            TextField(
              controller: _messageController,
              maxLines: 6,
              maxLength: _maxCharacters,
              decoration: InputDecoration(
                hintText: 'Enter your message here...\n\nTip: Use {name} to personalize messages',
                border: const OutlineInputBorder(),
                counterText: '$_characterCount/$_maxCharacters characters',
                counterStyle: TextStyle(
                  color: _characterCount > _maxCharacters * 0.9 
                      ? Colors.red 
                      : Colors.grey,
                ),
              ),
              onChanged: (value) {
                if (_showPreview) {
                  _generatePreview();
                }
              },
            ),
            
            // Preview section
            if (_showPreview) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Preview (with first attendee\'s name):',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _previewMessage.isEmpty ? 'Enter a message to see preview' : _previewMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final progress = _currentProgress!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.send, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Sending Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.hasErrors ? Colors.orange : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            
            // Progress stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent: ${progress.sentMessages}/${progress.totalMessages}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (progress.failedMessages > 0)
                  Text(
                    'Failed: ${progress.failedMessages}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
            
            // Current recipient
            if (progress.currentRecipient != null) ...[
              const SizedBox(height: 8),
              Text(
                'Sending to: ${progress.currentRecipient}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Error message
            if (progress.lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _smsManager.getUserFriendlyErrorMessage(progress.lastError!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSendControlsSection() {
    final progress = _currentProgress;
    final canSend = !_isLoading && 
                   !_isSending && 
                   _messageController.text.trim().isNotEmpty &&
                   _filteredAttendees.isNotEmpty;
    final canResume = progress != null && progress.isPaused;
    final canPause = _isSending && !_isLoading;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main send button
        if (!_isSending && !canResume)
          ElevatedButton.icon(
            onPressed: canSend ? _sendMessages : null,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(
              _isLoading 
                  ? 'Preparing...' 
                  : 'Send to ${_filteredAttendees.length} ${_filteredAttendees.length == 1 ? "Recipient" : "Recipients"}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        
        // Resume button
        if (canResume)
          ElevatedButton.icon(
            onPressed: _resumeSending,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume Sending'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        
        // Pause/Cancel controls (shown when sending)
        if (_isSending || canPause) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPause ? _pauseSending : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canPause ? _cancelSending : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
        
        // Error message display
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Help text
        const SizedBox(height: 16),
        Text(
          'Tips:\n'
          '• Use {name} in your message to personalize it for each attendee\n'
          '• Messages will be sent using your device\'s SMS\n'
          '• You can pause and resume if there are issues\n'
          '• Failed messages will be logged for review\n'
          '• Messages are queued when offline and sent when online',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Cloud Sync & Real-time Updates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SyncStatusWidget(
              showDetails: false,
              showLastSyncTime: true,
              padding: EdgeInsets.all(0),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isOffline ? Icons.wifi_off : Icons.update,
                  size: 16,
                  color: isOffline ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  isOffline 
                      ? 'Real-time updates unavailable offline'
                      : 'Attendee list updates in real-time',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOffline ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}