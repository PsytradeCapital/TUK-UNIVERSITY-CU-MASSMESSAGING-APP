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
import '../services/recovery_service.dart';

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
      
    } catch (e) {
      appState.setGlobalError('Failed to initialize app: $e', context: 'HomeScreen');
    } finally {
      appState.setGlobalLoading(false);
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
            body: IndexedStack(
              index: navigationProvider.currentIndex,
              children: screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: navigationProvider.currentIndex,
              onTap: (index) {
                navigationProvider.navigateToTab(index);
              },
              selectedItemColor: Colors.blue[700],
              unselectedItemColor: Colors.grey[600],
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_add),
                  label: 'Registration',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      Icon(
                        Icons.message,
                        color: navigationProvider.canNavigateToMessaging 
                          ? null 
                          : Colors.grey[400],
                      ),
                      if (sessionProvider.attendeeCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: navigationProvider.canNavigateToMessaging 
                                ? Colors.red 
                                : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${sessionProvider.attendeeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Messaging',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.analytics,
                    color: navigationProvider.canNavigateToReports 
                      ? null 
                      : Colors.grey[400],
                  ),
                  label: 'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.settings,
                    color: navigationProvider.canNavigateToSettings 
                      ? null 
                      : Colors.grey[400],
                  ),
                  label: 'Settings',
                ),
              ],
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
          return FloatingActionButton.extended(
            onPressed: () => _startNewService(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Service'),
            backgroundColor: Colors.green[700],
          );
        }
        break;
      case 1: // Messaging tab
        if (sessionProvider.hasActiveService && sessionProvider.attendeeCount > 0) {
          return FloatingActionButton(
            onPressed: () => _showQuickSendDialog(context),
            child: const Icon(Icons.send),
            backgroundColor: Colors.blue[700],
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
      builder: (context) => AlertDialog(
        title: const Text('Quick Send'),
        content: const Text('Navigate to messaging screen to compose and send messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<NavigationProvider>().navigateToTab(1);
            },
            child: const Text('Go to Messaging'),
          ),
        ],
      ),
    );
  }
}