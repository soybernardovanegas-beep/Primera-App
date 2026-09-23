import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';

/// Guarda los recordatorios en el teléfono y, en cada cambio, reprograma las
/// notificaciones y refresca el widget de la pantalla de inicio.
class ReminderStore extends ChangeNotifier {
  static const _key = 'reminders';

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => List.unmodifiable(_reminders);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _reminders = (jsonDecode(raw) as List)
          .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  /// Vuelve a programar todo. Es idempotente; se llama al abrir la app por si
  /// cambió la zona horaria o se perdió alguna alarma.
  Future<void> resync() async {
    for (final r in _reminders) {
      await NotificationService.instance.schedule(r);
    }
    await HomeWidgetService.instance.update(_reminders);
  }

  int nextId() => _reminders.fold(0, (m, r) => r.id > m ? r.id : m) + 1;

  Future<void> save(Reminder reminder) async {
    final i = _reminders.indexWhere((r) => r.id == reminder.id);
    if (i == -1) {
      _reminders.add(reminder);
    } else {
      _reminders[i] = reminder;
    }
    await _persist();
    await NotificationService.instance.schedule(reminder);
    await HomeWidgetService.instance.update(_reminders);
  }

  Future<void> delete(Reminder reminder) async {
    _reminders.removeWhere((r) => r.id == reminder.id);
    await _persist();
    await NotificationService.instance.cancel(reminder);
    await HomeWidgetService.instance.update(_reminders);
  }

  Future<void> _persist() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_reminders.map((r) => r.toJson()).toList()),
    );
  }
}
