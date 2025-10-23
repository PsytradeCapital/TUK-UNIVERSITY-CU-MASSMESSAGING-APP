import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'widgets/auth_wrapper.dart';
import 'widgets/global_error_handler.dart';
import 'screens/home_screen.dart';
import 'providers/service_session_provider.dart';
import 'providers/app_state_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/error_handling_service.dart';
import 'services/recovery_service.dart';
import 'theme/app_theme.dart';

void main() {
  // Set up global error handling
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize error handling service
    final errorHandlingService = ErrorHandlingService();
    final appStateProvider = AppStateProvider();
    errorHandlingService.initialize(appStateProvider);
    
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      errorHandlingService.handleError(details.exception, details.stack, context: 'FlutterError');
    };
    
    // Check if recovery is needed
    final recoveryService = RecoveryService();
    final needsRecovery = await recoveryService.needsRecovery();
    
    if (needsRecovery) {
      debugPrint('App recovery needed, performing quick recovery');
      await recoveryService.performQuickRecovery(appStateProvider: appStateProvider);
    }
    
    runApp(const ChristianUnionAttendanceApp());
  }, (error, stackTrace) {
    // Handle uncaught errors
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
    
    // Report to crash reporting service
    CrashReportingService().reportCrash(error, stackTrace);
    
    // Handle through error handling service
    ErrorHandlingService().handleUnhandledException(error, stackTrace);
  });
}

class ChristianUnionAttendanceApp extends StatelessWidget {
  const ChristianUnionAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppStateProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => ServiceSessionProvider()),
      ],
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'TUK CU Mass Messaging App',
            theme: AppTheme.lightTheme,
            // Add global error handling and loading overlay
            home: GlobalErrorHandler(
              child: LoadingOverlay(
                child: AuthWrapper(
                  child: Consumer<NavigationProvider>(
                    builder: (context, navigationProvider, child) {
                      // Initialize tab navigators on first build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        navigationProvider.initializeTabNavigators();
                      });
                      
                      return const HomeScreen();
                    },
                  ),
                ),
              ),
            ),
            // Handle app lifecycle changes
            builder: (context, child) {
              return _AppLifecycleHandler(child: child!);
            },
          );
        },
      ),
    );
  }
}

/// Widget to handle app lifecycle changes
class _AppLifecycleHandler extends StatefulWidget {
  final Widget child;
  
  const _AppLifecycleHandler({required this.child});

  @override
  State<_AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<_AppLifecycleHandler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        appStateProvider.updateAppLifecycleState(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        appStateProvider.updateAppLifecycleState(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}