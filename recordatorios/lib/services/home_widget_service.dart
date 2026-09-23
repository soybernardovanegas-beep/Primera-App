import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/reminder.dart';

/// Mantiene al día el widget de la pantalla de inicio. El widget nativo
/// (RemindersWidgetProvider.kt) lee la lista de recordatorios y calcula él
/// mismo cuáles siguen, así que funciona aunque la app lleve días sin abrirse.
class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  static const _provider = 'RemindersWidgetProvider';

  Future<void> update(List<Reminder> reminders) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'reminders_json',
        jsonEncode(reminders.map((r) => r.toJson()).toList()),
      );
      await HomeWidget.updateWidget(androidName: _provider);
      await HomeWidget.scheduleWidgetUpdates(
        _refreshTimes(reminders),
        androidName: _provider,
      );
    } catch (e) {
      debugPrint('No se pudo actualizar el widget: $e');
    }
  }

  /// Momentos en que el widget debe redibujarse en los próximos 7 días: justo
  /// después de cada recordatorio (para quitarlo de la lista) y a medianoche
  /// (para que "Hoy"/"Mañana" cambien de día).
  List<DateTime> _refreshTimes(List<Reminder> reminders) {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 7));
    final times = <DateTime>{};
    for (var i = 1; i <= 7; i++) {
      times.add(DateTime(now.year, now.month, now.day + i));
    }
    for (final r in reminders.where((r) => r.enabled)) {
      var from = now;
      while (true) {
        final next = r.nextOccurrence(from);
        if (next == null || next.isAfter(limit)) break;
        times.add(next.add(const Duration(seconds: 1)));
        from = next;
      }
    }
    return times.toList()..sort();
  }

  Future<bool> canPin() async {
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> pin() => HomeWidget.requestPinWidget(androidName: _provider);
}
