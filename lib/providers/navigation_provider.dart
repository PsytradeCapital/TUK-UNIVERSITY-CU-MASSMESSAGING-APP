import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Navigation provider for managing app navigation state and flow
class NavigationProvider extends ChangeNotifier {
  static final NavigationProvider _instance = NavigationProvider._internal();
  factory NavigationProvider() => _instance;
  NavigationProvider._internal();

  // Navigation state
  int _currentIndex = 0;
  List<String> _navigationHistory = [];
  Map<int, GlobalKey<NavigatorState>> _tabNavigatorKeys = {};
  
  // Tab state preservation
  Map<int, Map<String, dynamic>> _tabStates = {};
  
  // Navigation constraints
  bool _canNavigateToMessaging = false;
  bool _canNavigateToReports = true;
  bool _canNavigateToSettings = true;

  // Getters
  int get currentIndex => _currentIndex;
  List<String> get navigationHistory => List.unmodifiable(_navigationHistory);
  bool get canNavigateToMessaging => _canNavigateToMessaging;
  bool get canNavigateToReports => _canNavigateToReports;
  bool get canNavigateToSettings => _canNavigateToSettings;

  /// Initialize tab navigator keys
  void initializeTabNavigators() {
    for (int i = 0; i < 4; i++) {
      _tabNavigatorKeys[i] = GlobalKey<NavigatorState>();
    }
  }

  /// Get navigator key for specific tab
  GlobalKey<NavigatorState>? getTabNavigatorKey(int index) {
    return _tabNavigatorKeys[index];
  }

  /// Navigate to specific tab
  void navigateToTab(int index, {Map<String, dynamic>? arguments}) {
    if (index < 0 || index > 3) return;
    
    // Check navigation constraints
    if (!_canNavigateToTab(index)) {
      debugPrint('Navigation to tab $index is restricted');
      return;
    }

    final previousIndex = _currentIndex;
    _currentIndex = index;
    
    // Save previous tab state
    _saveTabState(previousIndex);
    
    // Restore new tab state
    _restoreTabState(index, arguments);
    
    // Add to navigation history
    _addToNavigationHistory('tab_$index');
    
    notifyListeners();
    debugPrint('Navigated to tab $index');
  }

  /// Check if navigation to specific tab is allowed
  bool _canNavigateToTab(int index) {
    switch (index) {
      case 0: // Registration
        return true;
      case 1: // Messaging
        return _canNavigateToMessaging;
      case 2: // Reports
        return _canNavigateToReports;
      case 3: // Settings
        return _canNavigateToSettings;
      default:
        return false;
    }
  }

  /// Update navigation constraints based on app state
  void updateNavigationConstraints({
    bool? canNavigateToMessaging,
    bool? canNavigateToReports,
    bool? canNavigateToSettings,
  }) {
    bool hasChanges = false;
    
    if (canNavigateToMessaging != null && _canNavigateToMessaging != canNavigateToMessaging) {
      _canNavigateToMessaging = canNavigateToMessaging;
      hasChanges = true;
    }
    
    if (canNavigateToReports != null && _canNavigateToReports != canNavigateToReports) {
      _canNavigateToReports = canNavigateToReports;
      hasChanges = true;
    }
    
    if (canNavigateToSettings != null && _canNavigateToSettings != canNavigateToSettings) {
      _canNavigateToSettings = canNavigateToSettings;
      hasChanges = true;
    }
    
    if (hasChanges) {
      notifyListeners();
      debugPrint('Navigation constraints updated');
    }
  }

  /// Save current tab state
  void _saveTabState(int tabIndex, [Map<String, dynamic>? additionalState]) {
    _tabStates[tabIndex] = {
      'timestamp': DateTime.now().toIso8601String(),
      'scrollPosition': 0.0, // Can be updated by screens
      ...?additionalState,
    };
  }

  /// Restore tab state
  void _restoreTabState(int tabIndex, [Map<String, dynamic>? arguments]) {
    final savedState = _tabStates[tabIndex];
    if (savedState != null) {
      // Tab state restoration logic can be implemented here
      debugPrint('Restoring state for tab $tabIndex: $savedState');
    }
    
    if (arguments != null) {
      // Handle navigation arguments
      debugPrint('Tab $tabIndex navigation arguments: $arguments');
    }
  }

