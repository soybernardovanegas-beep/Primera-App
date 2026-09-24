import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import 'content.dart';
import 'day_entry.dart';

/// Guarda el diario de 90 días en el teléfono. Cada cambio se guarda solo
/// ("guardado automático").
class DiaryStore extends ChangeNotifier {
  static const _entriesKey = 'diary_entries';
  static const _startKey = 'diary_start';
  static const _reminderKey = 'diary_reminder_minutes';

  final Map<String, DayEntry> _entries = {};
  late DateTime _start;

  /// Hora de la pregunta diaria, en minutos desde medianoche (17:00 por defecto).
  int _reminderMinutes = 17 * 60;

  Timer? _saveTimer;

  DateTime get startDate => _start;
  int get reminderHour => _reminderMinutes ~/ 60;
  int get reminderMinute => _reminderMinutes % 60;

  /// Días con algo escrito, del más reciente al más antiguo.
  List<DayEntry> get history =>
      _entries.values.where((e) => e.hasContent).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw != null) {
      for (final e in (jsonDecode(raw) as List)) {
        final entry = DayEntry.fromJson(e as Map<String, dynamic>);
        _entries[entry.key] = entry;
      }
    }
    final start = prefs.getString(_startKey);
    if (start == null) {
      // Primer uso: el día 1 es hoy (se puede cambiar desde la pantalla Hoy).
      _start = _day(DateTime.now());
      await prefs.setString(_startKey, dateKey(_start));
    } else {
      _start = DateTime.parse(start);
    }
    _reminderMinutes = prefs.getInt(_reminderKey) ?? _reminderMinutes;
    notifyListeners();
  }

  /// La entrada de ese día; si no existe aún, una vacía (se guarda al
  /// primer cambio).
  DayEntry entryFor(DateTime date) =>
      _entries[dateKey(date)] ?? DayEntry(date: date);

  /// Guarda los cambios de [entry]. La escritura a disco se agrupa para no
  /// escribir en cada letra que se teclea.
  void save(DayEntry entry) {
    _entries[entry.key] = entry;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.values.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setStartDate(DateTime date) async {
    _start = _day(date);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startKey, dateKey(_start));
    await scheduleQuestions();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    _reminderMinutes = hour * 60 + minute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderKey, _reminderMinutes);
    await scheduleQuestions();
  }

  /// Día del programa (el día de inicio es el 1).
  int dayNumber(DateTime date) {
    final d = _day(date);
    return DateTime.utc(d.year, d.month, d.day)
            .difference(DateTime.utc(_start.year, _start.month, _start.day))
            .inDays +
        1;
  }

  /// Programa la notificación con la pregunta de cada uno de los próximos días.
  Future<void> scheduleQuestions() async {
    final today = _day(DateTime.now());
    final items = [
      for (var i = 0; i < 14; i++)
        (
          at: DateTime(
            today.year,
            today.month,
            today.day + i,
            reminderHour,
            reminderMinute,
          ),
          question: questionForDay(
            dayNumber(DateTime(today.year, today.month, today.day + i)),
          ),
        ),
    ];
    try {
      await NotificationService.instance.scheduleDailyQuestions(items);
    } catch (e) {
      debugPrint('No se pudo programar la pregunta diaria: $e');
    }
  }

  // ---- Estadísticas ----

  /// Días completos (mañana y noche) seguidos, contando hasta hoy; si hoy aún
  /// no está completo, la racha termina en ayer.
  int streak([DateTime? now]) {
    var day = _day(now ?? DateTime.now());
    if (!entryFor(day).isComplete) day = _addDays(day, -1);
    var count = 0;
    while (entryFor(day).isComplete) {
      count++;
      day = _addDays(day, -1);
    }
    return count;
  }

  Iterable<DayEntry> get _all => _entries.values;

  int get totalContacted => _all.fold(0, (s, e) => s + e.contacted);
  int get totalPresented => _all.fold(0, (s, e) => s + e.presented);
  int get totalFollowed => _all.fold(0, (s, e) => s + e.followed);
  int get totalReach => _all.fold(0, (s, e) => s + e.reach);
  int get totalNewProspects =>
      _all.fold(0, (s, e) => s + (e.newProspects ?? 0));
  int get daysTeamMovedWithoutMe =>
      _all.where((e) => e.teamMovedWithoutMe == true).length;

  /// Porcentaje (0..1) de noches cerradas en que se cumplió cada compromiso.
  List<double> commitmentRates() {
    final closed = _all.where((e) => e.nightClosed).toList();
    return [
      for (var i = 0; i < nightCommitments.length; i++)
        closed.isEmpty
            ? 0
            : closed.where((e) => e.nightCommitments.contains(i)).length /
                  closed.length,
    ];
  }

  /// Energía de inicio y cierre por número de día, en orden.
  List<({int day, int? start, int? end})> energySeries() {
    final days =
        _all
            .where((e) => e.morningEnergy != null || e.nightEnergy != null)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return [
      for (final e in days)
        (day: dayNumber(e.date), start: e.morningEnergy, end: e.nightEnergy),
    ];
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);
}
