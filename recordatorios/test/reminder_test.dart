import 'package:flutter_test/flutter_test.dart';
import 'package:recordatorios/models/reminder.dart';

void main() {
  // Martes 23 de septiembre de 2025, 10:00.
  final now = DateTime(2025, 9, 23, 10);

  Reminder make({DateTime? date, Set<int> weekdays = const {}, int hour = 9}) =>
      Reminder(
        id: 1,
        title: 'Prueba',
        hour: hour,
        minute: 30,
        date: date,
        weekdays: weekdays,
      );

  test('una vez: futura devuelve la fecha, pasada devuelve null', () {
    expect(
      make(date: DateTime(2025, 9, 24)).nextOccurrence(now),
      DateTime(2025, 9, 24, 9, 30),
    );
    expect(make(date: DateTime(2025, 9, 23)).nextOccurrence(now), isNull);
  });

  test('diario: si ya pasó la hora de hoy, es mañana', () {
    final daily = make(weekdays: {1, 2, 3, 4, 5, 6, 7});
    expect(daily.nextOccurrence(now), DateTime(2025, 9, 24, 9, 30));
    expect(
      make(weekdays: {1, 2, 3, 4, 5, 6, 7}, hour: 18).nextOccurrence(now),
      DateTime(2025, 9, 23, 18, 30),
    );
  });

  test('días de la semana: salta al siguiente día elegido', () {
    // Lunes y viernes → viernes 26.
    expect(
      make(weekdays: {1, 5}).nextOccurrence(now),
      DateTime(2025, 9, 26, 9, 30),
    );
    // Solo martes y ya pasó la hora → martes siguiente.
    expect(
      make(weekdays: {2}).nextOccurrence(now),
      DateTime(2025, 9, 30, 9, 30),
    );
  });

  test('JSON ida y vuelta', () {
    final r = make(date: DateTime(2025, 12, 1));
    final back = Reminder.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
    expect(r.toJson()['date'], '2025-12-01');
  });
}
