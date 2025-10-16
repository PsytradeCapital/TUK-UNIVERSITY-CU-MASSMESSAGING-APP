import 'package:flutter/material.dart';
import '../models/attendee_model.dart';
import '../services/search_engine.dart';

class AttendeeSearchWidget extends StatefulWidget {
  final Function(AttendeeModel) onAttendeeSelected;
  final String? initialQuery;
  final bool enabled;

  const AttendeeSearchWidget({
    Key? key,
    required this.onAttendeeSelected,
    this.initialQuery,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<AttendeeSearchWidget> createState() => _AttendeeSearchWidgetState();
}

class _AttendeeSearchWidgetState extends State<AttendeeSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchEngine _searchEngine = SearchEngine();
  
  List<AttendeeSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    
    // Listen to search input changes
    _searchController.addListener(_onSearchChanged);
    
    // Listen to focus changes to show/hide suggestions
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _searchEngine.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    if (query == _lastQuery) return;
    _lastQuery = query;
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }
    
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _showSuggestions = true;
    });
    
    // Perform debounced search
    _searchEngine.fuzzySearchWithDebounce(query, (results) {
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _onFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      // Delay hiding suggestions to allow for tap selection
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    } else if (_searchController.text.trim().length >= 2) {
      setState(() {
        _showSuggestions = true;
      });
    }
  }

  void _onSuggestionSelected(AttendeeSearchResult result) {
    setState(() {
      _showSuggestions = false;
      _searchController.text = result.attendee.name;
    });
    
    _searchFocusNode.unfocus();
    widget.onAttendeeSelected(result.attendee);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _showSuggestions = false;
      _isSearching = false;
      _lastQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search input field
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _searchFocusNode.hasFocus ? Theme.of(context).primaryColor : Colors.grey[300]!,
              width: _searchFocusNode.hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: 'Search for returning attendee...',
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              if (_searchResults.isNotEmpty) {
                _onSuggestionSelected(_searchResults.first);
              }
            },
          ),
        ),
        
        // Search suggestions dropdown
        if (_showSuggestions && widget.enabled)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: _buildSuggestionsContent(),
          ),
      ],
    );
  }

  Widget _buildSuggestionsContent() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
            const SizedBox(width: 8),
            const Text(
              'No matching attendees found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSuggestionItem(result);
      },
    );
  }

  Widget _buildSuggestionItem(AttendeeSearchResult result) {
    final attendee = result.attendee;
    
    return InkWell(
      onTap: () => _onSuggestionSelected(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Attendee avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                attendee.name.isNotEmpty ? attendee.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Attendee details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name with highlighted match
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      children: _buildHighlightedName(attendee.name, result.matchedText),
                    ),
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // Phone, year, location info
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        result.maskedPhoneNumber,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.school, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        attendee.yearOfStudy,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // Location and attendance count
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          attendee.location,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${attendee.attendanceCount} visits',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Similarity indicator
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Column(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: _getSimilarityColor(result.similarity),
                  ),
                  Text(
                    '${(result.similarity * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: _getSimilarityColor(result.similarity),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildHighlightedName(String fullName, String matchedText) {
    if (matchedText.isEmpty || !fullName.toLowerCase().contains(matchedText.toLowerCase())) {
      return [TextSpan(text: fullName)];
    }

    final lowerFullName = fullName.toLowerCase();
    final lowerMatchedText = matchedText.toLowerCase();
    final startIndex = lowerFullName.indexOf(lowerMatchedText);
    
    if (startIndex == -1) {
      return [TextSpan(text: fullName)];
    }

    final List<TextSpan> spans = [];
    
    // Text before match
    if (startIndex > 0) {
      spans.add(TextSpan(text: fullName.substring(0, startIndex)));
    }
    
    // Highlighted match
    spans.add(TextSpan(
      text: fullName.substring(startIndex, startIndex + matchedText.length),
      style: TextStyle(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        fontWeight: FontWeight.bold,
      ),
    ));
    
    // Text after match
    if (startIndex + matchedText.length < fullName.length) {
      spans.add(TextSpan(
        text: fullName.substring(startIndex + matchedText.length),
      ));
    }
    
    return spans;
  }

  Color _getSimilarityColor(double similarity) {
    if (similarity >= 0.8) return Colors.green;
    if (similarity >= 0.6) return Colors.orange;
    return Colors.red;
  }
}