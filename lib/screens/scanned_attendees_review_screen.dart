import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scanned_attendee_model.dart';
import '../models/attendee_model.dart';
import '../services/analytics_service.dart';
import '../services/registration_service.dart';
import '../theme/app_theme.dart';
import '../utils/phone_validator.dart';

/// Screen for reviewing and editing scanned attendees before saving
class ScannedAttendeesReviewScreen extends StatefulWidget {
  final List<ScannedAttendee> scannedAttendees;
  final String scanSource;

  const ScannedAttendeesReviewScreen({
    Key? key,
    required this.scannedAttendees,
    required this.scanSource,
  }) : super(key: key);

  @override
  State<ScannedAttendeesReviewScreen> createState() => _ScannedAttendeesReviewScreenState();
}

class _ScannedAttendeesReviewScreenState extends State<ScannedAttendeesReviewScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final RegistrationService _registrationService = RegistrationService();
  
  late List<ScannedAttendee> _attendees;
  final Set<int> _selectedIndices = {};
  bool _selectAll = true;
  bool _isSaving = false;
  int _currentServiceId = 1; // Default service ID

  @override
  void initState() {
    super.initState();
    _attendees = List.from(widget.scannedAttendees);
    
    // Initially select all attendees with medium+ confidence
    for (int i = 0; i < _attendees.length; i++) {
      if (_attendees[i].confidence >= 0.6) {
        _selectedIndices.add(i);
      }
    }
    
    _trackScreenView();
  }

  Future<void> _trackScreenView() async {
    await _analyticsService.trackScreenView(
      screenName: 'Scanned Attendees Review',
      screenClass: 'ScannedAttendeesReviewScreen',
    );
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedIndices.clear();
        for (int i = 0; i < _attendees.length; i++) {
          _selectedIndices.add(i);
        }
      } else {
        _selectedIndices.clear();
      }
      _selectAll = !_selectAll;
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _editAttendee(int index) async {
    final attendee = _attendees[index];
    
    final result = await showDialog<ScannedAttendee>(
      context: context,
      builder: (context) => _EditAttendeeDialog(attendee: attendee),
    );

    if (result != null) {
      setState(() {
        _attendees[index] = result;
      });
    }
  }

  Future<void> _saveSelectedAttendees() async {
    if (_selectedIndices.isEmpty) {
      _showErrorSnackBar('Please select at least one attendee to save');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedAttendees = _selectedIndices
          .map((index) => _attendees[index])
          .toList();

      int savedCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      for (final attendee in selectedAttendees) {
        try {
          // Convert to AttendeeModel format and save
          final attendeeData = attendee.toAttendeeModel(
            serviceId: _currentServiceId,
            category: 'Scanned from ${widget.scanSource}',
          );

          await _registrationService.registerAttendee(
            name: attendee.name,
            phoneNumber: attendee.phoneNumber,
            location: attendee.location,
            yearOfStudy: '',
            category: attendeeData['category'],
          );

          savedCount++;
        } catch (e) {
          errorCount++;
          errors.add('${attendee.name}: $e');
          debugPrint('Error saving attendee ${attendee.name}: $e');
        }
      }

      // Track save analytics
      await _analyticsService.trackAttendeeRegistration(
        attendeeId: 'bulk_scan_${DateTime.now().millisecondsSinceEpoch}',
        location: 'Multiple',
        category: 'Scanned',
        serviceId: _currentServiceId,
      );

      setState(() {
        _isSaving = false;
      });

      if (savedCount > 0) {
        _showSuccessDialog(savedCount, errorCount, errors);
      } else {
        _showErrorDialog('Save Failed', 'No attendees could be saved. Please check the data and try again.');
      }

    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      _showErrorDialog('Save Error', 'An error occurred while saving: $e');
    }
  }

  void _showSuccessDialog(int savedCount, int errorCount, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Successfully saved: $savedCount attendees'),
            if (errorCount > 0) ...[
              const SizedBox(height: 8),
              Text('❌ Failed to save: $errorCount attendees'),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...errors.take(3).map((error) => Text('• $error', style: const TextStyle(fontSize: 12))),
                if (errors.length > 3) Text('... and ${errors.length - 3} more'),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to scanner with success
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review Scanned Attendees (${_attendees.length})'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_selectAll ? Icons.deselect : Icons.select_all),
            onPressed: _toggleSelectAll,
            tooltip: _selectAll ? 'Deselect All' : 'Select All',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Found ${_attendees.length} attendees from ${widget.scanSource}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedIndices.length} selected for saving',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Service ${_currentServiceId}',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Attendees list
          Expanded(
            child: ListView.builder(
              itemCount: _attendees.length,
              itemBuilder: (context, index) {
                final attendee = _attendees[index];
                final isSelected = _selectedIndices.contains(index);
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleSelection(index),
                      activeColor: AppTheme.primaryBlue,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            attendee.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: attendee.confidenceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: attendee.confidenceColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            attendee.confidenceLevel,
                            style: TextStyle(
                              fontSize: 10,
                              color: attendee.confidenceColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(attendee.phoneNumber),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(attendee.location),
                          ],
                        ),
                        if (attendee.needsVerification) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.warning, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                'Needs verification',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editAttendee(index),
                      tooltip: 'Edit',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedIndices.isEmpty || _isSaving ? null : _saveSelectedAttendees,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Save ${_selectedIndices.length} Attendees'),
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

/// Dialog for editing scanned attendee data
class _EditAttendeeDialog extends StatefulWidget {
  final ScannedAttendee attendee;

  const _EditAttendeeDialog({required this.attendee});

  @override
  State<_EditAttendeeDialog> createState() => _EditAttendeeDialogState();
}

class _EditAttendeeDialogState extends State<_EditAttendeeDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.attendee.name);
    _phoneController = TextEditingController(text: widget.attendee.phoneNumber);
    _locationController = TextEditingController(text: widget.attendee.location);
    _notesController = TextEditingController(text: widget.attendee.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Attendee'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.trim().split(' ').length < 2) {
                    return 'Please enter full name (first and last)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  hintText: '0712345678 or +254712345678',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  final normalized = AttendeeModel.normalizePhoneNumber(value.trim());
                  if (normalized.isEmpty) {
                    return 'Invalid phone number format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              // Original scan info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Original Scan:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.attendee.sourceText,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${widget.attendee.confidenceLevel} (${(widget.attendee.confidence * 100).toInt()}%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.attendee.confidenceColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedAttendee = widget.attendee.copyWith(
                name: _nameController.text.trim(),
                phoneNumber: AttendeeModel.normalizePhoneNumber(_phoneController.text.trim()),
                location: _locationController.text.trim(),
                notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                isVerified: true, // Mark as verified after manual edit
              );
              Navigator.of(context).pop(updatedAttendee);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}