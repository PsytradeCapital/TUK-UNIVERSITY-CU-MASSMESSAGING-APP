import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee_model.dart';
import '../repositories/offline_first_attendee_repository.dart';
import '../repositories/service_repository.dart';
import '../services/text_parser_service.dart';
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
        
        // Update progress
        setState(() {
          _saveProgress = (i + 1) / _parsedAttendees.length;
        });
        
        if (!parsed.isValid) {
          skippedCount++;
          continue;
        }

        // Check for duplicates
        final existing = await _repository.getAttendeeByPhone(parsed.phoneNumber);
        
        AttendeeModel? savedAttendee;
        
        if (existing != null) {
          // Show confirmation dialog
          final shouldUpdate = await _showDuplicateDialog(existing, parsed);
          
          if (shouldUpdate == true) {
            // Update existing
            final updated = existing.copyWith(
              name: parsed.name,
              location: parsed.location,
              attendanceCount: existing.attendanceCount + 1, // Increment attendance
            );
            await _repository.updateAttendee(updated);
            savedAttendee = updated;
            savedCount++;
          } else {
            skippedCount++;
          }
        } else {
          // Create new
          final newAttendee = AttendeeModel(
            name: parsed.name,
            phoneNumber: parsed.phoneNumber,
            location: parsed.location,
            category: AttendeeCategory.student,
            yearOfStudy: '',
            attendanceCount: 1, // First attendance
          );
          final id = await _repository.createAttendee(newAttendee);
          savedAttendee = newAttendee.copyWith(id: id);
          savedCount++;
        }
        
        // Add to session if option is enabled and session is active
        if (savedAttendee != null && _registerToSession && hasActiveSession) {
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
        final message = _registerToSession && hasActiveSession
            ? 'Saved $savedCount attendees to database and registered to current session. Skipped $skippedCount.'
            : 'Saved $savedCount attendees to database. Skipped $skippedCount.';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        Navigator.pop(context, savedCount);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save attendees: $e';
        _isSaving = false;
        _saveProgress = 0.0;
      });
    }
  }

  Future<bool?> _showDuplicateDialog(AttendeeModel existing, ParsedAttendee parsed) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone number ${parsed.phoneNumber} already exists:'),
            const SizedBox(height: 8),
            Text('Existing: ${existing.name}'),
            Text('New: ${parsed.name}'),
            const SizedBox(height: 16),
            const Text('Do you want to update the existing record?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
