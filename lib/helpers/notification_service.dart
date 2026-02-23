// lib/helpers/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/bill.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
    tz.initializeTimeZones();
  }

  Future<void> scheduleBillNotification(
    Bill bill, {
    String currencySymbol = 'KSh',
  }) async {
    if (bill.id == null) {
      return;
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Schedule reminder for 9:00 AM local time, one day before due date.
    final dueDateLocal = tz.TZDateTime.from(bill.dueDate, tz.local);
    final dayBeforeDue = dueDateLocal.subtract(const Duration(days: 1));
    final scheduleTime = tz.TZDateTime(
      tz.local,
      dayBeforeDue.year,
      dayBeforeDue.month,
      dayBeforeDue.day,
      9,
    );

    // Ensure the scheduled time is in the future
    if (scheduleTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'bill_reminders_channel',
      'Bill Reminders',
      channelDescription: 'Channel for bill reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: bill.id!,
      title: 'Upcoming Bill Reminder',
      body:
          'Your bill "${bill.name}" for $currencySymbol ${bill.amount.toStringAsFixed(0)} is due tomorrow.',
      scheduledDate: scheduleTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }
}
