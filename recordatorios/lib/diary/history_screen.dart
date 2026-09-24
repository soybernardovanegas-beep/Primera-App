import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import 'day_entry.dart';
import 'diary_store.dart';
import 'today_screen.dart';

/// Pestaña HISTORIAL: cada día del diario.
class HistoryScreen extends StatelessWidget {
  final DiaryStore store;

  const HistoryScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final days = store.history;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          children: [
            const Text(
              'Historial',
              style: TextStyle(
                fontFamily: serif,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text('CADA DÍA DEL DIARIO', style: labelStyle()),
            const SizedBox(height: 40),
            const Divider(height: 1, color: AppColors.line),
            if (days.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Text(
                  'Aquí aparecerá cada día que registres.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ),
            for (final e in days) ...[
              _HistoryRow(
                day: store.dayNumber(e.date),
                entry: e,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _PastDayScreen(store: store, entry: e),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
            ],
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final int day;
  final DayEntry entry;
  final VoidCallback onTap;

  const _HistoryRow({
    required this.day,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat("EEEE, d 'de' MMMM", 'es').format(entry.date);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                '$day',
                style: const TextStyle(
                  fontFamily: serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date[0].toUpperCase() + date.substring(1),
                    style: const TextStyle(fontSize: 18, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Mark(label: 'Mañana', done: entry.morningSealed),
                      const SizedBox(width: 24),
                      _Mark(label: 'Noche', done: entry.nightClosed),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  final String label;
  final bool done;

  const _Mark({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.accent : AppColors.faint;
    return Row(
      children: [
        Icon(
          done ? Icons.check : Icons.circle_outlined,
          size: done ? 18 : 10,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: labelStyle(color: color).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Un día pasado: sus tarjetas Mañana y Noche para revisarlas o completarlas.
class _PastDayScreen extends StatelessWidget {
  final DiaryStore store;
  final DayEntry entry;

  const _PastDayScreen({required this.store, required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat("EEEE, d 'de' MMMM", 'es').format(entry.date);
    return Scaffold(
      appBar: AppBar(title: Text('Día ${store.dayNumber(entry.date)}')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            Text(date.toUpperCase(), style: labelStyle()),
            const SizedBox(height: 40),
            DayCards(store: store, entry: store.entryFor(entry.date)),
          ],
        ),
      ),
    );
  }
}
