import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import 'content.dart';
import 'day_entry.dart';
import 'diary_store.dart';
import 'widgets.dart';

const doneLabels = {
  PersonAction.contactar: 'Contacté',
  PersonAction.presentar: 'Presenté',
  PersonAction.seguir: 'Seguí',
};

/// Noche — la cuenta.
class NightScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime date;

  const NightScreen({super.key, required this.store, required this.date});

  @override
  State<NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends State<NightScreen> {
  late final DayEntry e = widget.store.entryFor(widget.date);

  void _update(VoidCallback change) {
    setState(change);
    widget.store.save(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
          children: [
            EntryHeader(
              title: 'Noche',
              subtitle: 'la cuenta',
              date: DateFormat("EEEE, d 'de' MMMM", 'es').format(e.date),
              day: widget.store.dayNumber(e.date),
              totalDays: programDays,
            ),
            const SectionLabel('¿A quién moviste hoy?'),
            if (e.people.isEmpty)
              Text(
                'No anotaste personas en la mañana. Usa los contadores de abajo.',
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            for (final p in e.people) ...[
              Text(
                p.name,
                style: const TextStyle(fontSize: 20, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in PersonAction.values)
                    ChoiceBox(
                      label: doneLabels[a]!,
                      selected: p.done.contains(a),
                      onTap: () => _update(() => e.toggleDone(p, a)),
                    ),
                ],
              ),
              const Divider(height: 48, color: AppColors.line),
            ],
            StatGrid(
              columns: 3,
              cells: [
                _Counter(
                  label: 'Contactadas',
                  value: e.contacted,
                  onChanged: (v) => _update(() => e.contacted = v),
                ),
                _Counter(
                  label: 'Presentaciones',
                  value: e.presented,
                  onChanged: (v) => _update(() => e.presented = v),
                ),
                _Counter(
                  label: 'Seguimientos',
                  value: e.followed,
                  onChanged: (v) => _update(() => e.followed = v),
                ),
              ],
            ),
            const SectionGap(),
            const SectionLabel('Prospectos nuevos (0–6)'),
            ScaleSelector(
              min: 0,
              max: 6,
              value: e.newProspects,
              onChanged: (v) => _update(() => e.newProspects = v),
            ),
            const SectionGap(),
            const SectionLabel('Lo que hice hoy'),
            LineField(
              initial: e.didToday,
              hint: 'La cuenta real del día…',
              minLines: 3,
              onChanged: (v) => _update(() => e.didToday = v),
            ),
            const SectionGap(),
            const SectionLabel('¿A quién sigo mañana?'),
            LineField(
              initial: e.followTomorrow,
              hint: 'Nombres y siguiente paso…',
              minLines: 3,
              onChanged: (v) => _update(() => e.followTomorrow = v),
            ),
            const SectionGap(),
            const SectionLabel('Compromisos cumplidos'),
            for (final (i, c) in nightCommitments.indexed)
              CheckRow(
                label: c,
                checked: e.nightCommitments.contains(i),
                onTap: () => _update(() {
                  if (!e.nightCommitments.remove(i)) e.nightCommitments.add(i);
                }),
              ),
            const SectionGap(),
            const SectionLabel('¿El equipo se movió sin ti?'),
            ChoiceGroup<bool>(
              options: const [(true, 'Sí, alguien actuó'), (false, 'No')],
              value: e.teamMovedWithoutMe,
              onChanged: (v) => _update(() => e.teamMovedWithoutMe = v),
            ),
            const SectionGap(),
            const SectionLabel('Energía de cierre (1–10)'),
            ScaleSelector(
              min: 1,
              max: 10,
              value: e.nightEnergy,
              onChanged: (v) => _update(() => e.nightEnergy = v),
            ),
            const SectionGap(),
            const SectionLabel('Miedo o creencia que me detuvo'),
            LineField(
              initial: e.fear,
              hint: 'Lo que sentí hoy…',
              minLines: 3,
              onChanged: (v) => _update(() => e.fear = v),
            ),
            const SectionGap(),
            const SectionLabel('Afirmación contraria'),
            LineField(
              initial: e.affirmation,
              hint: 'La verdad que reemplaza al miedo…',
              onChanged: (v) => _update(() => e.affirmation = v),
            ),
            const SectionGap(),
            const SectionLabel('¿Sumé o activé a alguien real?'),
            ChoiceGroup<bool>(
              options: const [(true, 'Sí, sumé'), (false, 'Construí solo')],
              value: e.addedSomeone,
              onChanged: (v) => _update(() => e.addedSomeone = v),
            ),
            const SectionGap(),
            const Quote(nightQuote),
            const SizedBox(height: 16),
            SealButton(
              label: 'Cerrar la cuenta',
              done: e.nightClosed,
              onPressed: () {
                final closing = !e.nightClosed;
                _update(() => e.nightClosed = closing);
                if (closing) Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int delta) => InkWell(
      onTap: () => onChanged((value + delta).clamp(0, 999)),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(border: Border.all(color: AppColors.line)),
        child: Icon(icon, size: 16, color: AppColors.muted),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      child: Column(
        children: [
          FittedBox(
            child: Text(label.toUpperCase(), style: labelStyle(size: 11)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              button(Icons.remove, -1),
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              button(Icons.add, 1),
            ],
          ),
        ],
      ),
    );
  }
}
