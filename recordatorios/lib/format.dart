import 'package:intl/intl.dart';

import 'models/reminder.dart';

const weekdayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// "Todos los días", "Lun, Mié, Vie" o "mar 24 sep".
String describeRepeat(Reminder r) {
  if (r.isDaily) return 'Todos los días';
  if (r.isOnce) {
    return r.date == null
        ? 'Sin fecha'
        : DateFormat('EEE d MMM', 'es').format(r.date!);
  }
  if (r.weekdays.containsAll({1, 2, 3, 4, 5}) && r.weekdays.length == 5) {
    return 'Lunes a viernes';
  }
  if (r.weekdays.containsAll({6, 7}) && r.weekdays.length == 2) {
    return 'Fines de semana';
  }
  return (r.weekdays.toList()..sort())
      .map((d) => weekdayShort[d - 1])
      .join(', ');
}

/// "Hoy 18:30", "Mañana 08:00" o "vie 26 sep 10:00".
String describeWhen(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  final time = formatTime(at.hour, at.minute);
  if (diff == 0) return 'Hoy $time';
  if (diff == 1) return 'Mañana $time';
  return '${DateFormat('EEE d MMM', 'es').format(at)} $time';
}
