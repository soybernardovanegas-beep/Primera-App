import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Avisos en el teléfono para los recordatorios, aunque la app esté cerrada.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios',
      'Recordatorios',
      channelDescription: 'Avisos de seguimiento a tus contactos',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      // Sin avisos la app sigue funcionando; solo se pierde la alarma.
      debugPrint('No se pudieron activar las notificaciones: $e');
    }
  }

  /// Identificador numérico estable a partir del uuid del recordatorio.
  static int idFor(String reminderId) =>
      int.parse(reminderId.replaceAll('-', '').substring(0, 7), radix: 16);

  Future<void> schedule(Reminder reminder) async {
    if (!_ready || !reminder.dueAt.isAfter(DateTime.now())) return;
    await _safely(() => _plugin.zonedSchedule(
          id: idFor(reminder.id),
          title: 'Recordatorio: ${reminder.contactName}',
          body: reminder.note.isEmpty
              ? 'Toca para ver el contacto'
              : reminder.note,
          scheduledDate: tz.TZDateTime.from(reminder.dueAt, tz.local),
          notificationDetails: _details,
          // Inexacto: evita pedir el permiso especial de alarmas exactas; el
          // aviso puede llegar con unos minutos de diferencia.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        ));
  }

  Future<void> cancel(String reminderId) async {
    if (!_ready) return;
    await _safely(() => _plugin.cancel(id: idFor(reminderId)));
  }

  /// Reprograma todos los avisos pendientes (al abrir la app), por si se
  /// crearon o completaron desde otro dispositivo.
  Future<void> resync(List<Reminder> pending) async {
    if (!_ready) return;
    await _safely(_plugin.cancelAll);
    // Android limita la cantidad de alarmas; se programan las más próximas.
    final upcoming = pending
        .where((r) => r.dueAt.isAfter(DateTime.now()))
        .take(50);
    for (final r in upcoming) {
      await schedule(r);
    }
  }

  /// Quita todos los avisos (al cerrar sesión).
  Future<void> clear() async {
    if (!_ready) return;
    await _safely(_plugin.cancelAll);
  }

  /// Un aviso que falla (permiso negado, límite de alarmas...) nunca debe
  /// impedir guardar el recordatorio en la base de datos.
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Aviso no programado: $e');
    }
  }
}
