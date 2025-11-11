import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:module_tracker/services/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.debug('Initializing notification service');

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
    AppLogger.debug('Notification service initialized');
  }

  /// Request notification permissions (iOS/macOS)
  Future<bool> requestPermissions() async {
    AppLogger.debug('Requesting permissions');

    // Android 13+ requires runtime permission
    if (await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ==
        false) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      AppLogger.debug('Android permission granted: $granted');
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

    AppLogger.debug('iOS permission granted: $granted');
    return granted ?? true;
  }

  /// Schedule daily notification at 5pm
  Future<void> scheduleDailyReminder() async {
    AppLogger.debug('Scheduling daily 5pm reminder');

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

    AppLogger.debug('Next reminder scheduled for: $scheduledTime');

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
    // Cancel all daily reminders for specific days (IDs 10-16)
    for (int i = 10; i <= 16; i++) {
      await _notifications.cancel(i);
    }
    AppLogger.debug('Daily reminder cancelled');
  }

  /// Schedule daily reminder with custom time and days
  /// [time] - Time of day for the reminder
  /// [days] - Set of weekdays (1=Monday, 7=Sunday)
  Future<void> scheduleDailyReminderCustom(
    TimeOfDay time,
    Set<int> days,
  ) async {
    AppLogger.debug('Scheduling custom daily reminder at ${time.hour}:${time.minute} for days: $days');

    // Cancel existing daily reminders
    await cancelDailyReminder();

    if (days.isEmpty) {
      AppLogger.debug('No days selected, skipping schedule');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);

    // Schedule a notification for each selected day
    for (final day in days) {
      // Calculate next occurrence of this weekday
      var scheduledTime = _getNextWeekday(
        day,
        time.hour,
        time.minute,
      );

      // Make sure it's in the future
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 7));
      }

      AppLogger.debug('Scheduling for weekday $day at $scheduledTime');

      await _notifications.zonedSchedule(
        9 + day, // IDs 10-16 for Mon-Sun
        'Daily Task Reminder',
        'Time to check your tasks for today!',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_custom',
            'Custom Daily Reminders',
            channelDescription: 'Customizable daily task reminders',
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
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Get next occurrence of a specific weekday at a specific time
  /// [weekday] - 1=Monday, 7=Sunday
  tz.TZDateTime _getNextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    int daysUntilTarget = (weekday - now.weekday) % 7;

    if (daysUntilTarget == 0) {
      // It's the target day today
      final targetTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time hasn't passed yet today, schedule for today
      if (targetTime.isAfter(now)) {
        return targetTime;
      }
      // Otherwise, schedule for next week
      daysUntilTarget = 7;
    }

    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntilTarget,
      hour,
      minute,
    );
  }

  /// Send immediate notification for incomplete tasks
  Future<void> sendTaskReminder(int incompleteCount, int overdueCount) async {
    if (incompleteCount == 0 && overdueCount == 0) {
      AppLogger.debug('No incomplete tasks, skipping notification');
      return;
    }

    AppLogger.debug('Sending task reminder - Incomplete: $incompleteCount, Overdue: $overdueCount');

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

  /// Schedule weekend planning reminder (Sunday evening)
  Future<void> scheduleWeekendPlanning(TimeOfDay time) async {
    AppLogger.debug('Scheduling weekend planning at ${time.hour}:${time.minute}');

    await cancelWeekendPlanning();

    // Schedule for Sunday (weekday 7)
    var scheduledTime = _getNextWeekday(
      7, // Sunday
      time.hour,
      time.minute,
    );

    final now = tz.TZDateTime.now(tz.local);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 7));
    }

    AppLogger.debug('Next weekend planning scheduled for: $scheduledTime');

    await _notifications.zonedSchedule(
      20, // Weekend planning notification ID
      'Plan Your Week',
      'Take a moment to review your upcoming week!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekend_planning',
          'Weekend Planning',
          channelDescription: 'Weekly planning reminders',
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
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Cancel weekend planning reminder
  Future<void> cancelWeekendPlanning() async {
    await _notifications.cancel(20);
    AppLogger.debug('Weekend planning cancelled');
  }

  /// Schedule assessment due alerts
  /// This should be called with assessment data to schedule alerts
  Future<void> scheduleAssessmentAlert({
    required String assessmentId,
    required String assessmentName,
    required DateTime dueDate,
    required int daysBeforeDue,
  }) async {
    final notificationTime = dueDate.subtract(Duration(days: daysBeforeDue));
    final now = DateTime.now();

    // Don't schedule if the notification time has passed
    if (notificationTime.isBefore(now)) {
      AppLogger.debug('Assessment alert time has passed, skipping');
      return;
    }

    // Generate unique ID based on assessment and days before
    final notificationId = 100 + assessmentId.hashCode.abs() % 1000 + daysBeforeDue;

    final scheduledTime = tz.TZDateTime.from(notificationTime, tz.local);

    String timeFrame = daysBeforeDue == 1 ? 'tomorrow' : 'in $daysBeforeDue days';

    await _notifications.zonedSchedule(
      notificationId,
      'Assessment Due Soon',
      '$assessmentName is due $timeFrame',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'assessment_alerts',
          'Assessment Alerts',
          channelDescription: 'Alerts for upcoming assessments',
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
    );

    AppLogger.debug('Scheduled assessment alert for $assessmentName, due $timeFrame');
  }

  /// Cancel all assessment alerts (IDs 100-1999)
  Future<void> cancelAllAssessmentAlerts() async {
    for (int i = 100; i < 2000; i++) {
      await _notifications.cancel(i);
    }
    AppLogger.debug('All assessment alerts cancelled');
  }

  /// Schedule lecture reminder
  Future<void> scheduleLectureReminder({
    required String lectureId,
    required String lectureName,
    required DateTime lectureTime,
    required int minutesBefore,
  }) async {
    final notificationTime = lectureTime.subtract(Duration(minutes: minutesBefore));
    final now = DateTime.now();

    // Don't schedule if the notification time has passed
    if (notificationTime.isBefore(now)) {
      AppLogger.debug('Lecture reminder time has passed, skipping');
      return;
    }

    // Generate unique ID based on lecture
    final notificationId = 2000 + lectureId.hashCode.abs() % 1000;

    final scheduledTime = tz.TZDateTime.from(notificationTime, tz.local);

    await _notifications.zonedSchedule(
      notificationId,
      'Upcoming Lecture',
      '$lectureName starts in $minutesBefore minutes',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lecture_reminders',
          'Lecture Reminders',
          channelDescription: 'Reminders for upcoming lectures',
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
    );

    AppLogger.debug('Scheduled lecture reminder for $lectureName');
  }

  /// Cancel all lecture reminders (IDs 2000-2999)
  Future<void> cancelAllLectureReminders() async {
    for (int i = 2000; i < 3000; i++) {
      await _notifications.cancel(i);
    }
    AppLogger.debug('All lecture reminders cancelled');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.debug('Notification tapped - payload: ${response.payload}');
    // Handle navigation when notification is tapped
    // You can use a global navigator key or stream to handle this
  }

  /// Check pending notifications (for debugging)
  Future<void> checkPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    AppLogger.debug('Pending notifications: ${pending.length}');
    for (final notification in pending) {
      AppLogger.debug('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
  }
}
