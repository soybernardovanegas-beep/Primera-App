import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Fecha en UTC con el formato de iCalendar / Google Calendar:
/// 20260919T110200Z.
String calendarStamp(DateTime date) {
  final u = date.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T'
      '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Enlace que abre Google Calendar con el evento listo para guardar.
Uri googleCalendarUrl({
  required String title,
  required String details,
  required DateTime start,
  Duration duration = const Duration(minutes: 30),
}) {
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'details': details,
    'dates': '${calendarStamp(start)}/${calendarStamp(start.add(duration))}',
  });
}

String _escapeIcs(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\n', r'\n');

/// Contenido de un archivo .ics con un evento y una alarma 10 min antes.
String buildIcs({
  required String uid,
  required String title,
  required String details,
  required DateTime start,
  Duration duration = const Duration(minutes: 30),
  DateTime? now,
}) {
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Mi Red//CRM//ES',
    'BEGIN:VEVENT',
    'UID:$uid@mired',
    'DTSTAMP:${calendarStamp(now ?? DateTime.now())}',
    'DTSTART:${calendarStamp(start)}',
    'DTEND:${calendarStamp(start.add(duration))}',
    'SUMMARY:${_escapeIcs(title)}',
    'DESCRIPTION:${_escapeIcs(details)}',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:${_escapeIcs(title)}',
    'TRIGGER:-PT10M',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.join('\r\n')}\r\n';
}

/// Guarda un archivo temporal y abre el menú de compartir de Android.
Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String mimeType,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: mimeType)], text: text),
  );
}