  /// Add to navigation history
  void _addToNavigationHistory(String route) {
    _navigationHistory.insert(0, route);
    
    // Keep only last 20 navigation entries
    if (_navigationHistory.length > 20) {
      _navigationHistory = _navigationHistory.take(20).toList();
    }
  }

  /// Handle back navigation
  bool handleBackNavigation() {
    // Check if current tab can handle back navigation
    final currentNavigatorKey = _tabNavigatorKeys[_currentIndex];
    if (currentNavigatorKey?.currentState?.canPop() == true) {
      currentNavigatorKey!.currentState!.pop();
      return true;
    }
    
    // If no back navigation in current tab, try to go to previous tab
    if (_navigationHistory.length > 1) {
      final previousRoute = _navigationHistory[1];
      if (previousRoute.startsWith('tab_')) {
        final tabIndex = int.tryParse(previousRoute.split('_')[1]);
        if (tabIndex != null && tabIndex != _currentIndex) {
          navigateToTab(tabIndex);
          return true;
        }
      }
    }
    
    return false;
  }

  /// Get tab badge count (for showing notifications/counts on tabs)
  int getTabBadgeCount(int tabIndex) {
    switch (tabIndex) {
      case 1: // Messaging tab
        // This will be updated by ServiceSessionProvider
        return 0;
      default:
        return 0;
    }
  }

  /// Update tab badge count
  void updateTabBadgeCount(int tabIndex, int count) {
    // Implementation for updating badge counts
    notifyListeners();
  }

  /// Get tab enabled state
  bool isTabEnabled(int tabIndex) {
    return _canNavigateToTab(tabIndex);
  }

  /// Reset navigation state
  void resetNavigationState() {
    _currentIndex = 0;
    _navigationHistory.clear();
    _tabStates.clear();
    _canNavigateToMessaging = false;
    _canNavigateToReports = true;
    _canNavigateToSettings = true;
    notifyListeners();
    debugPrint('Navigation state reset');
  }

  /// Get navigation state summary
  Map<String, dynamic> getNavigationStateSummary() {
    return {
      'currentIndex': _currentIndex,
      'navigationHistoryCount': _navigationHistory.length,
      'recentHistory': _navigationHistory.take(5).toList(),
      'tabStatesCount': _tabStates.length,
      'canNavigateToMessaging': _canNavigateToMessaging,
      'canNavigateToReports': _canNavigateToReports,
      'canNavigateToSettings': _canNavigateToSettings,
    };
  }

  /// Handle deep link navigation
  void handleDeepLink(String route, {Map<String, dynamic>? arguments}) {
    debugPrint('Handling deep link: $route with arguments: $arguments');
    
    // Parse route and navigate accordingly
    if (route.startsWith('/tab/')) {
      final tabIndex = int.tryParse(route.split('/')[2]);
      if (tabIndex != null) {
        navigateToTab(tabIndex, arguments: arguments);
      }
    }
    
    _addToNavigationHistory('deeplink_$route');
  }

  /// Save scroll position for current tab
  void saveScrollPosition(int tabIndex, double position) {
    if (_tabStates[tabIndex] == null) {
      _tabStates[tabIndex] = {};
    }
    _tabStates[tabIndex]!['scrollPosition'] = position;
  }

  /// Get saved scroll position for tab
  double getSavedScrollPosition(int tabIndex) {
    return _tabStates[tabIndex]?['scrollPosition'] ?? 0.0;
  }

  /// Check if tab has saved state
  bool hasTabState(int tabIndex) {
    return _tabStates.containsKey(tabIndex);
  }

  /// Clear tab state
  void clearTabState(int tabIndex) {
    _tabStates.remove(tabIndex);
    notifyListeners();
  }

  /// Get current tab name
  String getCurrentTabName() {
    switch (_currentIndex) {
      case 0:
        return 'Registration';
      case 1:
        return 'Messaging';
      case 2:
        return 'Reports';
      case 3:
        return 'Settings';
      default:
        return 'Unknown';
    }
  }

  /// Check if current tab is the specified tab
  bool isCurrentTab(int tabIndex) {
    return _currentIndex == tabIndex;
  }
}