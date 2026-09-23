import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/guides.dart';
import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/crm_service.dart';
import '../widgets/bulk.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'contact_detail_screen.dart';
import 'crm_screen.dart' show matchesSearch;
import 'guides_screen.dart';
import 'power_hour_screen.dart';

/// Proceso de negocios: recordatorios del día y tablero por etapas.
class ProcessScreen extends StatefulWidget {
  const ProcessScreen({super.key});

  @override
  State<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends State<ProcessScreen> {
  final _service = CrmService(Supabase.instance.client);
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  Map<String, Reminder> _reminders = {};
  Interest? _interest;
  bool _isLoading = true;
  bool _showAllReminders = false;
  Set<String>? _selection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _service.fetchContacts(),
      _service.fetchPendingReminders(),
    ]);
    if (!mounted) return;
    final now = DateTime.now();
    final contacts = (results[0] as List<Contact>)
        .where((c) => c.isActive(now))
        .toList()
      ..sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
    setState(() {
      _contacts = contacts;
      _reminders = currentReminderByContact(results[1] as List<Reminder>);
      _isLoading = false;
    });
  }

  Future<void> _open(String contactId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: contactId)),
    );
    _load();
  }

  Future<void> _openGuide(Guide guide) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuideScreen(guide: guide)),
    );
  }

  Future<void> _advance(Contact c) async {
    final next = nextStage(c.stage, c.interest);
    if (next == null) return;
    await _service.setStage(c.id, next);
    if (!mounted) return;
    showSnack(context, '${c.name} → ${next.label}');
    _load();
  }

  Future<void> _discard(Contact c) async {
    await _service.setStage(c.id, Stage.descartado);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${c.name} pasó a "No interesado"'),
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () async {
          await _service.setStage(c.id, c.stage);
          _load();
        },
      ),
    ));
    _load();
  }

  Future<void> _delete(Contact c) async {
    final ok = await confirm(context, title: '¿Eliminar a ${c.name}?');
    if (!ok) return;
    await _service.deleteContact(c.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in _contacts) c.id: c};
    final visible = _contacts
        .where((c) =>
            (_interest == null || c.interest == _interest) &&
            matchesSearch(c, _searchController.text))
        .toList();
    final selection = _selection;

    return Scaffold(
      bottomNavigationBar: selection == null
          ? null
          : BulkActionBar(
              selected: selection,
              onDone: () {
                setState(() => _selection = null);
                _load();
              },
              onCancel: () => setState(() => _selection = null),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  ScreenHeader(
                    title: 'Proceso de Negocios 🚦',
                    subtitle: 'Mueve tus prospectos hacia el cierre',
                    trailing: OutlinedButton.icon(
                      onPressed: () => setState(() =>
                          _selection = selection == null ? <String>{} : null),
                      icon: const Icon(Icons.check_box_outlined),
                      label: Text(selection == null ? 'Seleccionar' : 'Listo'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar prospecto...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<Interest?>(
                          showSelectedIcon: false,
                          segments: [
                            const ButtonSegment(value: null, label: Text('Todos')),
                            for (final i in Interest.values)
                              ButtonSegment(
                                  value: i, label: Text('${i.emoji} ${i.label}')),
                          ],
                          selected: {_interest},
                          onSelectionChanged: (v) =>
                              setState(() => _interest = v.first),
                        ),
                        const SizedBox(height: 12),
                        _GuideButtons(onOpen: _openGuide),
                        const SizedBox(height: 12),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.bolt, color: Colors.orange),
                            ),
                            title: const Text('Hora de Poder',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('60 min de llamadas enfocadas'),
                            trailing: const Icon(Icons.timer_outlined),
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const PowerHourScreen()));
                              _load();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RemindersPanel(
                          reminders: _reminders.values
                              .where((r) => byId.containsKey(r.contactId))
                              .toList()
                            ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
                          contacts: byId,
                          showAll: _showAllReminders,
                          onToggleShowAll: () => setState(
                              () => _showAllReminders = !_showAllReminders),
                          onOpen: _open,
                          onChanged: _load,
                        ),
                      ],
                    ),
                  ),
                  for (final stage in Stage.values)
                    if (stage != Stage.descartado)
                      ..._stageSection(
                        stage,
                        visible.where((c) => c.stage == stage).toList(),
                        selection,
                      ),
                ],
              ),
            ),
    );
  }

  List<Widget> _stageSection(
    Stage stage,
    List<Contact> contacts,
    Set<String>? selection,
  ) {
    if (contacts.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 24, 8),
        child: Row(
          children: [
            Pill(label: stage.label, color: stage.color, dense: false),
            const Spacer(),
            Text('${contacts.length}',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
      for (final c in contacts)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProcessCard(
            contact: c,
            reminder: _reminders[c.id],
            selected: selection?.contains(c.id),
            onTap: selection == null
                ? () => _open(c.id)
                : () => setState(() => selection.contains(c.id)
                    ? selection.remove(c.id)
                    : selection.add(c.id)),
            onLongPress: () => setState(() => _selection = {...?selection, c.id}),
            onBell: () async {
              if (await showNewReminderSheet(context, c) != null) _load();
            },
            onAdvance: () => _advance(c),
            onDiscard: () => _discard(c),
            onFavorite: () async {
              await _service.updateFields(c.id, {'favorite': !c.favorite});
              _load();
            },
            onDelete: () => _delete(c),
          ),
        ),
    ];
  }
}

