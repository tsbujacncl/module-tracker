import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:module_tracker/firebase_options.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/screens/auth/login_screen.dart';
import 'package:module_tracker/screens/home/home_screen.dart';
import 'package:module_tracker/screens/onboarding/onboarding_screen.dart';
import 'package:module_tracker/services/app_logger.dart';
import 'package:module_tracker/services/notification_service.dart';
import 'package:module_tracker/theme/app_theme.dart';

void main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Load environment variables (optional for web/production builds)
      try {
        await dotenv.load(fileName: '.env');
        AppLogger.info('Environment variables loaded from .env file');
      } catch (e) {
        // Initialize with empty environment if .env file doesn't exist
        await dotenv.load(mergeWith: {});
        AppLogger.info('No .env file found, initialized with empty environment');
      }

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info('Firebase initialized');

      // Initialize Firebase Crashlytics (skip on web)
      if (!kIsWeb) {
        // Pass all uncaught errors from the framework to Crashlytics
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

        // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        AppLogger.info('Firebase Crashlytics initialized');
      }

      // Initialize Hive for local storage
      await Hive.initFlutter();
      AppLogger.info('Hive initialized for local storage');

      // Pre-open the settings box to ensure it's ready for user preferences
      await Hive.openBox('settings');
      AppLogger.info('Settings box opened and ready');

      // Initialize date formatting
      await initializeDateFormatting();

      // Set default orientation to portrait for phones
      // This will be overridden for tablets once we have screen size info
      if (!kIsWeb) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        AppLogger.debug('Default orientation set to portrait');
      }

      // Initialize notifications (only on mobile platforms)
      if (!kIsWeb) {
        try {
          final notificationService = NotificationService();
          await notificationService.initialize();
          await notificationService.requestPermissions();
          AppLogger.info('Notifications initialized');
        } catch (e, stackTrace) {
          AppLogger.error(
            'Error initializing notifications/background tasks',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else {
        AppLogger.debug('Skipping notifications/background tasks on web');
      }

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stack) {
      // Catch errors that occur outside of Flutter's error handling
      AppLogger.fatal('Uncaught error', error: error, stackTrace: stack);
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
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
        AppLogger.debug('Tablet detected - all orientations enabled');
      } else {
        // Portrait only on phones
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        AppLogger.debug('Phone detected - portrait only');
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
    return MaterialApp(
      title: 'Module Tracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'),
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
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
          AppLogger.debug('AUTH WRAPPER: User is logged in - ${user.email}');

          // Wait for preferences to load before deciding which screen to show
          if (userPreferences.isLoading) {
            AppLogger.debug('AUTH WRAPPER: Preferences still loading - showing loading indicator');
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Check if user has completed onboarding
          if (!userPreferences.hasCompletedOnboarding) {
            AppLogger.debug('AUTH WRAPPER: First-time user - showing onboarding screen');
            return const OnboardingScreen();
          }

          return const HomeScreen();
        } else {
          AppLogger.debug('AUTH WRAPPER: No user logged in - showing login screen');
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) {
        AppLogger.error('AUTH WRAPPER: Error', error: error, stackTrace: stackTrace);
        return const LoginScreen();
      },
    );
  }
}