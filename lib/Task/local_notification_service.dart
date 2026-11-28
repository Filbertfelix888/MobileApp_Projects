import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_models.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _notifiedTomorrowKey = 'pln_notified_tomorrow_v1';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextNotificationId = 1000;

  Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> notifyTaskMoved({
    required BuildContext context,
    required TaskCard task,
    required String fromColumnTitle,
    required String toColumnTitle,
  }) async {
    final title = 'Update Tugas: ${task.displayTitle}';
    final body = 'Dipindahkan dari $fromColumnTitle ke $toColumnTitle.';
    await _dispatchNotification(
      context: context,
      title: title,
      body: body,
      isUrgent: false,
    );
  }

  Future<void> checkTomorrowDeadlines({
    required BuildContext context,
    required List<TaskCard> tasks,
    required String currentColumnTitle,
    required bool isFinalColumn,
    DateTime? nowOverride,
  }) async {
    if (isFinalColumn) return;

    final now = nowOverride ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dayAfterTomorrowStart = tomorrowStart.add(const Duration(days: 1));

    final prefs = await SharedPreferences.getInstance();
    final alreadyNotified =
        (prefs.getStringList(_notifiedTomorrowKey) ?? const <String>[]).toSet();
    var prefsDirty = false;

    for (final task in tasks) {
      final dueDate = _parseDueDateLocal(task.dueDate);
      if (dueDate == null) continue;

      final dueDayStart = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final isDueTomorrow =
          !dueDayStart.isBefore(tomorrowStart) &&
          dueDayStart.isBefore(dayAfterTomorrowStart);

      if (!isDueTomorrow) continue;

      final token = '${task.publicId}|${dueDayStart.toIso8601String()}';
      if (alreadyNotified.contains(token)) continue;

      alreadyNotified.add(token);
      prefsDirty = true;

      if (!context.mounted) return;
      await _dispatchNotification(
        context: context,
        title: 'Deadline Besok: ${task.displayTitle}',
        body:
            'Tugas di kolom $currentColumnTitle memiliki tenggat waktu besok.',
        isUrgent: true,
      );
    }

    if (prefsDirty) {
      await prefs.setStringList(_notifiedTomorrowKey, alreadyNotified.toList());
    }
  }

  DateTime? _parseDueDateLocal(String? rawDueDate) {
    if (rawDueDate == null || rawDueDate.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(rawDueDate.trim());
    if (parsed == null) return null;
    if (parsed.year <= 1) return null;
    return parsed.toLocal();
  }

  Future<void> _dispatchNotification({
    required BuildContext context,
    required String title,
    required String body,
    required bool isUrgent,
  }) async {
    if (!kIsWeb) {
      await _ensureInitialized();

      final androidDetails = AndroidNotificationDetails(
        isUrgent ? 'pln_deadline_channel' : 'pln_task_update_channel',
        isUrgent ? 'Notifikasi Tenggat Tugas' : 'Notifikasi Perubahan Tugas',
        channelDescription:
            'Notifikasi lokal untuk pembaruan tugas dan tenggat waktu',
        importance: isUrgent ? Importance.high : Importance.defaultImportance,
        priority: isUrgent ? Priority.high : Priority.defaultPriority,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final notifId = _nextNotificationId++;

      await _plugin.show(
        notifId,
        title,
        body,
        notificationDetails,
      );
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isUrgent ? 5 : 3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      );
  }
}