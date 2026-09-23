import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/interaction.dart';
import '../models/sale.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'contact_form_screen.dart';
import 'sales_screen.dart';

/// Ficha de un contacto: acciones rápidas, etapa, seguimiento, historial de
/// interacciones y compras.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _service = CrmService(Supabase.instance.client);

  Contact? _contact;
  List<Interaction> _interactions = [];
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contact = await _service.fetchContact(widget.contactId);
    final interactions = await _service.fetchInteractions(widget.contactId);
    final sales = await _service.fetchSales(contactId: widget.contactId);
    if (!mounted) return;
    setState(() {
      _contact = contact;
      _interactions = interactions;
      _sales = sales;
    });
  }

  Future<void> _setStage(Stage stage) async {
    await _service.setStage(widget.contactId, stage);
    _load();
  }

  Future<void> _setFollowUp(DateTime? date) async {
    await _service.setNextFollowUp(widget.contactId, date);
    _load();
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _contact!.nextFollowUp ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) _setFollowUp(picked);
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ContactFormScreen(contact: _contact)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text(
          '¿Eliminar a ${_contact!.name}? También se borrará su historial. '
          'Sus ventas se conservan sin contacto asignado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteContact(widget.contactId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addInteraction() async {
    final result = await showModalBottomSheet<(InteractionKind, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _InteractionSheet(),
    );
    if (result == null) return;
    await _service.addInteraction(widget.contactId, result.$1, result.$2);
    // Tras hablar con alguien que era "nuevo", ya está contactado.
    if (_contact!.stage == Stage.nuevo) {
      await _service.setStage(widget.contactId, Stage.contactado);
    }
    _load();
  }

  Future<void> _addSale() async {
    final added = await showAddSaleSheet(context, contact: _contact);
    if (added) _load();
  }

  @override
  Widget build(BuildContext context) {
    final contact = _contact;
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final hasPhone = contact.phone.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Center(child: ContactAvatar(contact: contact, radius: 40)),
            const SizedBox(height: 12),
            Text(
              contact.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Center(child: StageChip(stage: contact.stage)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QuickAction(
                  icon: Icons.call_outlined,
                  label: 'Llamar',
                  onPressed: hasPhone ? () => callContact(context, contact) : null,
                ),
                _QuickAction(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  onPressed:
                      hasPhone ? () => whatsappContact(context, contact) : null,
                ),
                _QuickAction(
                  icon: Icons.note_add_outlined,
                  label: 'Registrar',
                  onPressed: _addInteraction,
                ),
                _QuickAction(
                  icon: Icons.add_shopping_cart,
                  label: 'Venta',
                  onPressed: _addSale,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Etapa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in Stage.values)
                  ChoiceChip(
                    label: Text(s.label),
                    avatar: Icon(s.icon, size: 18, color: s.color),
                    selected: contact.stage == s,
                    onSelected: (_) => _setStage(s),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _FollowUpCard(
              date: contact.nextFollowUp,
              onPick: _pickFollowUp,
              onQuickPick: (days) => _setFollowUp(
                DateUtils.dateOnly(DateTime.now()).add(Duration(days: days)),
              ),
              onClear: () => _setFollowUp(null),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  if (hasPhone)
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(contact.phone),
                    ),
                  if (contact.email.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: Text(contact.email),
                    ),
                  if (contact.city.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(contact.city),
                    ),
                  ListTile(
                    leading: const Icon(Icons.favorite_border),
                    title: Text('Le interesa: ${contact.interest.label}'),
                    subtitle: contact.source.isEmpty
                        ? null
                        : Text('Origen: ${contact.source}'),
                  ),
                  if (contact.notes.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(contact.notes),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Historial', style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: _addInteraction,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar'),
                ),
              ],
            ),
            if (_interactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Todavía no registras interacciones.'),
              )
            else
              for (final i in _interactions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(i.kind.icon, size: 20)),
                  title: Text(i.note.isEmpty ? i.kind.label : i.note),
                  subtitle: Text(
                    '${i.kind.label} · '
                    '${DateFormat('d MMM y, HH:mm', 'es').format(i.occurredAt)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      await _service.deleteInteraction(i.id);
                      _load();
                    },
                  ),
                ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Compras', style: theme.textTheme.titleMedium),
                ),
                if (_sales.isNotEmpty)
                  Text(
                    currencyFormat.format(
                      _sales.fold<double>(0, (s, e) => s + e.amount),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
              ],
            ),
            if (_sales.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin compras registradas.'),
              )
            else
              for (final s in _sales)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(s.product),
                  subtitle: Text(DateFormat('d MMM y', 'es').format(s.saleDate)),
                  trailing: Text(currencyFormat.format(s.amount)),
                ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({
    required this.date,
    required this.onPick,
    required this.onQuickPick,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onPick;
  final ValueChanged<int> onQuickPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Próximo seguimiento'),
              subtitle: Text(
                date == null
                    ? 'Sin programar'
                    : DateFormat('EEEE d MMMM y', 'es').format(date!),
              ),
              trailing: date == null
                  ? null
                  : IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    ),
            ),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(label: const Text('Mañana'), onPressed: () => onQuickPick(1)),
                ActionChip(label: const Text('En 3 días'), onPressed: () => onQuickPick(3)),
                ActionChip(label: const Text('En 1 semana'), onPressed: () => onQuickPick(7)),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('Elegir'),
                  onPressed: onPick,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionSheet extends StatefulWidget {
  const _InteractionSheet();

  @override
  State<_InteractionSheet> createState() => _InteractionSheetState();
}

class _InteractionSheetState extends State<_InteractionSheet> {
  final _noteController = TextEditingController();
  InteractionKind _kind = InteractionKind.llamada;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registrar interacción',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final k in InteractionKind.values)
                ChoiceChip(
                  avatar: Icon(k.icon, size: 18),
                  label: Text(k.label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '¿Qué hablaron? ¿Qué sigue?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop((_kind, _noteController.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
