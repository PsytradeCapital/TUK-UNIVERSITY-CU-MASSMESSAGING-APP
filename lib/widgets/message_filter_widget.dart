import 'package:flutter/material.dart';
import '../models/attendee_model.dart';

class MessageFilterWidget extends StatefulWidget {
  final Function(MessageFilters) onFiltersChanged;
  final List<String> availableYears;
  final List<String> availableLocations;

  const MessageFilterWidget({
    Key? key,
    required this.onFiltersChanged,
    required this.availableYears,
    required this.availableLocations,
  }) : super(key: key);

  @override
  State<MessageFilterWidget> createState() => _MessageFilterWidgetState();
}

class _MessageFilterWidgetState extends State<MessageFilterWidget> {
  final Set<String> _selectedYears = {};
  final Set<String> _selectedLocations = {};
  final Set<AttendeeCategory> _selectedCategories = {};

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Filter Recipients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters())
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Category filter
            _buildCategoryFilter(),
            const SizedBox(height: 16),
            
            // Year filter (only for students)
            if (_selectedCategories.isEmpty || _selectedCategories.contains(AttendeeCategory.student))
              _buildYearFilter(),
            if (_selectedCategories.isEmpty || _selectedCategories.contains(AttendeeCategory.student))
              const SizedBox(height: 16),
            
            // Location filter
            _buildLocationFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final allCategoriesSelected = _selectedCategories.length == AttendeeCategory.values.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Category',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (allCategoriesSelected) {
                    _selectedCategories.clear();
                  } else {
                    _selectedCategories.addAll(AttendeeCategory.values);
                  }
                  _notifyFiltersChanged();
                });
              },
              icon: Icon(
                allCategoriesSelected ? Icons.clear : Icons.select_all,
                size: 16,
              ),
              label: Text(allCategoriesSelected ? 'Clear All' : 'Select All'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AttendeeCategory.values.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(_getCategoryDisplayName(category)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                  _notifyFiltersChanged();
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildYearFilter() {
    final allYearsSelected = _selectedYears.length == widget.availableYears.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Year of Study',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (allYearsSelected) {
                    _selectedYears.clear();
                  } else {
                    _selectedYears.addAll(widget.availableYears);
                  }
                  _notifyFiltersChanged();
                });
              },
              icon: Icon(
                allYearsSelected ? Icons.clear : Icons.select_all,
                size: 16,
              ),
              label: Text(allYearsSelected ? 'Clear All' : 'Select All'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.availableYears.map((year) {
            final isSelected = _selectedYears.contains(year);
            return FilterChip(
              label: Text(year),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedYears.add(year);
                  } else {
                    _selectedYears.remove(year);
                  }
                  _notifyFiltersChanged();
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationFilter() {
    final allLocationsSelected = _selectedLocations.length == widget.availableLocations.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (allLocationsSelected) {
                    _selectedLocations.clear();
                  } else {
                    _selectedLocations.addAll(widget.availableLocations);
                  }
                  _notifyFiltersChanged();
                });
              },
              icon: Icon(
                allLocationsSelected ? Icons.clear : Icons.select_all,
                size: 16,
              ),
              label: Text(allLocationsSelected ? 'Clear All' : 'Select All'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.availableLocations.map((location) {
            final isSelected = _selectedLocations.contains(location);
            return FilterChip(
              label: Text(location),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedLocations.add(location);
                  } else {
                    _selectedLocations.remove(location);
                  }
                  _notifyFiltersChanged();
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getCategoryDisplayName(AttendeeCategory category) {
    switch (category) {
      case AttendeeCategory.student:
        return 'Students';
      case AttendeeCategory.associate:
        return 'Associates';
      case AttendeeCategory.visitor:
        return 'Visitors';
    }
  }

  bool _hasActiveFilters() {
    return _selectedYears.isNotEmpty ||
           _selectedLocations.isNotEmpty ||
           _selectedCategories.isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      _selectedYears.clear();
      _selectedLocations.clear();
      _selectedCategories.clear();
      _notifyFiltersChanged();
    });
  }

  void _notifyFiltersChanged() {
    widget.onFiltersChanged(MessageFilters(
      years: _selectedYears.isEmpty ? null : _selectedYears.toList(),
      locations: _selectedLocations.isEmpty ? null : _selectedLocations.toList(),
      categories: _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
    ));
  }
}

class MessageFilters {
  final List<String>? years;
  final List<String>? locations;
  final List<AttendeeCategory>? categories;

  MessageFilters({
    this.years,
    this.locations,
    this.categories,
  });

  bool get hasFilters => years != null || locations != null || categories != null;

  int get filterCount {
    int count = 0;
    if (years != null) count += years!.length;
    if (locations != null) count += locations!.length;
    if (categories != null) count += categories!.length;
    return count;
  }

  @override
  String toString() {
    final parts = <String>[];
    if (years != null && years!.isNotEmpty) {
      parts.add('Years: ${years!.join(", ")}');
    }
    if (locations != null && locations!.isNotEmpty) {
      parts.add('Locations: ${locations!.join(", ")}');
    }
    if (categories != null && categories!.isNotEmpty) {
      final categoryNames = categories!.map((c) {
        switch (c) {
          case AttendeeCategory.student:
            return 'Students';
          case AttendeeCategory.associate:
            return 'Associates';
          case AttendeeCategory.visitor:
            return 'Visitors';
        }
      }).join(", ");
      parts.add('Categories: $categoryNames');
    }
    return parts.isEmpty ? 'No filters' : parts.join(' | ');
  }
}
