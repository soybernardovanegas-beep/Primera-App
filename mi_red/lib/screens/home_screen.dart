import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/interaction.dart';
import '../models/profile.dart';
import '../models/qualification.dart';
import '../models/reminder.dart';
import '../models/sale.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'contact_detail_screen.dart';
import 'power_hour_screen.dart';

const _quotes = [
  'Tu libertad financiera se construye contacto a contacto.',
  'La fortuna está en el seguimiento.',
  'No cuentes los días, haz que los días cuenten.',
  'Cada "no" te acerca a un "sí".',
  'Tu red es tu riqueza.',
  'La constancia vence al talento.',
  'Hoy siembras, mañana cosechas.',
  'Lo que haces cada día importa más que lo que haces de vez en cuando.',
  'Recuerda tu porqué: es tu motor cuando falte la motivación.',
  'Ayuda a otros a lograr sus sueños y lograrás los tuyos.',
];

/// Inicio: resumen del día, métricas del mes y estado de tu red.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = CrmService(Supabase.instance.client);

  List<Contact> _contacts = [];
  List<Reminder> _reminders = [];
  List<Sale> _monthSales = [];
  Profile _profile = const Profile();
  int _callsToday = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        _service.fetchContacts(),
        _service.fetchPendingReminders(),
        _service.fetchSales(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        ),
        _service.fetchProfile(),
        _service.countInteractionsSince(DateUtils.dateOnly(now),
            kind: InteractionKind.llamada),
      ]);
      if (!mounted) return;
      final contacts = results[0] as List<Contact>;
      final active = {
        for (final c in contacts)
          if (c.isActive(now)) c.id,
      };
      setState(() {
        _contacts = contacts;
        _reminders = currentReminderByContact(results[1] as List<Reminder>)
            .values
            .where((r) => active.contains(r.contactId))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
        _monthSales = results[2] as List<Sale>;
        _profile = results[3] as Profile;
        _callsToday = results[4] as int;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudieron cargar los datos. Revisa tu conexión y que '
            'hayas ejecutado supabase/schema_v2.sql.';
      });
    }
  }

  Future<void> _open(String contactId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: contactId)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    final overdue = _reminders.where((r) => r.isOverdue(now)).length;
    final dueToday = _reminders.where((r) => r.dueAt.isBefore(endOfToday)).toList();
    final laterToday = dueToday.length - overdue;
    final monthAmount = _monthSales.fold<double>(0, (s, e) => s + e.amount);
    final monthPoints = _monthSales.fold<double>(0, (s, e) => s + e.points);
    final newThisMonth = _contacts
        .where((c) =>
            c.createdAt.year == now.year && c.createdAt.month == now.month)
        .length;
    final quote = _quotes[now.difference(DateTime(now.year)).inDays % _quotes.length];
    final name = _profile.displayName.isEmpty
        ? ''
        : ', ${_profile.displayName.split(' ').first}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Row(
            children: [
              Text('Mi', style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
              Text('Red', style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: gold)),
              const Text(' 💎', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Hola$name 👋', style: theme.textTheme.titleLarge),
          Text(
            toBeginningOfSentenceCase(
                DateFormat("EEEE d 'de' MMMM", 'es').format(now)),
            style: TextStyle(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Text('"$quote" ✨',
              style: TextStyle(
                  fontStyle: FontStyle.italic, color: theme.colorScheme.outline)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Tu día',
            icon: Icons.today_outlined,
            trailing: TextButton(
              onPressed: () => widget.onOpenTab(2),
              child: const Text('Ir a Proceso'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _DayStat('$overdue', 'Vencidos', theme.colorScheme.error),
                    _DayStat('$laterToday', 'Para hoy', gold),
                    _DayStat('$_callsToday', 'Llamadas hoy', const Color(0xFF2EBD85)),
                  ],
                ),
                if (dueToday.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final r in dueToday.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        Icons.notifications_outlined,
                        color: r.isOverdue(now) ? theme.colorScheme.error : gold,
                      ),
                      title: Text(r.contactName),
                      subtitle: r.note.isEmpty
                          ? null
                          : Text(r.note, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(r.contactId),
                    ),
                ],
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
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
              trailing: const Icon(Icons.play_circle_outline, color: gold),
              onTap: () async {
                await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PowerHourScreen()));
                _load();
              },
            ),
          ),
          _MetricsGrid(metrics: [
            ('Ventas del mes', currencyFormat.format(monthAmount), Icons.attach_money),
            ('Puntos del mes', pointsFormat.format(monthPoints), Icons.star_outline),
            ('Contactos nuevos', '$newThisMonth', Icons.person_add_alt),
            (
              'Socios en tu red',
              '${_contacts.where((c) => c.stage == Stage.socio).length}',
              Icons.handshake_outlined,
            ),
          ]),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Calidad de tu lista',
            icon: Icons.track_changes,
            trailing: Text(
              '${_contacts.where((c) => c.category == Category.ideal).length}'
              '/${_profile.idealGoal} ideales',
              style: const TextStyle(color: gold),
            ),
            child: Row(
              children: [
                for (final cat in Category.values)
                  _DayStat(
                    '${_contacts.where((c) => c.category == cat).length}',
                    '${cat.label} ${cat.emoji}',
                    cat.color,
                  ),
                _DayStat(
                  '${_contacts.where((c) => c.category == null).length}',
                  'Sin calificar',
                  theme.colorScheme.outline,
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Tu embudo',
            icon: Icons.filter_alt_outlined,
            child: _Funnel(contacts: _contacts),
          ),
        ],
      ),
    );
  }
}

class _DayStat extends StatelessWidget {
  const _DayStat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<(String, String, IconData)> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: [
        for (final (label, value, icon) in metrics)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: gold, size: 20),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(label,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Funnel extends StatelessWidget {
  const _Funnel({required this.contacts});

  final List<Contact> contacts;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in Stage.values) s: contacts.where((c) => c.stage == s).length,
    };
    final max = counts.values.fold<int>(1, (m, v) => v > m ? v : m);
    return Column(
      children: [
        for (final s in Stage.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 108, child: Text(s.label)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: counts[s]! / max,
                      minHeight: 12,
                      color: s.color,
                      backgroundColor: s.color.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${counts[s]}', textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
