import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee_model.dart';
import '../repositories/offline_first_attendee_repository.dart';
import '../providers/service_session_provider.dart';
import '../services/registration_service.dart';
import '../theme/app_theme.dart';

class BulkRegistrationScreen extends StatefulWidget {
  const BulkRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<BulkRegistrationScreen> createState() => _BulkRegistrationScreenState();
}

class _BulkRegistrationScreenState extends State<BulkRegistrationScreen> {
  final _attendeeRepository = OfflineFirstAttendeeRepository();
  final _registrationService = RegistrationService();
  final _searchController = TextEditingController();
  
  List<AttendeeModel> _allAttendees = [];
  List<AttendeeModel> _filteredAttendees = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  bool _isRegistering = false;
  String? _errorMessage;
  
  // Filters
  String? _selectedLocation;
  String? _selectedYear;
  String? _selectedCategory;
  List<String> _locations = [];
  List<String> _years = [];
  
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadAllAttendees();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAttendees() async {
    if (_allAttendees.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final attendees = await _attendeeRepository.getAllAttendees();
      attendees.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final locations = attendees.map((a) => a.location).toSet().toList();
      locations.sort();

      final years = attendees
          .where((a) => a.yearOfStudy != null && a.yearOfStudy!.isNotEmpty)
          .map((a) => a.yearOfStudy!)
          .toSet()
          .toList();
      years.sort();

      if (!mounted) return;
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
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredAttendees = _allAttendees.where((attendee) {
        final matchesSearch = query.isEmpty ||
            attendee.name.toLowerCase().contains(query) ||
            attendee.phoneNumber.contains(query);

        final matchesLocation = _selectedLocation == null ||
            attendee.location == _selectedLocation;

        final matchesYear = _selectedYear == null ||
            attendee.yearOfStudy == _selectedYear;

        final matchesCategory = _selectedCategory == null ||
            attendee.category.toString().split('.').last == _selectedCategory;

        return matchesSearch && matchesLocation && matchesYear && matchesCategory;
      }).toList();

      _filteredAttendees.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedIds = _filteredAttendees.where((a) => a.id != null).map((a) => a.id!).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _selectAll = _selectedIds.length == _filteredAttendees.length;
    });
  }

  Future<void> _registerSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    final sessionProvider = Provider.of<ServiceSessionProvider>(context, listen: false);
    
    if (!sessionProvider.hasActiveService) {
      final startNew = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Active Service'),
          content: const Text('You need to start a new service session first. Start now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Service'),
            ),
          ],
        ),
      );

      if (startNew != true) return;

      try {
        await sessionProvider.startNewService();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start service: $e')),
        );
        return;
      }
    }

    final selectedAttendees = _allAttendees.where((a) => a.id != null && _selectedIds.contains(a.id!)).toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Registration'),
        content: Text(
          'Register ${selectedAttendees.length} members to the current service session?\n\n'
          'This will mark them as present for today\'s service.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Register All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRegistering = true);

    int registered = 0;
    int failed = 0;

    for (final attendee in selectedAttendees) {
      try {
        final result = await _registrationService.registerReturningAttendee(attendee);
        if (result.isSuccess) {
          registered++;
        } else {
          failed++;
        }
      } catch (e) {
        failed++;
      }
    }

    setState(() => _isRegistering = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Registered: $registered'),
            if (failed > 0) Text('❌ Failed: $failed'),
            const SizedBox(height: 16),
            const Text(
              'Members have been added to the current service session. You can now message them from the Messaging tab.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Registration'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(_selectedLocation ?? 'Location'),
                        selected: _selectedLocation != null,
                        onSelected: (_) => _showLocationFilter(),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(_selectedYear ?? 'Year'),
                        selected: _selectedYear != null,
                        onSelected: (_) => _showYearFilter(),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(_selectedCategory ?? 'Category'),
                        selected: _selectedCategory != null,
                        onSelected: (_) => _showCategoryFilter(),
                      ),
                      if (_selectedLocation != null || _selectedYear != null || _selectedCategory != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedLocation = null;
                              _selectedYear = null;
                              _selectedCategory = null;
                            });
                            _applyFilters();
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Select all checkbox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: (_) => _toggleSelectAll(),
                ),
                const Text('Select All'),
                const Spacer(),
                Text('${_filteredAttendees.length} members'),
              ],
            ),
          ),

          // Members list
          Expanded(
            child: _buildMembersList(),
          ),

          // Register button
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _registerSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isRegistering
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
                            SizedBox(width: 12),
                            Text('Registering...'),
                          ],
                        )
                      : Text('Register ${_selectedIds.length} Members to Service'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
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
              onPressed: _loadAllAttendees,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredAttendees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No members found'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredAttendees.length,
      itemBuilder: (context, index) {
        final attendee = _filteredAttendees[index];
        final isSelected = attendee.id != null && _selectedIds.contains(attendee.id!);

        return CheckboxListTile(
          value: isSelected,
          onChanged: attendee.id != null ? (_) => _toggleSelection(attendee.id!) : null,
          title: Text(attendee.name),
          subtitle: Text(
            '${attendee.phoneNumber}\n${attendee.location} • ${attendee.category.toString().split('.').last}${attendee.yearOfStudy.isNotEmpty ? " • ${attendee.yearOfStudy}" : ""}',
          ),
          secondary: CircleAvatar(
            backgroundColor: AppTheme.primaryBlue,
            child: Text(
              attendee.name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          isThreeLine: true,
        );
      },
    );
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
                onTap: () {
                  setState(() => _selectedLocation = null);
                  Navigator.pop(context);
                  _applyFilters();
                },
              ),
              ..._locations.map((location) => ListTile(
                    title: Text(location),
                    onTap: () {
                      setState(() => _selectedLocation = location);
                      Navigator.pop(context);
                      _applyFilters();
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showYearFilter() {
    final years = ['Year 1', 'Year 2', 'Year 3', 'Year 4', 'Year 5', 'Year 6'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Year'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Years'),
              onTap: () {
                setState(() => _selectedYear = null);
                Navigator.pop(context);
                _applyFilters();
              },
            ),
            ...years.map((year) => ListTile(
                  title: Text(year),
                  onTap: () {
                    setState(() => _selectedYear = year);
                    Navigator.pop(context);
                    _applyFilters();
                  },
                )),
          ],
        ),
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
