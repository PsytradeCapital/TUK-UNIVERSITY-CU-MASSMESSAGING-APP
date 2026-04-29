import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee_model.dart';
import '../repositories/offline_first_attendee_repository.dart';
import '../repositories/service_repository.dart';
import '../services/text_parser_service.dart';
import '../services/sms_manager.dart';
import '../providers/service_session_provider.dart';

/// Bulk Text Import Screen
/// Allows users to paste/type multiple attendees at once
/// Format: Name, Phone, Location (one per line)
/// Registers attendees to current session for messaging
class BulkTextImportScreen extends StatefulWidget {
  const BulkTextImportScreen({Key? key}) : super(key: key);

  @override
  State<BulkTextImportScreen> createState() => _BulkTextImportScreenState();
}

class _BulkTextImportScreenState extends State<BulkTextImportScreen> {
  final _textController = TextEditingController();
  final _repository = OfflineFirstAttendeeRepository();
  final _serviceRepository = ServiceRepository();
  final _parser = TextParserService();
  
  List<ParsedAttendee> _parsedAttendees = [];
  bool _isParsing = false;
  bool _isSaving = false;
  double _saveProgress = 0.0;
  String? _errorMessage;
  bool _registerToSession = true; // NEW: Option to register to current session

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseText() async {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });

    try {
      final text = _textController.text;
      final parsed = await _parser.parseAttendeeText(text);
      
      setState(() {
        _parsedAttendees = parsed;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse text: $e';
        _isParsing = false;
      });
    }
  }

  Future<void> _saveAll() async {
    final sessionProvider = context.read<ServiceSessionProvider>();
    final hasActiveSession = sessionProvider.hasActiveService;
    
    setState(() {
      _isSaving = true;
      _saveProgress = 0.0;
      _errorMessage = null;
    });

    try {
      int savedCount = 0;
      int skippedCount = 0;
      final List<AttendeeModel> registeredAttendees = [];
      
      for (int i = 0; i < _parsedAttendees.length; i++) {
        final parsed = _parsedAttendees[i];
        
        // Update progress every 5 items to avoid excessive rebuilds
        if (i % 5 == 0) {
          setState(() {
            _saveProgress = (i + 1) / _parsedAttendees.length;
          });
        }
        
        if (!parsed.isValid) {
          skippedCount++;
          continue;
        }

        // Normalise phone to 07/01 format before any DB lookup
        final normalisedPhone = AttendeeModel.normalizePhoneNumber(parsed.phoneNumber);

        // Check for duplicates
        final existing = await _repository.getAttendeeByPhone(normalisedPhone);
        
        AttendeeModel? savedAttendee;
        
        if (existing != null) {
          // Always auto-update: merge new data and increment attendance
          final updated = existing.copyWith(
            name: parsed.name.isNotEmpty ? parsed.name : existing.name,
            location: parsed.location.isNotEmpty && parsed.location != 'Unknown'
                ? parsed.location
                : existing.location,
            attendanceCount: existing.attendanceCount + 1,
            lastUpdated: DateTime.now(),
          );
          await _repository.updateAttendee(updated);
          savedAttendee = updated;
          savedCount++;
        } else {
          // Create new
          final newAttendee = AttendeeModel(
            name: parsed.name,
            phoneNumber: normalisedPhone,
            location: parsed.location,
            category: AttendeeCategory.student,
            yearOfStudy: '',
            attendanceCount: 1,
          );
          final id = await _repository.createAttendee(newAttendee);
          savedAttendee = newAttendee.copyWith(id: id); // id is the SQLite row id
          savedCount++;
        }
        
        // Add to session if option is enabled, session is active, and attendee has a valid id
        if (savedAttendee != null && savedAttendee.id != null && _registerToSession && hasActiveSession) {
          registeredAttendees.add(savedAttendee);
        }
      }
      
      // Register all attendees to current session
      if (registeredAttendees.isNotEmpty && hasActiveSession) {
        final serviceId = sessionProvider.currentService!.serviceId;
        for (final attendee in registeredAttendees) {
          await _serviceRepository.addAttendeeToService(
            serviceId!,
            attendee.id!,
          );
        }
        
        // Update session provider
        await sessionProvider.loadActiveService();
      }

      if (mounted) {
        final sessionMsg = _registerToSession && hasActiveSession && registeredAttendees.isNotEmpty
            ? ' Added ${registeredAttendees.length} to active session.'
            : '';
        final message = 'Saved $savedCount attendees.$sessionMsg Skipped $skippedCount invalid.';

        // Collect all saved attendees for mass messaging
        final allSaved = <AttendeeModel>[];
        for (final parsed in _parsedAttendees) {
          if (!parsed.isValid) continue;
          final phone = AttendeeModel.normalizePhoneNumber(parsed.phoneNumber);
          final found = await _repository.getAttendeeByPhone(phone);
          if (found != null) allSaved.add(found);
        }

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Import Complete'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
              if (allSaved.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text('Message All (${allSaved.length})'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _MassMessageScreen(attendees: allSaved),
                      ),
                    );
                  },
                ),
            ],
          ),
        );

        if (mounted) Navigator.pop(context, savedCount);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save attendees: $e';
        _isSaving = false;
        _saveProgress = 0.0;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<ServiceSessionProvider>();
    final hasActiveSession = sessionProvider.hasActiveService;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Text Import'),
        actions: [
          if (_parsedAttendees.isNotEmpty && !_isSaving)
            IconButton(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              tooltip: 'Save All',
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste or type attendee information:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Format: Name, Phone, Location'),
                const Text('Example:'),
                const Text('John Doe, 0712345678, Nairobi'),
                const Text('Jane Smith, 0723456789, Mombasa'),
                const SizedBox(height: 8),
                const Text(
                  'One attendee per line',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
                if (hasActiveSession) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _registerToSession,
                    onChanged: _isSaving ? null : (value) {
                      setState(() {
                        _registerToSession = value ?? true;
                      });
                    },
                    title: const Text('Register to current session'),
                    subtitle: const Text('Add attendees to active service for messaging'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),

          // Saving progress indicator
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _saveProgress),
                  const SizedBox(height: 8),
                  Text('Saving... ${(_saveProgress * 100).toInt()}%'),
                ],
              ),
            ),

          // Text input
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  hintText: 'Paste attendee list here...',
                  border: OutlineInputBorder(),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),

          // Parse button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isParsing || _isSaving) ? null : _parseText,
                icon: _isParsing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isParsing ? 'Parsing...' : 'Parse Text'),
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Parsed results
          if (_parsedAttendees.isNotEmpty)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Found ${_parsedAttendees.length} attendees',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _parsedAttendees.length,
                      itemBuilder: (context, index) {
                        final attendee = _parsedAttendees[index];
                        return ListTile(
                          leading: Icon(
                            attendee.isValid ? Icons.check_circle : Icons.error,
                            color: attendee.isValid ? Colors.green : Colors.red,
                          ),
                          title: Text(attendee.name),
                          subtitle: Text('${attendee.phoneNumber} • ${attendee.location}'),
                          trailing: attendee.isValid
                              ? null
                              : const Text(
                                  'Invalid',
                                  style: TextStyle(color: Colors.red),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple mass-messaging screen for a list of attendees — no session required.
class _MassMessageScreen extends StatefulWidget {
  final List<AttendeeModel> attendees;
  const _MassMessageScreen({required this.attendees});

  @override
  State<_MassMessageScreen> createState() => _MassMessageScreenState();
}

class _MassMessageScreenState extends State<_MassMessageScreen> {
  final _msgController = TextEditingController();
  final _smsManager = SMSManager();
  bool _sending = false;
  String? _result;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_msgController.text.trim().isEmpty) return;
    setState(() { _sending = true; _result = null; });
    try {
      int sent = 0, failed = 0;
      await _smsManager.sendBulkSMS(
        widget.attendees,
        _msgController.text.trim(),
        onMessageSent: (_) => sent++,
        onMessageFailed: (_) => failed++,
      );
      setState(() {
        _result = '✅ Sent: $sent${failed > 0 ? '  ❌ Failed: $failed' : ''}';
      });
    } catch (e) {
      setState(() { _result = '❌ Error: $e'; });
    } finally {
      setState(() { _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Message ${widget.attendees.length} Contacts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.attendees.length} recipients',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _msgController,
              maxLines: 6,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Use {name} to personalise',
                border: OutlineInputBorder(),
                helperText: 'Keep under 160 chars for reliable delivery',
              ),
            ),
            const SizedBox(height: 16),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: _result!.startsWith('✅') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send to All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
