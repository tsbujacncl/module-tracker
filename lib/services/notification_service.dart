import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    print('DEBUG NOTIFICATIONS: Initializing notification service');

    // Initialize timezone
    tz.initializeTimeZones();

    // Set local timezone (you can make this configurable)
    final String timeZoneName = 'Europe/London'; // Change to your timezone
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    // Initialize
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    print('DEBUG NOTIFICATIONS: Notification service initialized');
  }

  /// Request notification permissions (iOS/macOS)
  Future<bool> requestPermissions() async {
    print('DEBUG NOTIFICATIONS: Requesting permissions');

    // Android 13+ requires runtime permission
    if (await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ==
        false) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      print('DEBUG NOTIFICATIONS: Android permission granted: $granted');
      return granted ?? false;
    }

    // iOS/macOS permissions
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    print('DEBUG NOTIFICATIONS: iOS permission granted: $granted');
    return granted ?? true;
  }

  /// Schedule daily notification at 5pm
  Future<void> scheduleDailyReminder() async {
    print('DEBUG NOTIFICATIONS: Scheduling daily 5pm reminder');

    await cancelDailyReminder(); // Cancel existing first

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      17, // 5pm
      0,
      0,
    );

    // If 5pm has passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    print('DEBUG NOTIFICATIONS: Next reminder scheduled for: $scheduledTime');

    await _notifications.zonedSchedule(
      0, // Notification ID
      'Task Reminder',
      'Checking your incomplete tasks...',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Task Reminders',
          channelDescription: 'Daily reminders for incomplete tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
    );
  }

  /// Cancel the daily reminder
  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(0);
    print('DEBUG NOTIFICATIONS: Daily reminder cancelled');
  }

  /// Send immediate notification for incomplete tasks
  Future<void> sendTaskReminder(int incompleteCount, int overdueCount) async {
    if (incompleteCount == 0 && overdueCount == 0) {
      print('DEBUG NOTIFICATIONS: No incomplete tasks, skipping notification');
      return;
    }

    print('DEBUG NOTIFICATIONS: Sending task reminder - Incomplete: $incompleteCount, Overdue: $overdueCount');

    String title = 'Task Reminder';
    String body;

    if (overdueCount > 0 && incompleteCount > 0) {
      body = 'You have $overdueCount overdue task${overdueCount > 1 ? 's' : ''} and $incompleteCount incomplete task${incompleteCount > 1 ? 's' : ''} for today';
    } else if (overdueCount > 0) {
      body = 'You have $overdueCount overdue task${overdueCount > 1 ? 's' : ''}';
    } else {
      body = 'You have $incompleteCount incomplete task${incompleteCount > 1 ? 's' : ''} for today';
    }

    await _notifications.show(
      1, // Different ID from daily reminder
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for incomplete tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('DEBUG NOTIFICATIONS: Notification tapped - payload: ${response.payload}');
    // Handle navigation when notification is tapped
    // You can use a global navigator key or stream to handle this
  }

  /// Check pending notifications (for debugging)
  Future<void> checkPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    print('DEBUG NOTIFICATIONS: Pending notifications: ${pending.length}');
    for (final notification in pending) {
      print('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
  }
}
