import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/sale.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'contact_detail_screen.dart';

/// Resumen del día: seguimientos pendientes, métricas del mes y embudo.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = CrmService(Supabase.instance.client);

  List<Contact> _contacts = [];
  List<Sale> _monthSales = [];
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
      final contacts = await _service.fetchContacts();
      final sales = await _service.fetchSales(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _monthSales = sales;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudieron cargar los datos. Revisa tu conexión.';
      });
    }
  }

  Future<void> _openContact(Contact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: contact.id)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final due = _contacts
        .where((c) => c.stage != Stage.descartado && c.isFollowUpDue(today))
        .toList()
      ..sort((a, b) => a.nextFollowUp!.compareTo(b.nextFollowUp!));
    final monthAmount = _monthSales.fold<double>(0, (s, e) => s + e.amount);
    final monthPoints = _monthSales.fold<double>(0, (s, e) => s + e.points);
    final newThisMonth = _contacts
        .where((c) =>
            c.createdAt.year == today.year && c.createdAt.month == today.month)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          toBeginningOfSentenceCase(
            DateFormat('EEEE d \'de\' MMMM', 'es').format(today),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  _MetricsGrid(
                    metrics: [
                      _Metric('Ventas del mes', currencyFormat.format(monthAmount),
                          Icons.attach_money),
                      _Metric('Puntos del mes', pointsFormat.format(monthPoints),
                          Icons.star_outline),
                      _Metric('Contactos nuevos', '$newThisMonth',
                          Icons.person_add_alt),
                      _Metric(
                        'Socios en tu red',
                        '${_contacts.where((c) => c.stage == Stage.socio).length}',
                        Icons.handshake_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    'Seguimientos para hoy',
                    trailing: due.isEmpty ? null : '${due.length}',
                  ),
                  if (due.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Estás al día.'),
                        subtitle: Text(
                          'Programa el próximo seguimiento desde la ficha de cada contacto.',
                        ),
                      ),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final c in due)
                            _FollowUpTile(
                              contact: c,
                              today: today,
                              onTap: () => _openContact(c),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Tu embudo'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _Funnel(contacts: _contacts),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => widget.onOpenTab(1),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Ver contactos'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: [
        for (final m in metrics)
          Card(
            margin: EdgeInsets.zero,
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(m.icon, color: scheme.onPrimaryContainer, size: 20),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m.value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    m.label,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Badge(label: Text(trailing!)),
          ],
        ],
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({
    required this.contact,
    required this.today,
    required this.onTap,
  });

  final Contact contact;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = contact.nextFollowUp!;
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    final when = days == 0
        ? 'Hoy'
        : days == 1
            ? 'Atrasado 1 día'
            : 'Atrasado $days días';
    return ListTile(
      onTap: onTap,
      leading: ContactAvatar(contact: contact),
      title: Text(contact.name),
      subtitle: Text(
        '$when · ${contact.stage.label}',
        style: days > 0
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: contact.phone.isEmpty
          ? null
          : IconButton(
              tooltip: 'WhatsApp',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => whatsappContact(context, contact),
            ),
    );
  }
}

class _Funnel extends StatelessWidget {
  const _Funnel({required this.contacts});

  final List<Contact> contacts;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in Stage.values)
        s: contacts.where((c) => c.stage == s).length,
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
