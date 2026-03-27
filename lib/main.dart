import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:dadaroo/firebase_options.dart';
import 'package:dadaroo/providers/app_provider.dart';
import 'package:dadaroo/screens/login_screen.dart';
import 'package:dadaroo/screens/family_setup_screen.dart';
import 'package:dadaroo/screens/profile_screen.dart';
import 'package:dadaroo/screens/dad_view.dart';
import 'package:dadaroo/screens/family_view.dart';
import 'package:dadaroo/screens/rate_dad_view.dart';
import 'package:dadaroo/screens/history_view.dart';
import 'package:dadaroo/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DadarooApp());
}

class DadarooApp extends StatelessWidget {
  const DadarooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Dadaroo',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}

/// Routes the user to the correct screen based on auth & family state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Still initializing Firebase Auth
    if (provider.isAuthLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🚗', style: TextStyle(fontSize: 64)),
              SizedBox(height: 16),
              Text(
                'Dadaroo',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkBrown,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppTheme.primaryOrange),
            ],
          ),
        ),
      );
    }

    // Not logged in
    if (!provider.isLoggedIn) {
      return const LoginScreen();
    }

    // Logged in but no family group
    if (!provider.hasFamilyGroup) {
      return const FamilySetupScreen();
    }

    // Fully set up - show main app
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    DadView(),
    FamilyView(),
    RateDadView(),
    HistoryView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon:
                Icon(Icons.directions_car, color: AppTheme.primaryOrange),
            label: 'Dad',
          ),
          NavigationDestination(
            icon: Icon(Icons.family_restroom_outlined),
            selectedIcon:
                Icon(Icons.family_restroom, color: AppTheme.primaryOrange),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star, color: AppTheme.primaryOrange),
            label: 'Rate Dad',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppTheme.primaryOrange),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
