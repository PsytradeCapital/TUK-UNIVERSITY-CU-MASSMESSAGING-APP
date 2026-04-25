import 'package:flutter/material.dart';
import '../models/attendee_model.dart';
import '../repositories/offline_first_attendee_repository.dart';
import '../services/sms_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/sync_status_widget.dart';

class AllMembersScreen extends StatefulWidget {
  const AllMembersScreen({Key? key}) : super(key: key);

  @override
  State<AllMembersScreen> createState() => _AllMembersScreenState();
}

class _AllMembersScreenState extends State<AllMembersScreen> {
  final _attendeeRepository = OfflineFirstAttendeeRepository();
  final _smsManager = SMSManager();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _overlayPortalController = OverlayPortalController();
  
  List<AttendeeModel> _allAttendees = [];
  List<AttendeeModel> _filteredAttendees = [];
  List<AttendeeModel> _autocompleteSuggestions = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showAutocomplete = false;
  
  // Filters
  String? _selectedLocation;
  String? _selectedYear;
  String? _selectedCategory;
  List<String> _locations = [];
  List<String> _years = [];
  
  @override
  void initState() {
    super.initState();
    _loadAllContacts();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadAllContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Local SQLite — instant read
      final attendees = await _attendeeRepository.getAllAttendees();

      if (!mounted) return;

      attendees.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final locations = attendees.map((a) => a.location).toSet().toList()
        ..sort();

      final years = attendees
          .where((a) => a.yearOfStudy.isNotEmpty)
          .map((a) => a.yearOfStudy)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _allAttendees = attendees;
        _filteredAttendees = attendees;
        _locations = locations;
        _years = years;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load members: $e';
        _isLoading = false;
      });
    }
  }
  
  void _onSearchChanged() {
    _applyFilters();
    _updateAutocompleteSuggestions();
  }
  
  void _updateAutocompleteSuggestions() {
    final query = _searchController.text.toLowerCase().trim();
    
    if (query.isEmpty) {
      setState(() {
        _showAutocomplete = false;
        _autocompleteSuggestions = [];
      });
      return;
    }
    
    // Get top 10 matching attendees
    final suggestions = _allAttendees.where((attendee) {
      return attendee.name.toLowerCase().contains(query) ||
             attendee.phoneNumber.contains(query);
    }).take(10).toList();
    
    setState(() {
      _autocompleteSuggestions = suggestions;
      _showAutocomplete = suggestions.isNotEmpty;
    });
  }
  
  void _selectSuggestion(AttendeeModel attendee) {
    setState(() {
      _searchController.text = attendee.name;
      _showAutocomplete = false;
      _searchFocusNode.unfocus();
    });
    _applyFilters();
  }
  
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredAttendees = _allAttendees.where((attendee) {
        // Search filter
        final matchesSearch = query.isEmpty ||
            attendee.name.toLowerCase().contains(query) ||
            attendee.phoneNumber.contains(query);
        
        // Location filter
        final matchesLocation = _selectedLocation == null ||
            attendee.location == _selectedLocation;
        
        // Year filter
        final matchesYear = _selectedYear == null ||
            attendee.yearOfStudy == _selectedYear;
        
        // Category filter
        final matchesCategory = _selectedCategory == null ||
            attendee.category == _selectedCategory;
        
        return matchesSearch && matchesLocation && matchesYear && matchesCategory;
      }).toList();
      
      // Sort filtered results
      _filteredAttendees.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }
  
  void _clearFilters() {
    setState(() {
      _selectedLocation = null;
      _selectedYear = null;
      _selectedCategory = null;
      _searchController.clear();
      _showAutocomplete = false;
      _autocompleteSuggestions = [];
      _filteredAttendees = List.from(_allAttendees);
    });
  }
  
  Future<void> _sendMessageToAll() async {
    if (_filteredAttendees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members to message')),
      );
      return;
    }
    
    final messageController = TextEditingController();
    bool personalizeMessage = false;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Send to ${_filteredAttendees.length} members'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Keep under 160 chars for reliable delivery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Use {name} to personalize',
                    border: const OutlineInputBorder(),
                    helperText: 'Recommended: 160 chars or less',
                    helperStyle: TextStyle(
                      color: messageController.text.length > 160 
                          ? Colors.red 
                          : Colors.grey,
                    ),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                  onChanged: (text) {
                    setDialogState(() {}); // Rebuild to update helper color
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Personalize with names'),
                  subtitle: const Text('Replace {name} with each member\'s name'),
                  value: personalizeMessage,
                  onChanged: (value) {
                    setDialogState(() {
                      personalizeMessage = value ?? false;
                    });
                  },
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && messageController.text.isNotEmpty) {
      await _sendMessages(messageController.text, personalizeMessage);
    }
  }
  
  Future<void> _sendMessages(String message, bool personalize) async {
    // Check message length and warn user
    if (message.length > 160) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Long Message Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your message is ${message.length} characters long.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Messages over 160 characters may FAIL to send on many networks!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Standard SMS limit is 160 characters\n'
                      '• Longer messages need multipart SMS\n'
                      '• Many carriers block or fail multipart SMS\n'
                      '• You may waste airtime on failed messages',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sending to ${_filteredAttendees.length} members',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recommendation: Shorten your message to 160 characters or less for reliable delivery.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel & Edit'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Send Anyway (Risky)'),
            ),
          ],
        ),
      );
      
      if (proceed != true) return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Sending messages... (${message.length} chars)'),
            if (message.length > 160)
              const Text(
                'Long messages may take longer',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
    
    try {
      int sent = 0;
      int failed = 0;
      
      // If personalizing, send individually with personalized messages
      if (personalize) {
        for (final attendee in _filteredAttendees) {
          try {
            final personalizedMsg = message.replaceAll('{name}', attendee.name)
                                           .replaceAll('{Name}', attendee.name)
                                           .replaceAll('{NAME}', attendee.name.toUpperCase());
            await _smsManager.sendBulkSMS([attendee], personalizedMsg);
            sent++;
          } catch (e) {
            failed++;
          }
        }
      } else {
        // Send same message to all
        await _smsManager.sendBulkSMS(
          _filteredAttendees,
          message,
          onMessageSent: (_) => sent++,
          onMessageFailed: (_) => failed++,
        );
      }
      
      Navigator.pop(context); // Close progress dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            failed > 0 ? 'Messages Sent (Some Failed)' : 'Messages Sent',
            style: TextStyle(
              color: failed > 0 ? Colors.orange : Colors.green,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Sent: $sent'),
              if (failed > 0) Text('❌ Failed: $failed'),
              const SizedBox(height: 12),
              if (message.length > 160)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Note: Long messages (>160 chars) may show as "sent" but fail to deliver. Check with recipients to confirm.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllContacts,
            tooltip: 'Refresh',
          ),
          const SyncStatusWidget(),
        ],
      ),
      body: Column(
        children: [
          // Search bar with autocomplete
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _showAutocomplete = false;
                                _autocompleteSuggestions = [];
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              // Autocomplete dropdown
              if (_showAutocomplete && _autocompleteSuggestions.isNotEmpty)
                Positioned(
                  top: 72,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _autocompleteSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _autocompleteSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                              child: Text(
                                suggestion.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              suggestion.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              '${suggestion.phoneNumber} • ${suggestion.location}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Location filter
                _buildFilterChip(
                  label: _selectedLocation ?? 'Location',
                  icon: Icons.location_on,
                  onTap: () => _showLocationFilter(),
                  isActive: _selectedLocation != null,
                ),
                const SizedBox(width: 8),
                
                // Year filter
                _buildFilterChip(
                  label: _selectedYear ?? 'Year',
                  icon: Icons.school,
                  onTap: () => _showYearFilter(),
                  isActive: _selectedYear != null,
                ),
                const SizedBox(width: 8),
                
                // Category filter
                _buildFilterChip(
                  label: _selectedCategory ?? 'Category',
                  icon: Icons.category,
                  onTap: () => _showCategoryFilter(),
                  isActive: _selectedCategory != null,
                ),
                const SizedBox(width: 8),
                
                // Clear filters
                if (_selectedLocation != null || _selectedYear != null || _selectedCategory != null)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredAttendees.length} members',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_filteredAttendees.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _sendMessageToAll,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Message All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          
          // Contacts list
          Expanded(
            child: _buildContactsList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
    );
  }
  
  Widget _buildContactsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllContacts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredAttendees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _allAttendees.isEmpty
                  ? 'No members yet'
                  : 'No members match your filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    
    // Group by first letter
    final grouped = <String, List<AttendeeModel>>{};
    for (final attendee in _filteredAttendees) {
      final firstLetter = attendee.name[0].toUpperCase();
      grouped.putIfAbsent(firstLetter, () => []).add(attendee);
    }
    
    final sortedKeys = grouped.keys.toList()..sort();
    
    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final letter = sortedKeys[index];
        final contacts = grouped[letter]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[200],
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            // Contacts in this section
            ...contacts.map((attendee) => _buildContactTile(attendee)),
          ],
        );
      },
    );
  }
  
  Widget _buildContactTile(AttendeeModel attendee) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryBlue,
        child: Text(
          attendee.name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(attendee.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(attendee.phoneNumber),
          Text(
            '${attendee.location} • ${attendee.category}${attendee.yearOfStudy != null ? " • ${attendee.yearOfStudy}" : ""}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.message, color: AppTheme.primaryBlue),
        onPressed: () => _sendMessageToOne(attendee),
        tooltip: 'Send message',
      ),
      isThreeLine: true,
    );
  }
  
  Future<void> _sendMessageToOne(AttendeeModel attendee) async {
    final messageController = TextEditingController();
    bool personalizeMessage = false;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Message ${attendee.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Keep under 160 chars for reliable delivery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Use {name} to personalize',
                    border: const OutlineInputBorder(),
                    helperText: 'Recommended: 160 chars or less',
                    helperStyle: TextStyle(
                      color: messageController.text.length > 160 
                          ? Colors.red 
                          : Colors.grey,
                    ),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                  onChanged: (text) {
                    setDialogState(() {}); // Rebuild to update helper color
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Personalize with name'),
                  subtitle: Text('Replace {name} with ${attendee.name}'),
                  value: personalizeMessage,
                  onChanged: (value) {
                    setDialogState(() {
                      personalizeMessage = value ?? false;
                    });
                  },
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && messageController.text.isNotEmpty) {
      try {
        String finalMessage = messageController.text;
        if (personalizeMessage) {
          finalMessage = finalMessage.replaceAll('{name}', attendee.name)
                                     .replaceAll('{Name}', attendee.name)
                                     .replaceAll('{NAME}', attendee.name.toUpperCase());
        }
        
        // Warn if message is too long
        if (finalMessage.length > 160) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Long Message'),
                ],
              ),
              content: Text(
                'Your message is ${finalMessage.length} characters. Messages over 160 characters may fail to send on some networks.\n\nDo you want to send anyway?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Send Anyway'),
                ),
              ],
            ),
          );
          
          if (proceed != true) return;
        }
        
        await _smsManager.sendBulkSMS([attendee], finalMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalMessage.length > 160 
                  ? 'Message sent (${finalMessage.length} chars - may take longer)'
                  : 'Message sent!'
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }
  
  void _showLocationFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Locations'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedLocation,
                  onChanged: (value) {
                    setState(() => _selectedLocation = null);
                    Navigator.pop(context);
                    _applyFilters();
                  },
                ),
                onTap: () {
                  setState(() => _selectedLocation = null);
                  Navigator.pop(context);
                  _applyFilters();
                },
              ),
              const Divider(),
              ..._locations.map((location) => ListTile(
                    title: Text(location),
                    leading: Radio<String?>(
                      value: location,
                      groupValue: _selectedLocation,
                      onChanged: (value) {
                        setState(() => _selectedLocation = location);
                        Navigator.pop(context);
                        _applyFilters();
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedLocation = location);
                      Navigator.pop(context);
                      _applyFilters();
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showYearFilter() {
    final years = ['Year 1', 'Year 2', 'Year 3', 'Year 4', 'Year 5', 'Year 6'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Year'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Years'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedYear,
                  onChanged: (value) {
                    setState(() => _selectedYear = null);
                    Navigator.pop(context);
                    _applyFilters();
                  },
                ),
                onTap: () {
                  setState(() => _selectedYear = null);
                  Navigator.pop(context);
                  _applyFilters();
                },
              ),
              const Divider(),
              ...years.map((year) => ListTile(
                    title: Text(year),
                    leading: Radio<String?>(
                      value: year,
                      groupValue: _selectedYear,
                      onChanged: (value) {
                        setState(() => _selectedYear = year);
                        Navigator.pop(context);
                        _applyFilters();
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedYear = year);
                      Navigator.pop(context);
                      _applyFilters();
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showCategoryFilter() {
    final categories = ['student', 'associate', 'visitor'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              onTap: () {
                setState(() => _selectedCategory = null);
                Navigator.pop(context);
                _applyFilters();
              },
            ),
            ...categories.map((category) => ListTile(
                  title: Text(category[0].toUpperCase() + category.substring(1)),
                  onTap: () {
                    setState(() => _selectedCategory = category);
                    Navigator.pop(context);
                    _applyFilters();
                  },
                )),
          ],
        ),
      ),
    );
  }
}
