import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import 'content.dart';
import 'day_entry.dart';
import 'diary_store.dart';
import 'widgets.dart';

const actionLabels = {
  PersonAction.contactar: 'Contactar',
  PersonAction.presentar: 'Presentar',
  PersonAction.seguir: 'Seguir',
};

/// Mañana — la intención.
class MorningScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime date;

  const MorningScreen({super.key, required this.store, required this.date});

  @override
  State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  late final DayEntry e = widget.store.entryFor(widget.date);

  void _update(VoidCallback change) {
    setState(change);
    widget.store.save(e);
  }

  Future<void> _addPerson() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir persona'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      _update(() => e.people.add(PersonPlan(name: name.trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
          children: [
            EntryHeader(
              title: 'Mañana',
              subtitle: 'la intención',
              date: DateFormat("EEEE, d 'de' MMMM", 'es').format(e.date),
              day: widget.store.dayNumber(e.date),
              totalDays: programDays,
            ),
            const SectionLabel('Personas a mover hoy'),
            for (final (i, p) in e.people.indexed) ...[
              _PersonRow(
                index: i + 1,
                person: p,
                onAction: (a) => _update(() => p.planned = a),
                onRemove: () => _update(() => e.people.remove(p)),
              ),
              const Divider(height: 40, color: AppColors.line),
            ],
            InkWell(
              onTap: _addPerson,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: AppColors.accent),
                    const SizedBox(width: 16),
                    Text(
                      'AÑADIR PERSONA',
                      style: labelStyle(
                        color: AppColors.accent,
                        size: 14,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SectionGap(),
            const SectionLabel('Evento hoy'),
            ChoiceGroup<String>(
              options: [for (final ev in events) (ev, ev)],
              value: e.event,
              onChanged: (v) => _update(() => e.event = v),
            ),
            const SectionGap(),
            const SectionLabel('Meta de prospectos nuevos'),
            ScaleSelector(
              min: 1,
              max: 6,
              value: e.prospectGoal,
              onChanged: (v) => _update(() => e.prospectGoal = v),
            ),
            const SectionGap(),
            const SectionLabel('¿A quién invito al próximo evento?'),
            LineField(
              initial: e.inviteNext,
              hint: 'Nombres…',
              onChanged: (v) => _update(() => e.inviteNext = v),
            ),
            const SectionGap(),
            const SectionLabel('Energía de inicio (1–10)'),
            ScaleSelector(
              min: 1,
              max: 10,
              value: e.morningEnergy,
              onChanged: (v) => _update(() => e.morningEnergy = v),
            ),
            const SectionGap(),
            const SectionLabel('Compromisos de la mañana'),
            for (final (i, c) in morningCommitments.indexed)
              CheckRow(
                label: c,
                checked: e.morningCommitments.contains(i),
                onTap: () => _update(() {
                  if (!e.morningCommitments.remove(i)) {
                    e.morningCommitments.add(i);
                  }
                }),
              ),
            const SectionGap(),
            const SectionLabel('La una cosa que no puede fallar hoy'),
            LineField(
              initial: e.oneThing,
              hint: 'Lo que pase lo que pase…',
              onChanged: (v) => _update(() => e.oneThing = v),
            ),
            const SectionGap(),
            const Quote(morningQuote),
            const SizedBox(height: 16),
            SealButton(
              label: 'Sellar la intención',
              done: e.morningSealed,
              onPressed: () {
                final sealing = !e.morningSealed;
                _update(() => e.morningSealed = sealing);
                if (sealing) Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final int index;
  final PersonPlan person;
  final ValueChanged<PersonAction?> onAction;
  final VoidCallback onRemove;

  const _PersonRow({
    required this.index,
    required this.person,
    required this.onAction,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: labelStyle(color: AppColors.faint),
              ),
            ),
            Expanded(
              child: Text(
                person.name,
                style: const TextStyle(fontSize: 20, color: AppColors.ink),
              ),
            ),
            IconButton(
              tooltip: 'Quitar',
              onPressed: onRemove,
              icon: const Icon(Icons.close, color: AppColors.faint),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 56),
          child: ChoiceGroup<PersonAction>(
            options: [
              for (final a in PersonAction.values) (a, actionLabels[a]!),
            ],
            value: person.planned,
            onChanged: onAction,
          ),
        ),
      ],
    );
  }
}
