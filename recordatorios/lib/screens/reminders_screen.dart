import 'package:flutter/material.dart';

import '../format.dart';
import '../models/reminder.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_store.dart';
import 'edit_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  final ReminderStore store;

  const RemindersScreen({super.key, required this.store});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _canPinWidget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotifications();
      widget.store.resync();
    }
  }

  Future<void> _init() async {
    await NotificationService.instance.requestPermission();
    await _checkNotifications();
    final canPin = await HomeWidgetService.instance.canPin();
    if (mounted) setState(() => _canPinWidget = canPin);
  }

  Future<void> _checkNotifications() async {
    final enabled = await NotificationService.instance.areEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _open([Reminder? reminder]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EditReminderScreen(store: widget.store, reminder: reminder),
      ),
    );
  }

  Future<void> _delete(Reminder r) async {
    await widget.store.delete(r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${r.title}" eliminado'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => widget.store.save(r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          if (_canPinWidget)
            IconButton(
              tooltip: 'Añadir widget a la pantalla de inicio',
              icon: const Icon(Icons.add_to_home_screen),
              onPressed: HomeWidgetService.instance.pin,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Nuevo'),
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final now = DateTime.now();
          final items = [...widget.store.reminders]
            ..sort((a, b) => _sortKey(a, now).compareTo(_sortKey(b, now)));
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (!_notificationsEnabled) const _NotificationsOffBanner(),
              if (items.isEmpty) const _EmptyState(),
              for (final r in items)
                Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => _delete(r),
                  child: _ReminderTile(
                    reminder: r,
                    now: now,
                    onTap: () => _open(r),
                    onToggle: (v) => widget.store.save(r.copyWith(enabled: v)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Primero los activos por próxima hora; al final los apagados y los pasados.
  DateTime _sortKey(Reminder r, DateTime now) {
    final next = r.enabled ? r.nextOccurrence(now) : null;
    return next ?? DateTime(9999);
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final DateTime now;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _ReminderTile({
    required this.reminder,
    required this.now,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final next = r.nextOccurrence(now);
    final active = r.enabled && next != null;
    final theme = Theme.of(context);
    final subtitle = [
      describeRepeat(r),
      if (active) 'próximo: ${describeWhen(next, now)}',
      if (next == null) 'ya pasó',
      if (r.note.isNotEmpty) r.note,
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: Text(
        formatTime(r.hour, r.minute),
        style: theme.textTheme.titleLarge?.copyWith(
          color: active ? theme.colorScheme.primary : theme.disabledColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      title: Text(
        r.title,
        style: active ? null : TextStyle(color: theme.disabledColor),
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Switch(value: r.enabled, onChanged: onToggle),
    );
  }
}

class _NotificationsOffBanner extends StatelessWidget {
  const _NotificationsOffBanner();

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.notifications_off_outlined),
      content: const Text(
        'Las notificaciones están desactivadas: los recordatorios no sonarán. '
        'Actívalas en Ajustes > Apps > Recordatorios > Notificaciones.',
      ),
      actions: [
        TextButton(
          onPressed: NotificationService.instance.requestPermission,
          child: const Text('Permitir'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(32, 96, 32, 0),
      child: Column(
        children: [
          Icon(Icons.alarm, size: 64),
          SizedBox(height: 16),
          Text(
            'Aún no tienes recordatorios.\nToca "Nuevo" para crear uno.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
