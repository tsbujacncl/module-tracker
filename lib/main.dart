import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:module_tracker/firebase_options.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/theme_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/screens/auth/login_screen.dart';
import 'package:module_tracker/screens/home/home_screen.dart';
import 'package:module_tracker/screens/onboarding/onboarding_screen.dart';
import 'package:module_tracker/services/notification_service.dart';
import 'package:module_tracker/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('DEBUG: Firebase initialized');

  // Initialize Hive for local storage
  await Hive.initFlutter();
  print('DEBUG: Hive initialized for local storage');

  // Pre-open the settings box to ensure it's ready for user preferences
  await Hive.openBox('settings');
  print('DEBUG: Settings box opened and ready');

  // Initialize date formatting
  await initializeDateFormatting();

  // Set default orientation to portrait for phones
  // This will be overridden for tablets once we have screen size info
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('DEBUG: Default orientation set to portrait');
  }

  // Initialize notifications (only on mobile platforms)
  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.requestPermissions();
      print('DEBUG: Notifications initialized');
    } catch (e) {
      print('DEBUG: Error initializing notifications/background tasks: $e');
    }
  } else {
    print('DEBUG: Skipping notifications/background tasks on web');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrientation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _updateOrientation();
  }

  void _updateOrientation() {
    if (!kIsWeb && mounted) {
      final mediaQuery = MediaQuery.of(context);
      final isTablet = _isTablet(mediaQuery);

      if (isTablet) {
        // Allow all orientations on tablets
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        print('DEBUG: Tablet detected - all orientations enabled');
      } else {
        // Portrait only on phones
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        print('DEBUG: Phone detected - portrait only');
      }
    }
  }

  bool _isTablet(MediaQueryData mediaQuery) {
    // Get the shorter side of the screen
    final shortestSide = mediaQuery.size.shortestSide;
    // Tablets typically have a shortest side >= 600dp
    return shortestSide >= 600;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Module Tracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode.themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userPreferences = ref.watch(userPreferencesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          print('DEBUG AUTH WRAPPER: User is logged in - ${user.email}');

          // Check if user has completed onboarding
          if (!userPreferences.hasCompletedOnboarding) {
            print('DEBUG AUTH WRAPPER: First-time user - showing onboarding screen');
            return const OnboardingScreen();
          }

          return const HomeScreen();
        } else {
          print('DEBUG AUTH WRAPPER: No user logged in - showing login screen');
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) {
        print('DEBUG AUTH WRAPPER: Error - $error');
        return const LoginScreen();
      },
    );
  }
}