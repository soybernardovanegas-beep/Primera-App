import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models/reminder.dart';
import '../services/reminder_store.dart';

enum _Repeat { once, daily, days }

class EditReminderScreen extends StatefulWidget {
  final ReminderStore store;
  final Reminder? reminder;

  const EditReminderScreen({super.key, required this.store, this.reminder});

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late TimeOfDay _time;
  late DateTime _date;
  late _Repeat _repeat;
  late Set<int> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    final soon = DateTime.now().add(const Duration(hours: 1));
    _title = TextEditingController(text: r?.title ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _time = r == null
        ? TimeOfDay(hour: soon.hour, minute: 0)
        : TimeOfDay(hour: r.hour, minute: r.minute);
    _date = r?.date ?? DateTime(soon.year, soon.month, soon.day);
    _repeat = r == null || r.isOnce
        ? _Repeat.once
        : r.isDaily
        ? _Repeat.daily
        : _Repeat.days;
    _days = r == null || r.isOnce || r.isDaily
        ? {1, 2, 3, 4, 5}
        : {...r.weekdays};
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 5),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    String? error;
    if (title.isEmpty) error = 'Escribe qué quieres que te recuerde.';
    if (_repeat == _Repeat.days && _days.isEmpty) {
      error = 'Elige al menos un día.';
    }
    final reminder = Reminder(
      id: widget.reminder?.id ?? widget.store.nextId(),
      title: title,
      note: _note.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      date: _repeat == _Repeat.once ? _date : null,
      weekdays: switch (_repeat) {
        _Repeat.once => const {},
        _Repeat.daily => const {1, 2, 3, 4, 5, 6, 7},
        _Repeat.days => _days,
      },
    );
    if (error == null && reminder.nextOccurrence(DateTime.now()) == null) {
      error = 'Esa fecha y hora ya pasaron.';
    }
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    await widget.store.save(reminder);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reminder == null
              ? 'Nuevo recordatorio'
              : 'Editar recordatorio',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.reminder == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '¿Qué te recuerdo?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _pickTime,
              child: Text(
                formatTime(_time.hour, _time.minute),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Repetir', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<_Repeat>(
            segments: const [
              ButtonSegment(value: _Repeat.once, label: Text('Una vez')),
              ButtonSegment(value: _Repeat.daily, label: Text('Diario')),
              ButtonSegment(value: _Repeat.days, label: Text('Días')),
            ],
            selected: {_repeat},
            onSelectionChanged: (s) => setState(() => _repeat = s.first),
          ),
          const SizedBox(height: 16),
          if (_repeat == _Repeat.once)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                DateFormat("EEEE d 'de' MMMM, y", 'es').format(_date),
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
          if (_repeat == _Repeat.days)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayShort[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (on) => setState(() {
                      on ? _days.add(d) : _days.remove(d);
                    }),
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}
