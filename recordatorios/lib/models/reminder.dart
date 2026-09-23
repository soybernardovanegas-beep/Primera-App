/// Un recordatorio. Si [weekdays] está vacío es de una sola vez y usa [date];
/// si no, se repite en esos días de la semana (1 = lunes ... 7 = domingo,
/// igual que [DateTime.weekday]). Los 7 días = todos los días.
class Reminder {
  final int id;
  final String title;
  final String note;
  final int hour;
  final int minute;
  final DateTime? date;
  final Set<int> weekdays;
  final bool enabled;

  const Reminder({
    required this.id,
    required this.title,
    this.note = '',
    required this.hour,
    required this.minute,
    this.date,
    this.weekdays = const {},
    this.enabled = true,
  });

  bool get isOnce => weekdays.isEmpty;
  bool get isDaily => weekdays.length == 7;

  /// Próxima vez que debe sonar a partir de [from] (exclusivo), o null si ya
  /// pasó (solo ocurre con los de una sola vez).
  DateTime? nextOccurrence(DateTime from) {
    if (isOnce) {
      final d = date;
      if (d == null) return null;
      final at = DateTime(d.year, d.month, d.day, hour, minute);
      return at.isAfter(from) ? at : null;
    }
    for (var i = 0; i < 8; i++) {
      final day = DateTime(from.year, from.month, from.day + i, hour, minute);
      if (weekdays.contains(day.weekday) && day.isAfter(from)) return day;
    }
    return null;
  }

  Reminder copyWith({
    String? title,
    String? note,
    int? hour,
    int? minute,
    DateTime? date,
    Set<int>? weekdays,
    bool? enabled,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      date: date ?? this.date,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'hour': hour,
    'minute': minute,
    // Formato yyyy-MM-dd: el widget nativo (Kotlin) también lo lee.
    'date': date == null
        ? null
        : '${date!.year.toString().padLeft(4, '0')}-'
              '${date!.month.toString().padLeft(2, '0')}-'
              '${date!.day.toString().padLeft(2, '0')}',
    'weekdays': (weekdays.toList()..sort()),
    'enabled': enabled,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String?;
    return Reminder(
      id: json['id'] as int,
      title: json['title'] as String,
      note: json['note'] as String? ?? '',
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      date: date == null ? null : DateTime.parse(date),
      weekdays: ((json['weekdays'] as List?) ?? const [])
          .map((e) => e as int)
          .toSet(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
