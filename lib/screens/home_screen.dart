import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'registration_screen.dart';
import 'messaging_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import '../providers/service_session_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load any existing active service session on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceSessionProvider>().loadActiveService();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, sessionProvider, child) {
        final List<Widget> screens = [
          const RegistrationScreen(),
          MessagingScreen(
            attendees: sessionProvider.currentAttendees,
            serviceId: sessionProvider.currentService?.serviceId ?? 0,
          ),
          const ReportsScreen(),
          const SettingsScreen(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
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
                    const Icon(Icons.message),
                    if (sessionProvider.attendeeCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
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
              const BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Reports',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}