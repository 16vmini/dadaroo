import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:dadaroo/config/app_config.dart';
import 'package:dadaroo/firebase_options.dart';
import 'package:dadaroo/models/user_profile.dart';
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
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed (using placeholder config): $e');
  }
  runApp(const DadarooApp());
}

class DadarooApp extends StatelessWidget {
  const DadarooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: appConfig.appName,
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚗', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                appConfig.appName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkBrown,
                ),
              ),
              const SizedBox(height: 24),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDad = provider.userProfile?.role == UserRole.dad;

    final screens = isDad
        ? const [DadView(), FamilyView(), RateDadView(), HistoryView()]
        : const [FamilyView(), RateDadView(), HistoryView()];

    final destinations = isDad
        ? [
            NavigationDestination(
              icon: const Icon(Icons.directions_car_outlined),
              selectedIcon:
                  Icon(Icons.directions_car, color: AppTheme.primaryOrange),
              label: appConfig.parentRole,
            ),
            NavigationDestination(
              icon: const Icon(Icons.family_restroom_outlined),
              selectedIcon:
                  Icon(Icons.family_restroom, color: AppTheme.primaryOrange),
              label: 'Family',
            ),
            NavigationDestination(
              icon: const Icon(Icons.star_outline),
              selectedIcon: Icon(Icons.star, color: AppTheme.primaryOrange),
              label: 'Rate ${appConfig.parentRole}',
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppTheme.primaryOrange),
              label: 'History',
            ),
          ]
        : [
            NavigationDestination(
              icon: const Icon(Icons.family_restroom_outlined),
              selectedIcon:
                  Icon(Icons.family_restroom, color: AppTheme.primaryOrange),
              label: 'Tracking',
            ),
            NavigationDestination(
              icon: const Icon(Icons.star_outline),
              selectedIcon: Icon(Icons.star, color: AppTheme.primaryOrange),
              label: 'Rate ${appConfig.parentRole}',
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppTheme.primaryOrange),
              label: 'History',
            ),
          ];

    // Clamp index if role changes
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: destinations,
      ),
    );
  }
}
