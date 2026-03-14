import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/global_error_handler.dart';
import 'screens/home_screen.dart';
import 'providers/service_session_provider.dart';
import 'providers/app_state_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/error_handling_service.dart';
import 'services/recovery_service.dart';
import 'services/connectivity_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/real_time_sync_service.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/background_sync_service.dart';
import 'theme/app_theme.dart';

/// Configure Firestore settings for offline persistence and performance
Future<void> _configureFirestore() async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Enable offline persistence
    await firestore.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
    
    // Configure cache settings
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    debugPrint('Firestore offline persistence enabled');
  } catch (e) {
    debugPrint('Firestore configuration error: $e');
    // Continue even if offline persistence fails
  }
}

void main() {
  // Set up global error handling
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase with proper options
    bool firebaseInitialized = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      debugPrint('Firebase initialized successfully');
      
      // Configure Firestore settings only if Firebase is initialized
      await _configureFirestore();
      debugPrint('Firestore configured successfully');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      debugPrint('App will run in offline mode');
      firebaseInitialized = false;
      // Continue without Firebase - app will work in offline mode
    }
    
    // Initialize services with Firebase availability check
    try {
      // Initialize Analytics Service only if Firebase is available
      if (firebaseInitialized) {
        final analyticsService = AnalyticsService();
        await analyticsService.initialize();
        debugPrint('AnalyticsService initialized successfully');
        
        // Track app open event
        await analyticsService.trackAppOpen();
      }
    } catch (e) {
      debugPrint('Analytics initialization error: $e');
    }
    
    // Initialize Auth Service with offline fallback
    try {
      final authService = AuthService();
      await authService.initialize();
      debugPrint('AuthService initialized successfully');
    } catch (e) {
      debugPrint('Auth service initialization error: $e');
    }
    
    // Initialize connectivity and sync services with Firebase check
    try {
      final connectivityService = ConnectivityService();
      await connectivityService.initialize();
      debugPrint('ConnectivityService initialized successfully');
      
      if (firebaseInitialized) {
        final cloudSyncService = CloudSyncService();
        await cloudSyncService.initialize();
        debugPrint('CloudSyncService initialized successfully');

        // DISABLED: Real-time sync causes permission errors and delays
        // final realTimeSyncService = RealTimeSyncService();
        // await realTimeSyncService.initialize();
        // debugPrint('RealTimeSyncService initialized successfully');
        
        // DISABLED: Background sync causes permission errors
        // Uncomment when Firebase permissions are fixed
        // final backgroundSyncService = BackgroundSyncService();
        // Future.delayed(const Duration(seconds: 5), () {
        //   try {
        //     backgroundSyncService.start();
        //     debugPrint('BackgroundSyncService started successfully (delayed)');
        //   } catch (e) {
        //     debugPrint('BackgroundSyncService start error: $e');
        //   }
        // });
      } else {
        debugPrint('Cloud services disabled - Firebase not available');
      }
    } catch (e) {
      debugPrint('Service initialization error: $e');
    }
    
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
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        appStateProvider.updateAppLifecycleState(false);
        _handleAppPaused();
        break;
    }
  }

  /// Handle app resumed - refresh connectivity and trigger sync if needed
  void _handleAppResumed() {
    final connectivityService = ConnectivityService();
    final cloudSyncService = CloudSyncService();
    final analyticsService = AnalyticsService();
    
    // Track app foreground event
    analyticsService.trackAppForeground();
    
    // Refresh connectivity status
    connectivityService.refreshConnectivity().then((isOnline) {
      if (isOnline && cloudSyncService.isAutoSyncEnabled()) {
        // Trigger sync after a short delay to allow connection to stabilize
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            await cloudSyncService.syncFromCloud();
            await cloudSyncService.syncToCloud();
          } catch (e) {
            debugPrint('Auto-sync on app resume failed: $e');
          }
        });
      }
    });
  }

  /// Handle app paused/backgrounded
  void _handleAppPaused() {
    final analyticsService = AnalyticsService();
    
    // Track app background event
    analyticsService.trackAppBackground();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}