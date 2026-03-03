import 'package:flutter/material.dart';
import '../models/attendee_model.dart';
import '../repositories/offline_first_attendee_repository.dart';
import '../services/text_parser_service.dart';

/// Bulk Text Import Screen
/// Allows users to paste/type multiple attendees at once
/// Format: Name, Phone, Location (one per line)
class BulkTextImportScreen extends StatefulWidget {
  const BulkTextImportScreen({Key? key}) : super(key: key);

  @override
  State<BulkTextImportScreen> createState() => _BulkTextImportScreenState();
}

class _BulkTextImportScreenState extends State<BulkTextImportScreen> {
  final _textController = TextEditingController();
  final _repository = OfflineFirstAttendeeRepository();
  final _parser = TextParserService();
  
  List<ParsedAttendee> _parsedAttendees = [];
  bool _isParsing = false;
  bool _isSaving = false;
  String? _errorMessage;

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
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      int savedCount = 0;
      int skippedCount = 0;
      
      for (final parsed in _parsedAttendees) {
        if (!parsed.isValid) {
          skippedCount++;
          continue;
        }

        // Check for duplicates
        final existing = await _repository.getAttendeeByPhone(parsed.phoneNumber);
        
        if (existing != null) {
          // Show confirmation dialog
          final shouldUpdate = await _showDuplicateDialog(existing, parsed);
          
          if (shouldUpdate == true) {
            // Update existing
            await _repository.updateAttendee(
              existing.copyWith(
                name: parsed.name,
                location: parsed.location,
              ),
            );
            savedCount++;
          } else {
            skippedCount++;
          }
        } else {
          // Create new
          await _repository.createAttendee(AttendeeModel(
            name: parsed.name,
            phoneNumber: parsed.phoneNumber,
            location: parsed.location,
            category: AttendeeCategory.student,
          ));
          savedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $savedCount attendees, skipped $skippedCount'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, savedCount);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save attendees: $e';
        _isSaving = false;
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
                onPressed: _isParsing ? null : _parseText,
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
