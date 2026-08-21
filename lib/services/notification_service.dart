import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/reminder.dart';
import 'simulated_call_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final id = int.tryParse(response.payload ?? '');
        if (id != null) SimulatedCallService.handleReminderTap(id);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleReminderCall(Reminder reminder) async {
    final tzName = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(tzName);
    final scheduled = tz.TZDateTime.from(reminder.scheduledAt, location);

    const androidDetails = AndroidNotificationDetails(
      'ben_reminders',
      'Ben Reminders',
      channelDescription: 'Ben is calling you',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
    );

    await _plugin.zonedSchedule(
      reminder.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Ben is calling...',
      reminder.task,
      scheduled,
      const NotificationDetails(android: androidDetails),
      payload: reminder.id?.toString(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async => await _plugin.cancelAll();
}
