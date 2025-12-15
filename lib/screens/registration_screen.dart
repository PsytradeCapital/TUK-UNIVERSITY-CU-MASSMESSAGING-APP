import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee_model.dart';
import '../services/registration_service.dart';
import '../widgets/attendee_search_widget.dart';
import '../widgets/cu_logo_widget.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets/offline_handler.dart';
import '../providers/service_session_provider.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with OfflineCapable {
  final _formKey = GlobalKey<FormState>();
  final _registrationService = RegistrationService();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customLocationController = TextEditingController();
  
  // Form state
  String? _selectedYear;
  String? _selectedLocation;
  AttendeeCategory _selectedCategory = AttendeeCategory.student;
  bool _isLoading = false;
  bool _showCustomLocation = false;
  
  // Selected attendee for returning attendee registration
  AttendeeModel? _selectedAttendee;
  bool _isReturningAttendee = false;
  
  // Error messages
  String? _nameError;
  String? _phoneError;
  String? _yearError;
  String? _locationError;
  String? _categoryError;
  String? _generalError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _customLocationController.dispose();
    super.dispose();
  }

  void _onAttendeeSelected(AttendeeModel attendee) {
    setState(() {
      _selectedAttendee = attendee;
      _isReturningAttendee = true;
      
      // Auto-populate form with attendee data
      _nameController.text = attendee.name;
      _phoneController.text = attendee.phoneNumber;
      _selectedYear = attendee.yearOfStudy;
      _selectedCategory = attendee.category;
      
      // Handle location - check if it's a predefined location
      final predefinedLocations = _registrationService.getPredefinedLocations();
      if (predefinedLocations.contains(attendee.location)) {
        _selectedLocation = attendee.location;
        _showCustomLocation = false;
        _customLocationController.clear();
      } else {
        _selectedLocation = 'Other';
        _customLocationController.text = attendee.location;
        _showCustomLocation = true;
      }
      
      // Clear any previous errors
      _clearErrors();
    });
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _customLocationController.clear();
      _selectedYear = null;
      _selectedLocation = null;
      _selectedCategory = AttendeeCategory.student;
      _selectedAttendee = null;
      _isReturningAttendee = false;
      _showCustomLocation = false;
      _clearErrors();
    });
  }

  void _clearErrors() {
    setState(() {
      _nameError = null;
      _phoneError = null;
      _yearError = null;
      _locationError = null;
      _categoryError = null;
      _generalError = null;
    });
  }

  bool _validateForm() {
    _clearErrors();
    bool isValid = true;

    // Validate name
    final nameError = _registrationService.validateName(_nameController.text);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      isValid = false;
    }

    // Validate phone
    final phoneError = _registrationService.validatePhoneNumber(_phoneController.text);
    if (phoneError != null) {
      setState(() => _phoneError = phoneError);
      isValid = false;
    }

    // Validate year (only required for students)
    if (_selectedCategory == AttendeeCategory.student) {
      final yearError = _registrationService.validateYearOfStudy(_selectedYear ?? '');
      if (yearError != null) {
        setState(() => _yearError = yearError);
        isValid = false;
      }
    }

    // Validate location
    String locationValue = _selectedLocation == 'Other' 
        ? _customLocationController.text.trim() 
        : _selectedLocation ?? '';
    final locationError = _registrationService.validateLocation(locationValue);
    if (locationError != null) {
      setState(() => _locationError = locationError);
      isValid = false;
    }

    return isValid;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final locationValue = _selectedLocation == 'Other' 
          ? _customLocationController.text.trim() 
          : _selectedLocation!;

      // Handle offline registration
      final success = await handleOfflineOperation(
        'registration',
        () async {
          RegistrationResult result;

          if (_isReturningAttendee && _selectedAttendee != null) {
            // Register returning attendee with potential updates
            result = await _registrationService.registerReturningAttendeeWithValidation(
              existingAttendee: _selectedAttendee!,
              updatedName: _nameController.text.trim(),
              updatedPhone: _phoneController.text.trim(),
              updatedYear: _selectedYear,
              updatedLocation: locationValue,
            );
          } else {
            // Register new attendee
            result = await _registrationService.registerAttendee(
              name: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              yearOfStudy: _selectedYear ?? '',
              location: locationValue,
              category: _selectedCategory,
            );
          }

          if (result.isSuccess) {
            _showSuccessDialog(result.attendee!, _isReturningAttendee);
            _clearForm();
          } else if (result.isDuplicate) {
            _showDuplicateDialog(result.attendee!);
          } else {
            setState(() => _generalError = result.errorMessage);
          }
        },
        operationData: {
          'type': _isReturningAttendee ? 'returning' : 'new',
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'year': _selectedYear ?? '',
          'location': locationValue,
          'category': _selectedCategory.toString(),
        },
      );

      // If offline, show appropriate message
      if (!success && isOffline) {
        setState(() => _generalError = 'Registration saved offline. Will sync when online.');
        _clearForm();
      }
    } catch (e) {
      setState(() => _generalError = 'Registration failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(AttendeeModel attendee, bool isReturning) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Icon(
          Icons.check_circle, 
          color: Colors.green, 
          size: 48
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isReturning ? 'Welcome Back!' : 'Registration Successful!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Name: ${attendee.name}'),
            Text('Phone: ${attendee.phoneNumber}'),
            Text('Category: ${attendee.categoryDisplayName}'),
            if (attendee.yearOfStudy.isNotEmpty)
              Text('Year: ${attendee.yearOfStudy}'),
            Text('Location: ${attendee.location}'),
            if (isReturning)
              Text(
                'Total Attendance: ${attendee.attendanceCount}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            const SizedBox(height: 16),
            // Show sync status
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isOffline ? Icons.wifi_off : Icons.cloud_done,
                        size: 16,
                        color: isOffline ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOffline ? 'Saved offline' : 'Synced to cloud',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOffline ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (isOffline)
                    const Text(
                      'Will sync when connection is restored',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateDialog(AttendeeModel existingAttendee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.warning, color: Colors.orange, size: 48),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Phone Number Already Registered',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Name: ${existingAttendee.name}'),
            Text('Phone: ${existingAttendee.phoneNumber}'),
            Text('Category: ${existingAttendee.categoryDisplayName}'),
            if (existingAttendee.yearOfStudy.isNotEmpty)
              Text('Year: ${existingAttendee.yearOfStudy}'),
            Text('Location: ${existingAttendee.location}'),
            Text('Attendance Count: ${existingAttendee.attendanceCount}'),
            const SizedBox(height: 16),
            const Text('Would you like to register this person for today\'s service?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await _registrationService.registerReturningAttendee(existingAttendee);
              if (result.isSuccess) {
                _showSuccessDialog(result.attendee!, true);
                _clearForm();
              } else {
                _showErrorSnackBar(result.errorMessage ?? 'Failed to register returning attendee');
              }
            },
            child: const Text('Register for Today'),
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, sessionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CULogoWidget(height: 48, useDarkVersion: true),
                const SizedBox(width: 12),
                const Text('Register Attendee'),
              ],
            ),
            centerTitle: true,
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            toolbarHeight: 70,
            actions: [
              IconButton(
                onPressed: _clearForm,
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear Form',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Service Session Management Card
                  _buildSessionManagementCard(sessionProvider),
                  
                  const SizedBox(height: 16),
                  
                  // Sync Status Card
                  _buildSyncStatusCard(),
                  
                  const SizedBox(height: 16),
              // Search for returning attendees
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.search, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Search for Returning Attendee',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_isReturningAttendee)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isReturningAttendee = false;
                                  _selectedAttendee = null;
                                });
                                _clearForm();
                              },
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('New Attendee'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_isReturningAttendee) ...[
                        AttendeeSearchWidget(
                          onAttendeeSelected: _onAttendeeSelected,
                          enabled: !_isLoading,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected: ${_selectedAttendee?.name ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    if (_selectedAttendee != null)
                                      Text(
                                        'Previous visits: ${_selectedAttendee!.attendanceCount}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Registration form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isReturningAttendee ? Icons.person_outline : Icons.person_add,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isReturningAttendee ? 'Confirm Attendee Details' : 'New Attendee Registration',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'Enter full name',
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                          errorText: _nameError,
                          helperText: _isReturningAttendee ? 'You can edit details if needed' : null,
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: '+2547xxxxxxxx or 07xxxxxxxx',
                          prefixIcon: const Icon(Icons.phone),
                          border: const OutlineInputBorder(),
                          errorText: _phoneError,
                        ),
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Category dropdown
                      DropdownButtonFormField<AttendeeCategory>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          prefixIcon: const Icon(Icons.category),
                          border: const OutlineInputBorder(),
                          errorText: _categoryError,
                          helperText: 'Select Student, Associate, or Visitor',
                        ),
                        items: AttendeeCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(AttendeeModel.categoryToString(category).toUpperCase()),
                          );
                        }).toList(),
                        onChanged: _isLoading ? null : (value) {
                          setState(() {
                            _selectedCategory = value!;
                            _categoryError = null;
                            // Clear year if not a student
                            if (_selectedCategory != AttendeeCategory.student) {
                              _selectedYear = null;
                            }
                          });
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Year of study dropdown (only for students)
                      if (_selectedCategory == AttendeeCategory.student)
                        DropdownButtonFormField<String>(
                          value: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year of Study *',
                            prefixIcon: const Icon(Icons.school),
                            border: const OutlineInputBorder(),
                            errorText: _yearError,
                          ),
                          items: _registrationService.getYearOfStudyOptions().map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            );
                          }).toList(),
                          onChanged: _isLoading ? null : (value) {
                            setState(() {
                              _selectedYear = value;
                              _yearError = null;
                            });
                          },
                        ),
                      
                      if (_selectedCategory == AttendeeCategory.student)
                        const SizedBox(height: 16),
                      
                      const SizedBox(height: 16),
                      
                      // Location dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: InputDecoration(
                          labelText: 'Location *',
                          prefixIcon: const Icon(Icons.location_on),
                          border: const OutlineInputBorder(),
                          errorText: _locationError,
                        ),
                        items: _registrationService.getPredefinedLocations().map((location) {
                          return DropdownMenuItem(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: _isLoading ? null : (value) {
                          setState(() {
                            _selectedLocation = value;
                            _showCustomLocation = value == 'Other';
                            _locationError = null;
                            if (!_showCustomLocation) {
                              _customLocationController.clear();
                            }
                          });
                        },
                      ),
                      
                      // Custom location field (shown when "Other" is selected)
                      if (_showCustomLocation) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customLocationController,
                          decoration: InputDecoration(
                            labelText: 'Custom Location *',
                            hintText: 'Enter your location in Nairobi',
                            prefixIcon: const Icon(Icons.edit_location),
                            border: const OutlineInputBorder(),
                            errorText: _locationError,
                          ),
                          textCapitalization: TextCapitalization.words,
                          enabled: !_isLoading,
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Error message
                      if (_generalError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _generalError!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Registering...'),
                                  ],
                                )
                              : Text(
                                  _isReturningAttendee 
                                      ? 'Register for Today\'s Service' 
                                      : 'Register New Attendee',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionManagementCard(ServiceSessionProvider sessionProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sessionProvider.hasActiveService ? Icons.event : Icons.event_available,
                  color: sessionProvider.hasActiveService ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  sessionProvider.hasActiveService ? 'Active Service Session' : 'No Active Session',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (sessionProvider.hasActiveService) ...[
                  Chip(
                    label: Text('${sessionProvider.attendeeCount} attendees'),
                    backgroundColor: Colors.blue.shade100,
                    labelStyle: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (sessionProvider.hasActiveService) ...[
              // Active session info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Started: ${_formatDateTime(sessionProvider.currentService!.serviceDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (sessionProvider.attendeeCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Registered Attendees:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...sessionProvider.currentAttendees.take(3).map((attendee) => 
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '• ${attendee.name} (${attendee.yearOfStudy})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                      ),
                      if (sessionProvider.attendeeCount > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '... and ${sessionProvider.attendeeCount - 3} more',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Session actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sessionProvider.isLoading ? null : () => _showAttendeeListDialog(sessionProvider),
                      icon: const Icon(Icons.list, size: 16),
                      label: const Text('View All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sessionProvider.isLoading ? null : () => _showClearSessionDialog(sessionProvider),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear Session'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No active session
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 32, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'No active service session',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a new service to begin registering attendees',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Start new service button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sessionProvider.isLoading ? null : () => _startNewService(sessionProvider),
                  icon: sessionProvider.isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle),
                  label: Text(sessionProvider.isLoading ? 'Starting...' : 'Start New Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _startNewService(ServiceSessionProvider sessionProvider) async {
    try {
      await sessionProvider.startNewService();
      _showSuccessSnackBar('New service session started successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to start new service: $e');
    }
  }

  void _showAttendeeListDialog(ServiceSessionProvider sessionProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Current Session Attendees (${sessionProvider.attendeeCount})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: sessionProvider.currentAttendees.isEmpty
              ? const Center(
                  child: Text('No attendees registered yet'),
                )
              : ListView.builder(
                  itemCount: sessionProvider.currentAttendees.length,
                  itemBuilder: (context, index) {
                    final attendee = sessionProvider.currentAttendees[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            attendee.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          attendee.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${attendee.phoneNumber} • ${attendee.yearOfStudy}'),
                            Text(
                              '${attendee.location} • ${attendee.attendanceCount} visits',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeAttendeeFromSession(sessionProvider, attendee),
                          tooltip: 'Remove from session',
                        ),
                      ),
                    );
                  },
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

  void _showClearSessionDialog(ServiceSessionProvider sessionProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear Session'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to clear the current service session?'),
            const SizedBox(height: 8),
            Text(
              'This will remove all ${sessionProvider.attendeeCount} registered attendees from the current session.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Attendee records will be preserved, but they will need to be re-registered for future services.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearSession(sessionProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAttendeeFromSession(ServiceSessionProvider sessionProvider, AttendeeModel attendee) async {
    try {
      await sessionProvider.removeAttendeeFromSession(attendee);
      _showSuccessSnackBar('${attendee.name} removed from session');
      Navigator.of(context).pop(); // Close the dialog
      // Reopen the dialog to show updated list
      _showAttendeeListDialog(sessionProvider);
    } catch (e) {
      _showErrorSnackBar('Failed to remove attendee: $e');
    }
  }

  void _clearSession(ServiceSessionProvider sessionProvider) {
    sessionProvider.clearSession();
    _showSuccessSnackBar('Service session cleared successfully');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Cloud Sync Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SyncStatusWidget(
              showDetails: true,
              showLastSyncTime: true,
              padding: EdgeInsets.all(0),
            ),
          ],
        ),
      ),
    );
  }
}