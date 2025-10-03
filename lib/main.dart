import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:module_tracker/firebase_options.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/theme_provider.dart';
import 'package:module_tracker/screens/auth/login_screen.dart';
import 'package:module_tracker/screens/home/home_screen.dart';
import 'package:module_tracker/services/notification_service.dart';
import 'package:module_tracker/services/background_task_service.dart';
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

  // Initialize date formatting
  await initializeDateFormatting();

  // Initialize notifications (only on mobile platforms)
  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.requestPermissions();
      print('DEBUG: Notifications initialized');

      // Register daily task check (5pm reminder)
      await BackgroundTaskService.registerDailyTaskCheck();
      print('DEBUG: Background tasks registered');
    } catch (e) {
      print('DEBUG: Error initializing notifications/background tasks: $e');
    }
  } else {
    print('DEBUG: Skipping notifications/background tasks on web');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return authState.when(
      data: (user) {
        if (user != null) {
          print('DEBUG AUTH WRAPPER: User is logged in - ${user.email}');
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