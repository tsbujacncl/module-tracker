import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:module_tracker/firebase_options.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/screens/auth/login_screen.dart';
import 'package:module_tracker/screens/home/home_screen.dart';
import 'package:module_tracker/services/notification_service.dart';
import 'package:module_tracker/services/background_task_service.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Module Tracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9), // Vibrant cyan/sky blue
          brightness: Brightness.light,
          primary: const Color(0xFF0EA5E9),
          secondary: const Color(0xFF06B6D4),
          tertiary: const Color(0xFF10B981),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF0F9FF),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0F2FE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0F2FE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
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