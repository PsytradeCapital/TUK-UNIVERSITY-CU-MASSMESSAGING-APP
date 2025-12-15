import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity
/// Provides real-time connectivity status and connection restoration detection
class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  // Connectivity plugin instance
  final Connectivity _connectivity = Connectivity();

  // Current connectivity state
  ConnectivityResult _currentConnectivity = ConnectivityResult.none;
  bool _isOnline = false;
  DateTime? _lastConnectionTime;
  DateTime? _lastDisconnectionTime;

  // Stream controllers
  final StreamController<bool> _connectivityController = 
      StreamController<bool>.broadcast();
  final StreamController<ConnectivityResult> _connectivityResultController = 
      StreamController<ConnectivityResult>.broadcast();

  // Subscription to connectivity changes
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Initialization flag
  bool _isInitialized = false;

  /// Initialize the connectivity service
  /// Should be called once during app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get initial connectivity status
      _currentConnectivity = await _connectivity.checkConnectivity();
      _isOnline = _isConnectivityOnline(_currentConnectivity);
      
      if (_isOnline) {
        _lastConnectionTime = DateTime.now();
      } else {
        _lastDisconnectionTime = DateTime.now();
      }

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
        },
      );

      _isInitialized = true;
      debugPrint('ConnectivityService initialized - Current status: ${_isOnline ? 'Online' : 'Offline'} ($_currentConnectivity)');
    } catch (e) {
      debugPrint('Failed to initialize ConnectivityService: $e');
    }
  }

  /// Check if device is currently online
  bool isOnline() {
    return _isOnline;
  }

  /// Check if device is currently offline
  bool isOffline() {
    return !_isOnline;
  }

  /// Get current connectivity result
  ConnectivityResult getCurrentConnectivity() {
    return _currentConnectivity;
  }

  /// Get detailed connectivity status
  ConnectivityStatus getConnectivityStatus() {
    return ConnectivityStatus(
      isOnline: _isOnline,
      connectivityResult: _currentConnectivity,
      lastConnectionTime: _lastConnectionTime,
      lastDisconnectionTime: _lastDisconnectionTime,
    );
  }

  /// Stream of connectivity status (true = online, false = offline)
  Stream<bool> connectivityStream() {
    return _connectivityController.stream;
  }

  /// Stream of detailed connectivity results
  Stream<ConnectivityResult> connectivityResultStream() {
    return _connectivityResultController.stream;
  }

  /// Stream that emits when connection is restored (goes from offline to online)
  Stream<DateTime> connectionRestoredStream() {
    return _connectivityController.stream
        .where((isOnline) => isOnline)
        .map((_) => DateTime.now());
  }

  /// Stream that emits when connection is lost (goes from online to offline)
  Stream<DateTime> connectionLostStream() {
    return _connectivityController.stream
        .where((isOnline) => !isOnline)
        .map((_) => DateTime.now());
  }

  /// Manually refresh connectivity status
  /// Useful for checking connectivity after network operations fail
  Future<bool> refreshConnectivity() async {
    try {
      final newConnectivity = await _connectivity.checkConnectivity();
      _onConnectivityChanged(newConnectivity);
      return _isOnline;
    } catch (e) {
      debugPrint('Failed to refresh connectivity: $e');
      return _isOnline;
    }
  }

  /// Wait for connection to be restored
  /// Returns immediately if already online
  /// Times out after specified duration
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isOnline) return true;

    try {
      await connectionRestoredStream()
          .timeout(timeout)
          .first;
      return true;
    } on TimeoutException {
      debugPrint('Timeout waiting for connection restoration');
      return false;
    } catch (e) {
      debugPrint('Error waiting for connection: $e');
      return false;
    }
  }

  /// Get human-readable connectivity description
  String getConnectivityDescription() {
    if (!_isOnline) {
      return 'No internet connection';
    }

    switch (_currentConnectivity) {
      case ConnectivityResult.wifi:
        return 'Connected via Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Connected via mobile data';
      case ConnectivityResult.ethernet:
        return 'Connected via ethernet';
      case ConnectivityResult.bluetooth:
        return 'Connected via Bluetooth';
      case ConnectivityResult.vpn:
        return 'Connected via VPN';
      case ConnectivityResult.other:
        return 'Connected via other network';
      case ConnectivityResult.none:
      default:
        return 'No internet connection';
    }
  }

  /// Check if connectivity type is metered (mobile data)
  bool isMeteredConnection() {
    return _currentConnectivity == ConnectivityResult.mobile;
  }

  /// Check if connectivity type is unmetered (Wi-Fi, ethernet)
  bool isUnmeteredConnection() {
    return _currentConnectivity == ConnectivityResult.wifi ||
           _currentConnectivity == ConnectivityResult.ethernet;
  }

  // Private methods

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final previousConnectivity = _currentConnectivity;
    final wasOnline = _isOnline;

    _currentConnectivity = result;
    _isOnline = _isConnectivityOnline(result);

    // Update timestamps
    if (_isOnline && !wasOnline) {
      _lastConnectionTime = DateTime.now();
      debugPrint('Connection restored: $_currentConnectivity at $_lastConnectionTime');
    } else if (!_isOnline && wasOnline) {
      _lastDisconnectionTime = DateTime.now();
      debugPrint('Connection lost: $_currentConnectivity at $_lastDisconnectionTime');
    }

    // Emit events if connectivity status changed
    if (wasOnline != _isOnline) {
      _connectivityController.add(_isOnline);
    }

    // Always emit connectivity result changes
    if (previousConnectivity != _currentConnectivity) {
      _connectivityResultController.add(_currentConnectivity);
    }

    debugPrint('Connectivity changed: $previousConnectivity -> $_currentConnectivity (${_isOnline ? 'Online' : 'Offline'})');
  }

  /// Determine if connectivity result indicates online status
  bool _isConnectivityOnline(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.vpn:
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.other:
        return true;
      case ConnectivityResult.none:
      default:
        return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _connectivityResultController.close();
    _isInitialized = false;
    debugPrint('ConnectivityService disposed');
  }
}

