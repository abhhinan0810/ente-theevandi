import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/track_train_screen.dart';
import 'screens/coach_estimation_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'services/user_session.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnteTheevandiApp());
}

class EnteTheevandiApp extends StatefulWidget {
  const EnteTheevandiApp({super.key});

  @override
  State<EnteTheevandiApp> createState() => _EnteTheevandiAppState();
}

class _EnteTheevandiAppState extends State<EnteTheevandiApp> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = UserSession().isLoggedIn;
    UserSession().addListener(_onSessionUpdate);
  }

  @override
  void dispose() {
    UserSession().removeListener(_onSessionUpdate);
    super.dispose();
  }

  void _onSessionUpdate() {
    if (mounted) {
      setState(() {
        _isLoggedIn = UserSession().isLoggedIn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ente Theevandi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _isLoggedIn
          ? const MainNavigationWrapper()
          : LoginScreen(
              onLoginSuccess: () {
                setState(() => _isLoggedIn = true);
              },
            ),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TrackTrainScreen(),
    CoachEstimationScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primary,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.train_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.train_rounded, color: Colors.white),
              label: 'Trains',
            ),
            NavigationDestination(
              icon: Icon(Icons.near_me_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.near_me_rounded, color: Colors.white),
              label: 'Tracker',
            ),
            NavigationDestination(
              icon: Icon(Icons.pin_drop_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.pin_drop_rounded, color: Colors.white),
              label: 'Coach GPS',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: Colors.white),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
