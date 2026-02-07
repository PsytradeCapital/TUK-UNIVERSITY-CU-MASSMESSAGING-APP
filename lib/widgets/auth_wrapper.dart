import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/security_service.dart';
import '../services/auth_service.dart';
import '../services/initial_sync_service.dart';
import '../screens/pin_auth_screen.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/login_screen.dart';
import '../screens/pending_approval_screen.dart';
import '../screens/initial_sync_screen.dart';
import '../providers/app_state_provider.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;
  
  const AuthWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isPinSet = false;
  bool _isLoading = true;
  bool _isFirebaseAuthenticated = false;
  bool _isUserApproved = false;
  bool _needsInitialSync = false;
  final AuthService _authService = AuthService();
  final InitialSyncService _initialSyncService = InitialSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthenticationStatus();
    
    // Listen to Firebase auth state changes
    _authService.authStateChanges().listen((user) {
      if (mounted) {
        _checkAuthenticationStatus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Update app state provider
    if (mounted) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.updateAppLifecycleState(state == AppLifecycleState.resumed);
    }
    
    switch (state) {
      case AppLifecycleState.resumed:
        _checkAutoLock();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        SecurityService.updateLastActiveTime();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      // Check Firebase authentication
      final firebaseUser = _authService.getCurrentUser();
      final isFirebaseAuth = firebaseUser != null;
      
      // Check user approval status if Firebase authenticated
      bool isApproved = false;
      bool needsSync = false;
      if (isFirebaseAuth) {
        isApproved = await _authService.isUserApproved();
        
        // Check if initial sync is needed
        if (isApproved) {
          needsSync = await _initialSyncService.needsInitialSync();
        }
      }
      
      // Check PIN status
      final isPinSet = await SecurityService.isPinSet();
      
      setState(() {
        _isFirebaseAuthenticated = isFirebaseAuth;
        _isUserApproved = isApproved;
        _needsInitialSync = needsSync;
        _isPinSet = isPinSet;
        _isAuthenticated = !isPinSet; // If no PIN is set, consider authenticated for PIN
        _isLoading = false;
      });
      
      if (isPinSet) {
        await _checkAutoLock();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
        _isPinSet = false;
        _isFirebaseAuthenticated = false;
        _isUserApproved = false;
        _needsInitialSync = false;
      });
      
      // Report error to app state provider
      if (mounted) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        appState.setGlobalError('Authentication check failed: $e', context: 'AuthWrapper');
      }
    }
  }

  Future<void> _checkAutoLock() async {
    if (!_isPinSet) return;
    
    try {
      final shouldLock = await SecurityService.shouldAutoLock();
      if (shouldLock && _isAuthenticated) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onPinSetup(bool success) {
    if (success) {
      setState(() {
        _isPinSet = true;
        _isAuthenticated = true;
      });
    }
  }

  void _onSyncComplete() {
    setState(() {
      _needsInitialSync = false;
    });
  }

  void _onSyncFailed() {
    // Restart the app or show error
    setState(() {
      _isLoading = true;
    });
    _checkAuthenticationStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Check Firebase authentication first
    if (!_isFirebaseAuthenticated) {
      return const LoginScreen();
    }

    // Check user approval status
    if (!_isUserApproved) {
      // Auto-approve martinmbugua300@gmail.com
      final user = _authService.getCurrentUser();
      if (user?.email?.toLowerCase() == 'martinmbugua300@gmail.com') {
        // Force approval for this specific email
        setState(() {
          _isUserApproved = true;
        });
      } else {
        return const PendingApprovalScreen();
      }
    }

    // Check if initial sync is needed
    if (_needsInitialSync) {
      return InitialSyncScreen(
        onSyncComplete: _onSyncComplete,
        onSyncFailed: _onSyncFailed,
      );
    }

    // Then check PIN authentication
    if (!_isPinSet) {
      return PinSetupScreen(
        isChangingPin: false,
      );
    }

    if (!_isAuthenticated) {
      return PinAuthScreen(
        onAuthenticated: _onAuthenticated,
      );
    }

    return widget.child;
  }
}