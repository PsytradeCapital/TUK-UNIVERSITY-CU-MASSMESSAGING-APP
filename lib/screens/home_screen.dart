import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'registration_screen.dart';
import 'messaging_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import '../providers/service_session_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/global_error_handler.dart';
import '../widgets/offline_handler.dart';
import '../widgets/sync_status_widget.dart';
import '../services/recovery_service.dart';
import '../utils/accessibility_utils.dart';
import '../utils/responsive_utils.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load any existing active service session on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final appState = context.read<AppStateProvider>();
    final navigationProvider = context.read<NavigationProvider>();
    final sessionProvider = context.read<ServiceSessionProvider>();

    try {
      appState.setGlobalLoading(true);
      
      // Load active service session
      await sessionProvider.loadActiveService();
      
      // Update navigation constraints based on session state
      navigationProvider.updateNavigationConstraints(
        canNavigateToMessaging: sessionProvider.hasActiveService && sessionProvider.attendeeCount > 0,
      );
      
      // Create recovery checkpoint
      final recoveryService = RecoveryService();
      await recoveryService.createRecoveryCheckpoint(sessionProvider: sessionProvider);
      
    } catch (e) {
      appState.setGlobalError('Failed to initialize app: $e', context: 'HomeScreen');
      
      // Try recovery if initialization fails
      await _performRecovery();
    } finally {
      appState.setGlobalLoading(false);
    }
  }

  Future<void> _performRecovery() async {
    final appState = context.read<AppStateProvider>();
    final sessionProvider = context.read<ServiceSessionProvider>();
    
    try {
      final recoveryService = RecoveryService();
      final result = await recoveryService.performRecovery(
        appStateProvider: appState,
        sessionProvider: sessionProvider,
      );
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App recovered successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        appState.setGlobalError('Recovery failed: ${result.errors}', context: 'HomeScreen');
      }
    } catch (e) {
      appState.setGlobalError('Recovery process failed: $e', context: 'HomeScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ServiceSessionProvider, NavigationProvider, AppStateProvider>(
      builder: (context, sessionProvider, navigationProvider, appState, child) {
        // Update navigation constraints when session changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigationProvider.updateNavigationConstraints(
            canNavigateToMessaging: sessionProvider.hasActiveService && sessionProvider.attendeeCount > 0,
          );
        });

        final List<Widget> screens = [
          ErrorBoundary(
            context: 'RegistrationScreen',
            child: ScreenErrorHandler(
              screenName: 'Registration',
              child: ScreenLoadingIndicator(
                screenName: 'Registration',
                child: const RegistrationScreen(),
              ),
            ),
          ),
          ErrorBoundary(
            context: 'MessagingScreen',
            child: ScreenErrorHandler(
              screenName: 'Messaging',
              child: ScreenLoadingIndicator(
                screenName: 'Messaging',
                child: MessagingScreen(
                  attendees: sessionProvider.currentAttendees,
                  serviceId: sessionProvider.currentService?.serviceId ?? 0,
                ),
              ),
            ),
          ),
          ErrorBoundary(
            context: 'ReportsScreen',
            child: ScreenErrorHandler(
              screenName: 'Reports',
              child: ScreenLoadingIndicator(
                screenName: 'Reports',
                child: const ReportsScreen(),
              ),
            ),
          ),
          ErrorBoundary(
            context: 'SettingsScreen',
            child: ScreenErrorHandler(
              screenName: 'Settings',
              child: ScreenLoadingIndicator(
                screenName: 'Settings',
                child: const SettingsScreen(),
              ),
            ),
          ),
        ];

        return WillPopScope(
          onWillPop: () async {
            return !navigationProvider.handleBackNavigation();
          },
          child: OfflineHandler(
            child: Scaffold(
            appBar: AppBar(
              title: const Text('TUK CU Mass Messaging'),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              actions: [
                // Sync status indicator in app bar
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SyncStatusIndicator(
                    onTap: () => _showSyncStatusDialog(context),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Sync status widget at top of screen
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: const SyncStatusWidget(
                    showDetails: false,
                    showLastSyncTime: true,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: navigationProvider.currentIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildAccessibleBottomNavigationBar(
              context, 
              navigationProvider, 
              sessionProvider
            ),
            // Add floating action button for quick actions
            floatingActionButton: _buildFloatingActionButton(context, sessionProvider, navigationProvider),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(
    BuildContext context, 
    ServiceSessionProvider sessionProvider, 
    NavigationProvider navigationProvider
  ) {
    // Show different FAB based on current tab and state
    switch (navigationProvider.currentIndex) {
      case 0: // Registration tab
        if (!sessionProvider.hasActiveService) {
          return AccessibilityUtils.createAccessibleFAB(
            child: ResponsiveUtils.isMobile(context) 
              ? const Icon(Icons.play_arrow)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 8),
                    Text('Start'),
                  ],
                ),
            label: 'Start new service session',
            hint: 'Tap to begin registering attendees for a new service',
            onPressed: () {
              AccessibilityUtils.provideHapticFeedback(HapticFeedbackType.mediumImpact);
              _startNewService(context);
            },
            backgroundColor: AppTheme.secondaryGreen,
          );
        }
        break;
      case 1: // Messaging tab
        if (sessionProvider.hasActiveService && sessionProvider.attendeeCount > 0) {
          return AccessibilityUtils.createAccessibleFAB(
            child: const Icon(Icons.send),
            label: 'Quick send message',
            hint: 'Tap to open message composition dialog',
            onPressed: () {
              AccessibilityUtils.provideHapticFeedback(HapticFeedbackType.mediumImpact);
              _showQuickSendDialog(context);
            },
            backgroundColor: AppTheme.primaryBlue,
          );
        }
        break;
    }
    return null;
  }

  Future<void> _startNewService(BuildContext context) async {
    final appState = context.read<AppStateProvider>();
    final sessionProvider = context.read<ServiceSessionProvider>();
    final navigationProvider = context.read<NavigationProvider>();

    try {
      appState.setGlobalLoading(true);
      await sessionProvider.startNewService();
      
      // Update navigation constraints
      navigationProvider.updateNavigationConstraints(
        canNavigateToMessaging: true,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New service started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      appState.setGlobalError('Failed to start new service: $e', context: 'HomeScreen');
    } finally {
      appState.setGlobalLoading(false);
    }
  }

  void _showQuickSendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AccessibilityUtils.createAccessibleAlertDialog(
        title: 'Quick Send',
        content: 'Navigate to messaging screen to compose and send messages?',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<NavigationProvider>().navigateToTab(1);
              AccessibilityUtils.announceToScreenReader(
                context, 
                'Navigated to messaging screen'
              );
            },
            child: const Text('Go to Messaging'),
          ),
        ],
      ),
    );
  }

  void _showSyncStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: const SyncStatusWidget(
          showDetails: true,
          showLastSyncTime: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibleBottomNavigationBar(
    BuildContext context,
    NavigationProvider navigationProvider,
    ServiceSessionProvider sessionProvider,
  ) {
    return Semantics(
      container: true,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationProvider.currentIndex,
        onTap: (index) {
          AccessibilityUtils.provideHapticFeedback(HapticFeedbackType.selectionClick);
          navigationProvider.navigateToTab(index);
          
          // Announce tab change to screen reader
          final tabNames = ['Registration', 'Messaging', 'Reports', 'Settings'];
          AccessibilityUtils.announceToScreenReader(
            context, 
            'Switched to ${tabNames[index]} tab'
          );
        },
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.textSecondary,
        items: [
          BottomNavigationBarItem(
            icon: Semantics(
              label: AccessibilityUtils.getTabSemantics(0, 'Registration'),
              child: const Icon(Icons.person_add),
            ),
            label: 'Registration',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              label: AccessibilityUtils.getTabSemantics(
                1, 
                'Messaging', 
                isEnabled: navigationProvider.canNavigateToMessaging,
                badgeCount: sessionProvider.attendeeCount > 0 ? sessionProvider.attendeeCount : null,
              ),
              child: Stack(
                children: [
                  Icon(
                    Icons.message,
                    color: navigationProvider.canNavigateToMessaging 
                      ? null 
                      : AppTheme.textHint,
                  ),
                  if (sessionProvider.attendeeCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: navigationProvider.canNavigateToMessaging 
                            ? AppTheme.errorRed 
                            : AppTheme.textHint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${sessionProvider.attendeeCount}',
                          style: const TextStyle(
                            color: AppTheme.textOnPrimary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          semanticsLabel: AccessibilityUtils.getAttendeeCountSemantics(
                            sessionProvider.attendeeCount
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            label: 'Messaging',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              label: AccessibilityUtils.getTabSemantics(
                2, 
                'Reports', 
                isEnabled: navigationProvider.canNavigateToReports
              ),
              child: Icon(
                Icons.analytics,
                color: navigationProvider.canNavigateToReports 
                  ? null 
                  : AppTheme.textHint,
              ),
            ),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Semantics(
              label: AccessibilityUtils.getTabSemantics(
                3, 
                'Settings', 
                isEnabled: navigationProvider.canNavigateToSettings
              ),
              child: Icon(
                Icons.settings,
                color: navigationProvider.canNavigateToSettings 
                  ? null 
                  : AppTheme.textHint,
              ),
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}