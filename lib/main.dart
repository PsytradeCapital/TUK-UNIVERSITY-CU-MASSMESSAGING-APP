import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/home_screen.dart';
import 'providers/service_session_provider.dart';

void main() {
  runApp(const ChristianUnionAttendanceApp());
}

class ChristianUnionAttendanceApp extends StatelessWidget {
  const ChristianUnionAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ServiceSessionProvider(),
      child: MaterialApp(
        title: 'Christian Union Attendance',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
        ),
        home: const AuthWrapper(
          child: HomeScreen(),
        ),
      ),
    );
  }
}