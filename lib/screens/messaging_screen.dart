import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee_model.dart';
import '../models/message_log_model.dart';
import '../services/sms_manager.dart';
import '../services/notification_service.dart';
import '../repositories/message_log_repository.dart';
import '../providers/service_session_provider.dart';
import '../widgets/cu_logo_widget.dart';

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

class _MessagingScreenState extends State<MessagingScreen> {
  final _messageController = TextEditingController();
  final _smsManager = SMSManager();
  final _messageLogRepository = MessageLogRepository();
  final _notificationService = NotificationService();
  
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  SMSProgress? _currentProgress;
  
  // Message composition state
  int _characterCount = 0;
  final int _maxCharacters = 1600; // SMS limit
  bool _showPreview = false;
  String _previewMessage = '';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updateCharacterCount);
    
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

    if (widget.attendees.isEmpty) {
      _notificationService.showErrorNotification(
        'No Recipients',
        'No attendees found for this service session.',
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

    try {
      await _smsManager.sendBulkSMS(
        widget.attendees,
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
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _notificationService.showErrorNotification(
        'Sending Failed',
        _smsManager.getUserFriendlyErrorMessage(e.toString()),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      ),
      body: widget.attendees.isEmpty
          ? _buildEmptyState()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.attendees.length} attendees will receive this message',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            
            // Show first few attendees
            if (widget.attendees.isNotEmpty) ...[
              const Divider(),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: widget.attendees.length,
                  itemBuilder: (context, index) {
                    final attendee = widget.attendees[index];
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
                        '${AttendeeModel.maskPhoneNumber(attendee.phoneNumber)} • ${attendee.yearOfStudy}',
                      ),
                      trailing: Text(
                        '${attendee.attendanceCount} visits',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
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
                   widget.attendees.isNotEmpty;
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
            label: Text(_isLoading ? 'Preparing...' : 'Send Messages'),
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
          '• Failed messages will be logged for review',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}