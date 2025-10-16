import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/security_service.dart';
import '../screens/pin_auth_screen.dart';
import '../screens/pin_setup_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthenticationStatus();
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
      final isPinSet = await SecurityService.isPinSet();
      setState(() {
        _isPinSet = isPinSet;
        _isAuthenticated = !isPinSet; // If no PIN is set, consider authenticated
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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