/// Detailed connectivity status model
class ConnectivityStatus {
  final bool isOnline;
  final ConnectivityResult connectivityResult;
  final DateTime? lastConnectionTime;
  final DateTime? lastDisconnectionTime;

  ConnectivityStatus({
    required this.isOnline,
    required this.connectivityResult,
    this.lastConnectionTime,
    this.lastDisconnectionTime,
  });

  /// Get duration since last connection
  Duration? get timeSinceLastConnection {
    if (lastConnectionTime == null) return null;
    return DateTime.now().difference(lastConnectionTime!);
  }

  /// Get duration since last disconnection
  Duration? get timeSinceLastDisconnection {
    if (lastDisconnectionTime == null) return null;
    return DateTime.now().difference(lastDisconnectionTime!);
  }

  /// Get human-readable status description
  String get description {
    if (!isOnline) {
      return 'Offline';
    }

    switch (connectivityResult) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
      default:
        return 'No Connection';
    }
  }

  @override
  String toString() {
    return 'ConnectivityStatus(isOnline: $isOnline, '
           'result: $connectivityResult, '
           'lastConnection: $lastConnectionTime, '
           'lastDisconnection: $lastDisconnectionTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectivityStatus &&
           other.isOnline == isOnline &&
           other.connectivityResult == connectivityResult &&
           other.lastConnectionTime == lastConnectionTime &&
           other.lastDisconnectionTime == lastDisconnectionTime;
  }

  @override
  int get hashCode {
    return Object.hash(
      isOnline,
      connectivityResult,
      lastConnectionTime,
      lastDisconnectionTime,
    );
  }
}

/// Exception for connectivity-related errors
class ConnectivityException implements Exception {
  final String message;
  final ConnectivityResult? connectivityResult;

  ConnectivityException(this.message, {this.connectivityResult});

  @override
  String toString() => 'ConnectivityException: $message';
}