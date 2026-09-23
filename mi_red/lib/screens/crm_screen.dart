import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/profile.dart';
import '../models/qualification.dart';
import '../models/reminder.dart';
import '../services/calendar_links.dart';
import '../services/crm_service.dart';
import '../services/import_export.dart';
import '../widgets/bulk.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'contact_detail_screen.dart';
import 'import_screen.dart';

/// Filtros adicionales de la lista de contactos.
class ContactFilters {
  Temperature? temperature;
  bool onlyFavorites = false;
  final Set<Stage> stages = {};
  final Set<String> tags = {};
  String? source;

  int get activeCount =>
      (temperature != null ? 1 : 0) +
      (onlyFavorites ? 1 : 0) +
      (stages.isNotEmpty ? 1 : 0) +
      (tags.isNotEmpty ? 1 : 0) +
      (source != null ? 1 : 0);

  bool matches(Contact c) =>
      (temperature == null || c.temperature == temperature) &&
      (!onlyFavorites || c.favorite) &&
      (stages.isEmpty || stages.contains(c.stage)) &&
      (tags.isEmpty || c.tags.any(tags.contains)) &&
      (source == null || c.source == source);

  void clear() {
    temperature = null;
    onlyFavorites = false;
    stages.clear();
    tags.clear();
    source = null;
  }
}

