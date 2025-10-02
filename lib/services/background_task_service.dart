import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:module_tracker/firebase_options.dart';
import 'package:module_tracker/services/notification_service.dart';
import 'package:module_tracker/services/task_checker_service.dart';

/// Background task callback - runs in isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('DEBUG BACKGROUND: Task started - $task');

    try {
      // Initialize Firebase in background isolate
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG BACKGROUND: No user logged in, skipping task check');
        return Future.value(true);
      }

      print('DEBUG BACKGROUND: Checking tasks for user: ${user.uid}');

      // Check for incomplete tasks
      final taskChecker = TaskCheckerService();
      final (incompleteToday, overdue) = await taskChecker.checkIncompleteTasks(user.uid);

      print('DEBUG BACKGROUND: Found $incompleteToday incomplete tasks today, $overdue overdue');

      // Send notification if there are incomplete/overdue tasks
      if (incompleteToday > 0 || overdue > 0) {
        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.sendTaskReminder(incompleteToday, overdue);
      }

      return Future.value(true);
    } catch (e) {
      print('DEBUG BACKGROUND: Error in background task - $e');
      return Future.value(false);
    }
  });
}

class BackgroundTaskService {
  static const String _dailyTaskCheckId = 'daily_task_check';

  /// Register the daily task check (runs at 5pm)
  static Future<void> registerDailyTaskCheck() async {
    print('DEBUG BACKGROUND: Registering daily task check');

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );

    // Register periodic task
    // Note: On Android, minimum interval is 15 minutes
    // For daily at 5pm, we use periodic task and check time in callback
    await Workmanager().registerPeriodicTask(
      _dailyTaskCheckId,
      _dailyTaskCheckId,
      frequency: const Duration(hours: 24),
      initialDelay: _getInitialDelay(),
      constraints: Constraints(
        networkType: NetworkType.connected, // Require internet for Firestore
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    print('DEBUG BACKGROUND: Daily task check registered with initial delay: ${_getInitialDelay()}');
  }

  /// Calculate initial delay to run at 5pm today/tomorrow
  static Duration _getInitialDelay() {
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, 17, 0); // 5pm today

    // If 5pm has passed, schedule for tomorrow
    if (targetTime.isBefore(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    return targetTime.difference(now);
  }

  /// Cancel the daily task check
  static Future<void> cancelDailyTaskCheck() async {
    print('DEBUG BACKGROUND: Cancelling daily task check');
    await Workmanager().cancelByUniqueName(_dailyTaskCheckId);
  }

  /// Run task check immediately (for testing)
  static Future<void> runTaskCheckNow() async {
    print('DEBUG BACKGROUND: Running task check now');

    await Workmanager().registerOneOffTask(
      'test_task_check',
      'test_task_check',
      initialDelay: const Duration(seconds: 5),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