class _GuideButtons extends StatelessWidget {
  const _GuideButtons({required this.onOpen});

  final ValueChanged<Guide> onOpen;

  @override
  Widget build(BuildContext context) {
    Widget button(Guide g) => FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: gold.withValues(alpha: 0.12),
            foregroundColor: gold,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          onPressed: () => onOpen(g),
          icon: Icon(g.icon, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(g.title)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: button(guideObjeciones)),
            const SizedBox(width: 8),
            Expanded(child: button(guideProspeccion)),
            const SizedBox(width: 8),
            Expanded(child: button(guideRedes)),
          ],
        ),
        const SizedBox(height: 8),
        button(guideSeguimiento),
      ],
    );
  }
}

class _RemindersPanel extends StatelessWidget {
  const _RemindersPanel({
    required this.reminders,
    required this.contacts,
    required this.showAll,
    required this.onToggleShowAll,
    required this.onOpen,
    required this.onChanged,
  });

  final List<Reminder> reminders;
  final Map<String, Contact> contacts;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final ValueChanged<String> onOpen;
  final VoidCallback onChanged;

  static const _collapsedCount = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final overdue = reminders.where((r) => r.isOverdue(now)).toList();
    final upcoming = reminders.where((r) => !r.isOverdue(now)).toList();
    final shownOverdue = showAll ? overdue : overdue.take(_collapsedCount).toList();
    final shownUpcoming =
        showAll ? upcoming : upcoming.take(_collapsedCount).toList();
    final hidden = reminders.length - shownOverdue.length - shownUpcoming.length;

