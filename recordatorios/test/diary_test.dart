import 'package:flutter_test/flutter_test.dart';
import 'package:recordatorios/diary/day_entry.dart';
import 'package:recordatorios/diary/diary_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DiaryStore> storeStartingOn(String start) async {
    SharedPreferences.setMockInitialValues({'diary_start': start});
    final store = DiaryStore();
    await store.load();
    return store;
  }

  DayEntry complete(DateTime d) =>
      DayEntry(date: d, morningSealed: true, nightClosed: true);

  test('el día de inicio es el día 1', () async {
    final store = await storeStartingOn('2026-09-20');
    expect(store.dayNumber(DateTime(2026, 9, 20, 23)), 1);
    expect(store.dayNumber(DateTime(2026, 9, 24, 8)), 5);
  });

  test('racha: días completos seguidos hasta hoy o ayer', () async {
    final store = await storeStartingOn('2026-09-20');
    store.save(complete(DateTime(2026, 9, 21)));
    store.save(complete(DateTime(2026, 9, 22)));
    store.save(complete(DateTime(2026, 9, 23)));
    // Hoy (24) aún pendiente: cuenta hasta ayer.
    store.save(DayEntry(date: DateTime(2026, 9, 24), morningSealed: true));
    expect(store.streak(DateTime(2026, 9, 24, 17)), 3);
    // Un hueco corta la racha.
    expect(store.streak(DateTime(2026, 9, 26, 9)), 0);
  });

  test('marcar en la noche ajusta los contadores', () {
    final e = DayEntry(date: DateTime(2026, 9, 24));
    final nora = PersonPlan(name: 'Nora', planned: PersonAction.seguir);
    e.people.add(nora);
    e.toggleDone(nora, PersonAction.presentar);
    e.toggleDone(nora, PersonAction.seguir);
    expect((e.presented, e.followed, e.reach), (1, 1, 2));
    e.toggleDone(nora, PersonAction.seguir);
    expect((e.followed, e.reach), (0, 1));
  });

  test('cumplimiento de compromisos sobre noches cerradas', () async {
    final store = await storeStartingOn('2026-09-20');
    store.save(
      DayEntry(date: DateTime(2026, 9, 21), nightClosed: true)
        ..nightCommitments.add(3),
    );
    store.save(DayEntry(date: DateTime(2026, 9, 22), nightClosed: true));
    expect(store.commitmentRates(), [0, 0, 0, 0.5]);
  });

  test('JSON ida y vuelta', () {
    final e = DayEntry(
      date: DateTime(2026, 9, 24),
      people: [PersonPlan(name: 'Hugo', planned: PersonAction.contactar)],
      event: 'Ninguno',
      morningEnergy: 2,
      morningCommitments: {1, 2},
      teamMovedWithoutMe: false,
    );
    expect(DayEntry.fromJson(e.toJson()).toJson(), e.toJson());
  });
}