/// Búsqueda por nombre, teléfono, etiqueta, referido u origen.
bool matchesSearch(Contact c, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return c.name.toLowerCase().contains(q) ||
      c.phone.contains(q) ||
      c.referredBy.toLowerCase().contains(q) ||
      c.source.toLowerCase().contains(q) ||
      c.tags.any((t) => t.toLowerCase().contains(q));
}

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final _service = CrmService(Supabase.instance.client);
  final _searchController = TextEditingController();
  final _filters = ContactFilters();

  List<Contact> _contacts = [];
  Map<String, Reminder> _reminders = {};
  Profile _profile = const Profile();
  Category? _category;
  bool _isLoading = true;
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
      _service.fetchProfile(),
    ]);
    if (!mounted) return;
    final contacts = results[0] as List<Contact>;
    // Primero los de mayor puntaje; los sin calificar al final.
    contacts.sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
    setState(() {
      _contacts = contacts;
      _reminders = currentReminderByContact(results[1] as List<Reminder>);
      _profile = results[2] as Profile;
      _isLoading = false;
      _selection = _selection?.where((id) => contacts.any((c) => c.id == id)).toSet();
    });
  }

  Future<void> _open(Contact c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: c.id)),
    );
    _load();
  }

  Future<void> _export() async {
    await shareTextFile(
      fileName: 'contactos_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      mimeType: 'text/csv',
      content: exportContactsCsv(_contacts),
    );
  }

  Future<void> _import() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    );
    _load();
  }

  Future<void> _deleteOne(Contact c) async {
    final ok = await confirm(context, title: '¿Eliminar a ${c.name}?');
    if (!ok) return;
    await _service.deleteContact(c.id);
    _load();
  }

  Future<void> _showFilters() async {
    final tags = {for (final c in _contacts) ...c.tags}.toList()..sort();
    final sources = {
      for (final c in _contacts)
        if (c.source.isNotEmpty) c.source,
    }.toList()
      ..sort();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            builder: (context, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Filtros',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    TextButton(
                      onPressed: () => update(_filters.clear),
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Solo favoritos ⭐'),
                  value: _filters.onlyFavorites,
                  onChanged: (v) => update(() => _filters.onlyFavorites = v),
                ),
                const Text('Temperatura'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in Temperature.values)
                      ChoiceChip(
                        label: Text('${t.emoji} ${t.label}'),
                        selected: _filters.temperature == t,
                        onSelected: (on) =>
                            update(() => _filters.temperature = on ? t : null),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Etapa'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in Stage.values)
                      FilterChip(
                        label: Text(s.label),
                        selected: _filters.stages.contains(s),
                        onSelected: (on) => update(() =>
                            on ? _filters.stages.add(s) : _filters.stages.remove(s)),
                      ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Etiquetas'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final t in tags)
                        FilterChip(
                          label: Text(t),
                          selected: _filters.tags.contains(t),
                          onSelected: (on) => update(() =>
                              on ? _filters.tags.add(t) : _filters.tags.remove(t)),
                        ),
                    ],
                  ),
                ],
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Origen'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final s in sources)
                        ChoiceChip(
                          label: Text(s),
                          selected: _filters.source == s,
                          onSelected: (on) =>
                              update(() => _filters.source = on ? s : null),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _contacts
        .where((c) =>
            _filters.matches(c) && matchesSearch(c, _searchController.text))
        .toList();
    final visible = _category == null
        ? base
        : base.where((c) => c.category == _category).toList();
    final idealCount =
        _contacts.where((c) => c.category == Category.ideal).length;
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _GoalCard(current: idealCount, goal: _profile.idealGoal),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _import,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Importar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _contacts.isEmpty ? null : _export,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Exportar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Seleccionar',
                        isSelected: selection != null,
                        onPressed: () => setState(() =>
                            _selection = selection == null ? <String>{} : null),
                        icon: const Icon(Icons.check_box_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _showFilters,
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: Text(_filters.activeCount == 0
                          ? 'Filtros'
                          : 'Filtros (${_filters.activeCount})'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<Category?>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                          value: null, label: Text('Total\n${base.length}',
                              textAlign: TextAlign.center)),
                      for (final cat in Category.values)
                        ButtonSegment(
                          value: cat,
                          label: Text(
                            '${cat.label}\n${cat.emoji} '
                            '${base.where((c) => c.category == cat).length}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    selected: {_category},
                    onSelectionChanged: (v) =>
                        setState(() => _category = v.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nombre, teléfono o etiqueta...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    EmptyState(
                      icon: Icons.people_outline,
                      message: _contacts.isEmpty
                          ? 'Aún no tienes contactos.\nAgrégalos con el botón + o impórtalos.'
                          : 'Ningún contacto coincide.',
                    ),
                  for (final c in visible)
                    _CrmCard(
                      contact: c,
                      reminder: _reminders[c.id],
                      selected: selection?.contains(c.id),
                      onTap: selection == null
                          ? () => _open(c)
                          : () => setState(() => selection.contains(c.id)
                              ? selection.remove(c.id)
                              : selection.add(c.id)),
                      onLongPress: () =>
                          setState(() => _selection = {...?selection, c.id}),
                      onBell: () async {
                        if (await showNewReminderSheet(context, c) != null) {
                          _load();
                        }
                      },
                      onDelete: () => _deleteOne(c),
                    ),
                ],
              ),
            ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.current, required this.goal});

  final int current;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final missing = goal - current;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes, color: gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$current de $goal contactos ideales',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  missing > 0 ? 'Faltan $missing' : '¡Meta cumplida! 🎉',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal == 0 ? 1 : (current / goal).clamp(0, 1),
                minHeight: 8,
                color: gold,
                backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmCard extends StatelessWidget {
  const _CrmCard({
    required this.contact,
    required this.reminder,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onBell,
    required this.onDelete,
  });

  final Contact contact;
  final Reminder? reminder;

  /// null si no está en modo selección.
  final bool? selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onBell;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = contact.category;
    final snoozed = contact.isSnoozed(DateTime.now());
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              if (selected != null)
                Checkbox(value: selected, onChanged: (_) => onTap()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (category != null) ...[
                          const SizedBox(width: 6),
                          Text(category.emoji),
                        ],
                        if (contact.favorite) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: gold, size: 16),
                        ],
                      ],
                    ),
                    Text(
                      snoozed
                          ? '⏸ Pausado · ${contact.stage.label}'
                          : contact.stage.label,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                    if (contact.referredBy.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Pill(label: 'Ref: ${contact.referredBy}'),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    contact.score?.toString() ?? '–',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: category?.color ?? theme.colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('PTS',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
              if (selected == null) ...[
                ReminderBell(reminder: reminder, onPressed: onBell),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