    Widget label(String text, Color color, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
              ],
              Text(text,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: color, letterSpacing: 1.2)),
            ],
          ),
        );

    return SectionCard(
      title: 'Recordatorios',
      icon: Icons.calendar_month_outlined,
      trailing: Text('${reminders.length}',
          style: TextStyle(color: theme.colorScheme.outline)),
      child: reminders.isEmpty
          ? const Text('Sin recordatorios pendientes. ¡Estás al día! ✅')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shownOverdue.isNotEmpty)
                  label('VENCIDOS', theme.colorScheme.error,
                      icon: Icons.warning_amber),
                for (final r in shownOverdue) _tile(context, r, overdue: true),
                if (shownUpcoming.isNotEmpty) label('PRÓXIMOS', gold),
                for (final r in shownUpcoming) _tile(context, r, overdue: false),
                if (hidden > 0 || showAll)
                  TextButton(
                    onPressed: onToggleShowAll,
                    child: Text(showAll ? 'Ver menos' : 'Ver todos ($hidden más)'),
                  ),
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, Reminder r, {required bool overdue}) {
    final theme = Theme.of(context);
    final color = overdue ? theme.colorScheme.error : theme.colorScheme.outline;
    final date = overdue
        ? DateFormat('d MMM', 'es').format(r.dueAt)
        : DateFormat('d MMM y · HH:mm', 'es').format(r.dueAt);
    return Card(
      color: overdue
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
          : theme.colorScheme.surfaceContainerHigh,
      child: ListTile(
        onTap: () => onOpen(r.contactId),
        leading: Icon(Icons.notifications_outlined, color: color),
        title: Text(r.contactName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: TextStyle(color: color)),
            if (r.note.isNotEmpty)
              Text('📝 ${r.note}', maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Hecho',
          icon: const Icon(Icons.check),
          onPressed: () async {
            await completeReminderFlow(context, r, contacts[r.contactId]);
            onChanged();
          },
        ),
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({
    required this.contact,
    required this.reminder,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onBell,
    required this.onAdvance,
    required this.onDiscard,
    required this.onFavorite,
    required this.onDelete,
  });

  final Contact contact;
  final Reminder? reminder;
  final bool? selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onBell;
  final VoidCallback onAdvance;
  final VoidCallback onDiscard;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = contact;
    final next = nextStage(c.stage, c.interest);
    const green = Color(0xFF2EBD85);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selected != null)
                    Checkbox(value: selected, onChanged: (_) => onTap()),
                  Expanded(
                    child: Text(
                      c.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    c.score == null ? 'Sin calificar' : '${c.score} pts',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                  ReminderBell(reminder: reminder, onPressed: onBell),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (c.referredBy.isNotEmpty) Pill(label: 'Ref: ${c.referredBy}'),
                    if (c.source.isNotEmpty) Pill(label: 'Origen: ${c.source}'),
                    Pill(
                      label: '${c.temperature.emoji} ${c.temperature.label}',
                      color: c.temperature.color,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (c.phone.isEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_outlined,
                            size: 18, color: theme.colorScheme.outline),
                        const SizedBox(width: 6),
                        Text('Sin teléfono',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.outline)),
                      ],
                    )
                  else
                    ActionChip(
                      avatar: const Icon(Icons.phone_in_talk_outlined,
                          color: green, size: 18),
                      label: Text(c.phone,
                          style: const TextStyle(
                              color: green, fontWeight: FontWeight.w600)),
                      backgroundColor: green.withValues(alpha: 0.12),
                      onPressed: c.hasPhone ? () => callContact(context, c) : null,
                    ),
                  if (c.hasPhone)
                    ActionChip(
                      avatar: const Icon(Icons.chat_outlined, color: green, size: 18),
                      label: const Text('WA',
                          style: TextStyle(
                              color: green, fontWeight: FontWeight.w600)),
                      backgroundColor: green.withValues(alpha: 0.12),
                      onPressed: () => whatsappContact(context, c),
                    ),
                  ActionChip(
                    avatar:
                        const Icon(Icons.auto_awesome_outlined, color: gold, size: 18),
                    label: const Text('Sugerir', style: TextStyle(color: gold)),
                    backgroundColor: gold.withValues(alpha: 0.12),
                    onPressed: () => showSuggestSheet(context, c),
                  ),
                ],
              ),
              if (selected == null)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'No interesado',
                      icon: Icon(Icons.cancel_outlined,
                          color: theme.colorScheme.error),
                      onPressed: onDiscard,
                    ),
                    if (next != null)
                      TextButton.icon(
                        onPressed: onAdvance,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        iconAlignment: IconAlignment.end,
                        label: const Text('Avanzar'),
                      ),
                    IconButton(
                      tooltip: 'Favorito',
                      icon: Icon(c.favorite ? Icons.star : Icons.star_border,
                          color: c.favorite ? gold : null),
                      onPressed: onFavorite,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
