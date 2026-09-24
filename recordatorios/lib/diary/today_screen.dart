import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import 'content.dart';
import 'day_entry.dart';
import 'diary_store.dart';
import 'morning_screen.dart';
import 'night_screen.dart';
import 'widgets.dart';

/// Pestaña HOY: el día del programa, la pregunta del día y las dos partes del
/// diario.
class TodayScreen extends StatelessWidget {
  final DiaryStore store;

  const TodayScreen({super.key, required this.store});

  Future<void> _changeStart(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      helpText: 'Día 1 del programa',
      initialDate: store.startDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null) await store.setStartDate(d);
  }

  Future<void> _changeReminder(BuildContext context) async {
    final t = await showTimePicker(
      context: context,
      helpText: 'Hora del recordatorio diario',
      initialTime: TimeOfDay(
        hour: store.reminderHour,
        minute: store.reminderMinute,
      ),
    );
    if (t != null) await store.setReminderTime(t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final e = store.entryFor(now);
        final day = store.dayNumber(now);
        final reminderAt = DateTime(
          now.year,
          now.month,
          now.day,
          store.reminderHour,
          store.reminderMinute,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          children: [
            Text(
              'Día $day',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: serif,
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Text(
              '/ $programDays',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: serif,
                fontSize: 26,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat("EEEE, d 'de' MMMM", 'es').format(now).toUpperCase(),
              textAlign: TextAlign.center,
              style: labelStyle(size: 14).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => _changeStart(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'DÍA 1: ${DateFormat('d MMM y', 'es').format(store.startDate).toUpperCase()}'
                  ' · CAMBIAR FECHA DE INICIO',
                  style: labelStyle(
                    color: AppColors.faint,
                    size: 11,
                  ).copyWith(letterSpacing: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _QuestionBox(
              time: DateFormat('h:mm a', 'es').format(reminderAt).toUpperCase(),
              question: questionForDay(day),
              onTap: () => _changeReminder(context),
            ),
            const SizedBox(height: 40),
            DayCards(store: store, entry: e),
            const SizedBox(height: 56),
            StatGrid(
              cells: [
                StatCell(
                  value: '${store.streak()}',
                  label: 'Racha',
                  caption: 'Días seguidos',
                ),
                StatCell(
                  value: '${store.totalReach}',
                  label: 'Alcance total',
                  caption: 'Contactos · $programDays días',
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              _nudge(e, now),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 17,
                color: AppColors.muted,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _nudge(DayEntry e, DateTime now) {
    final afternoon = now.hour >= 13;
    if (e.isComplete) return 'Día completo. Mañana se vuelve a empezar.';
    if (!e.morningSealed) {
      return afternoon
          ? 'Aún no sellas la intención de hoy.'
          : 'Buenos días. Es hora de la intención.';
    }
    return afternoon
        ? 'Ya pasó la una de la tarde. Es hora de la cuenta.'
        : 'Intención sellada. Ahora, a mover personas.';
  }
}

class _QuestionBox extends StatelessWidget {
  final String time;
  final String question;
  final VoidCallback onTap;

  const _QuestionBox({
    required this.time,
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
        decoration: BoxDecoration(border: Border.all(color: AppColors.accent)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECORDATORIO · $time',
              style: labelStyle(color: AppColors.accent)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              question,
              style: const TextStyle(
                fontFamily: serif,
                fontSize: 21,
                height: 1.6,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las tarjetas Mañana y Noche de un día, que abren su formulario.
class DayCards extends StatelessWidget {
  final DiaryStore store;
  final DayEntry entry;

  const DayCards({super.key, required this.store, required this.entry});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = dateKey(now) == entry.key;
    // Avance del día entre las 6:00 y las 23:00 (días pasados: completo).
    final progress = isToday
        ? ((now.hour * 60 + now.minute - 6 * 60) / (17 * 60)).clamp(0.0, 1.0)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntryCard(
          title: 'Mañana',
          subtitle: 'la intención',
          done: entry.morningSealed,
          onTap: () =>
              _open(context, MorningScreen(store: store, date: entry.date)),
        ),
        const SizedBox(height: 32),
        Stack(
          children: [
            Container(height: 2, color: AppColors.line),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(height: 4, color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _EntryCard(
          title: 'Noche',
          subtitle: 'la cuenta',
          done: entry.nightClosed,
          onTap: () =>
              _open(context, NightScreen(store: store, date: entry.date)),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  const _EntryCard({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: serif,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                StatusBadge(done: done),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '— $subtitle',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 18,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              done ? 'TOCA PARA REVISAR' : 'TOCA PARA REGISTRAR',
              style: labelStyle(color: AppColors.faint, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
