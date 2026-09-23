import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Programa las notificaciones de cada recordatorio a su hora, aunque la app
/// esté cerrada (Android las vuelve a programar solo tras reiniciar).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios',
      'Recordatorios',
      channelDescription: 'Avisos a la hora de cada recordatorio',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('No se pudo leer la zona horaria, uso UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  /// Pide permiso para mostrar notificaciones (Android 13+). Devuelve si
  /// quedaron permitidas.
  Future<bool> requestPermission() async {
    return await _android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> areEnabled() async {
    return await _android?.areNotificationsEnabled() ?? true;
  }

  // Cada recordatorio usa hasta 8 ids: id*10 (una vez / diario) e
  // id*10 + día de la semana (1..7) para los que se repiten ciertos días.
  Future<void> cancel(Reminder r) async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(id: r.id * 10 + i);
    }
  }

  Future<void> schedule(Reminder r) async {
    await cancel(r);
    if (!r.enabled) return;

    final exact = await _android?.canScheduleExactNotifications() ?? true;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final body = r.note.isEmpty ? null : r.note;
    final now = DateTime.now();

    if (r.isOnce || r.isDaily) {
      final next = r.nextOccurrence(now);
      if (next == null) return;
      await _plugin.zonedSchedule(
        id: r.id * 10,
        title: r.title,
        body: body,
        scheduledDate: tz.TZDateTime.from(next, tz.local),
        notificationDetails: _details,
        androidScheduleMode: mode,
        matchDateTimeComponents: r.isDaily ? DateTimeComponents.time : null,
      );
      return;
    }

    for (final weekday in r.weekdays) {
      final next = Reminder(
        id: r.id,
        title: r.title,
        hour: r.hour,
        minute: r.minute,
        weekdays: {weekday},
      ).nextOccurrence(now)!;
      await _plugin.zonedSchedule(
        id: r.id * 10 + weekday,
        title: r.title,
        body: body,
        scheduledDate: tz.TZDateTime.from(next, tz.local),
        notificationDetails: _details,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }
}
