import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'call_mode_screen.dart';

/// Orden de llamadas: primero los recordatorios vencidos, luego los de
/// mayor puntaje, y los calientes antes que los fríos.
List<Contact> powerHourQueue(
  List<Contact> contacts,
  Map<String, Reminder> reminders,
  DateTime now,
) {
  int rank(Contact c) {
    final r = reminders[c.id];
    return r != null && r.isOverdue(now) ? 0 : 1;
  }

  final queue = contacts
      .where((c) =>
          c.isActive(now) && c.hasPhone && c.stage != Stage.socio)
      .toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final byScore = (b.score ?? -1).compareTo(a.score ?? -1);
      if (byScore != 0) return byScore;
      // Caliente antes que frío.
      return b.temperature.index.compareTo(a.temperature.index);
    });
  return queue;
}

/// Hora de Poder: 60 minutos de llamadas seguidas, sin distracciones.
class PowerHourScreen extends StatefulWidget {
  const PowerHourScreen({super.key});

  @override
  State<PowerHourScreen> createState() => _PowerHourScreenState();
}

class _PowerHourScreenState extends State<PowerHourScreen> {
  static const _duration = Duration(minutes: 60);

  final _service = CrmService(Supabase.instance.client);
  final Map<CallOutcome, int> _results = {};

  List<Contact>? _queue;
  Map<String, Reminder> _reminders = {};
  int _position = 0;
  DateTime? _startedAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _keepScreenOn(false);
    super.dispose();
  }

  /// Mantiene la pantalla encendida durante la Hora de Poder. Si el
  /// teléfono no lo permite, la app sigue funcionando igual.
  void _keepScreenOn(bool on) {
    WakelockPlus.toggle(enable: on).catchError((_) {});
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _service.fetchContacts(),
      _service.fetchPendingReminders(),
    ]);
    if (!mounted) return;
    final reminders = currentReminderByContact(results[1] as List<Reminder>);
    setState(() {
      _reminders = reminders;
      _queue = powerHourQueue(
          results[0] as List<Contact>, reminders, DateTime.now());
    });
  }

  void _start() {
    setState(() => _startedAt = DateTime.now());
    _keepScreenOn(true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == Duration.zero) {
        _ticker?.cancel();
        _keepScreenOn(false);
      }
      setState(() {});
    });
  }

  Duration get _remaining {
    final started = _startedAt;
    if (started == null) return _duration;
    final left = _duration - DateTime.now().difference(started);
    return left.isNegative ? Duration.zero : left;
  }

  int get _calls => _results.values.fold(0, (a, b) => a + b);

  Future<void> _callCurrent() async {
    final contact = _queue![_position];
    final outcome = await Navigator.of(context).push<CallOutcome>(
      MaterialPageRoute(
        builder: (_) => CallModeScreen(contactId: contact.id, powerHour: true),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (outcome != null) _results[outcome] = (_results[outcome] ?? 0) + 1;
      _position++;
    });
  }

  String _format(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = _queue;
    final finished = _startedAt != null &&
        (_remaining == Duration.zero || (queue != null && _position >= queue.length));

    return Scaffold(
      appBar: AppBar(title: const Text('Hora de Poder ⚡')),
      body: queue == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Text(
                    _format(_remaining),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _startedAt == null ? theme.colorScheme.outline : gold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 1 - _remaining.inSeconds / _duration.inSeconds,
                  color: gold,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(
                        label: '📞 $_calls ${_calls == 1 ? 'llamada' : 'llamadas'}',
                        dense: false),
                    for (final o in CallOutcome.values)
                      if ((_results[o] ?? 0) > 0)
                        Pill(label: '${o.label}: ${_results[o]}', color: o.color, dense: false),
                  ],
                ),
                const SizedBox(height: 24),
                if (_startedAt == null) ...[
                  Text(
                    'Apaga notificaciones, ten agua a la mano y llama sin '
                    'parar durante 60 minutos. Registra el resultado de cada '
                    'llamada con un toque y pasa al siguiente.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${queue.length} contactos en la fila '
                    '(vencidos primero, luego mayor puntaje)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: queue.isEmpty ? null : _start,
                    icon: const Icon(Icons.bolt),
                    label: const Text('Empezar'),
                  ),
                ] else if (finished) ...[
                  Text('¡Hora de Poder terminada! 🎉',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Hiciste $_calls llamadas. La constancia es lo que construye tu red.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Terminar'),
                  ),
                ] else ...[
                  Text('SIGUIENTE LLAMADA',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: gold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  _NextCard(
                    contact: queue[_position],
                    reminder: _reminders[queue[_position].id],
                    onCall: _callCurrent,
                    onSkip: () => setState(() => _position++),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Después: ${queue.skip(_position + 1).take(3).map((c) => c.name).join(', ')}'
                    '${queue.length - _position - 1 > 3 ? '...' : ''}',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => setState(() => _position = queue.length),
                    child: const Text('Terminar antes'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.contact,
    required this.reminder,
    required this.onCall,
    required this.onSkip,
  });

  final Contact contact;
  final Reminder? reminder;
  final VoidCallback onCall;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(contact.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            CategoryLabel(contact: contact),
            const SizedBox(height: 4),
            Text('${contact.stage.label} · ${contact.phone}',
                style: TextStyle(color: theme.colorScheme.outline)),
            if (reminder != null && reminder!.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('📝 ${reminder!.note}'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call),
                    label: const Text('Abrir llamada'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: onSkip, child: const Text('Saltar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
