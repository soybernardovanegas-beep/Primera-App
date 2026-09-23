import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/interaction.dart';
import '../models/qualification.dart';
import '../models/reminder.dart';
import '../models/sale.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'call_mode_screen.dart';
import 'contact_form_screen.dart';
import 'qualification_screen.dart';
import 'sales_screen.dart';

/// Ficha de un contacto: calificación, enfoque, recordatorios, su porqué,
/// historial y compras.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _service = CrmService(Supabase.instance.client);

  Contact? _contact;
  List<Reminder> _reminders = [];
  List<Interaction> _interactions = [];
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _service.fetchContact(widget.contactId),
      _service.fetchPendingReminders(contactId: widget.contactId),
      _service.fetchInteractions(widget.contactId),
      _service.fetchSales(contactId: widget.contactId),
    ]);
    if (!mounted) return;
    setState(() {
      _contact = results[0] as Contact;
      _reminders = results[1] as List<Reminder>;
      _interactions = results[2] as List<Interaction>;
      _sales = results[3] as List<Sale>;
    });
  }

  Future<void> _update(Map<String, dynamic> fields) async {
    await _service.updateFields(widget.contactId, fields);
    _load();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _delete() async {
    final contact = _contact!;
    final ok = await confirm(
      context,
      title: 'Eliminar contacto',
      message: '¿Eliminar a ${contact.name}? También se borran sus '
          'recordatorios e historial. Sus ventas se conservan.',
    );
    if (!ok) return;
    await _service.deleteContact(contact.id);
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

  Future<void> _snooze(int months) async {
    final now = DateTime.now();
    final until = DateTime(now.year, now.month + months, now.day);
    await _service.snooze(widget.contactId, until);
    if (!mounted) return;
    showSnack(context,
        'Se reactivará el ${DateFormat('d MMM y', 'es').format(until)}');
    _load();
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
    final now = DateTime.now();
    final next = nextStage(contact.stage, contact.interest);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Favorito',
            icon: Icon(contact.favorite ? Icons.star : Icons.star_border,
                color: contact.favorite ? gold : null),
            onPressed: () => _update({'favorite': !contact.favorite}),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _push(ContactFormScreen(contact: contact)),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            Text(
              contact.name,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            CategoryLabel(contact: contact),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  label:
                      '${contact.temperature.emoji} ${contact.temperature.label}',
                  color: contact.temperature.color,
                  dense: false,
                  onTap: () => _update({
                    'temperature': contact.temperature == Temperature.frio
                        ? Temperature.caliente.name
                        : Temperature.frio.name,
                  }),
                ),
                StageChip(stage: contact.stage),
                if (contact.isSnoozed(now))
                  Pill(
                    label: '⏸ Pausado hasta '
                        '${DateFormat('d MMM y', 'es').format(contact.snoozedUntil!)}',
                    dense: false,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _push(CallModeScreen(contactId: contact.id)),
              icon: const Icon(Icons.call),
              label: const Text('Modo Llamada en Vivo 📞'),
            ),
            const SizedBox(height: 16),
            _ContactInfoCard(contact: contact),
            _ScoreCard(
              contact: contact,
              onQualify: () => _push(QualificationScreen(contact: contact)),
            ),
            SectionCard(
              title: 'Etapa',
              icon: Icons.flag_outlined,
              trailing: next == null
                  ? null
                  : TextButton.icon(
                      onPressed: () => _update({'stage': next.name}),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: Text(next.label),
                    ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in Stage.values)
                    ChoiceChip(
                      label: Text(s.label),
                      avatar: Icon(s.icon, size: 18, color: s.color),
                      selected: contact.stage == s,
                      onSelected: (_) => _update({'stage': s.name}),
                    ),
                ],
              ),
            ),
            SectionCard(
              title: 'Enfoque de conversación',
              subtitle: '¿De qué le vas a hablar a este contacto?',
              child: Wrap(
                spacing: 6,
                children: [
                  for (final i in Interest.values)
                    ChoiceChip(
                      label: Text('${i.emoji} ${i.label}'),
                      selected: contact.interest == i,
                      onSelected: (_) => _update({'interest': i.name}),
                    ),
                ],
              ),
            ),
            _RemindersCard(
              contact: contact,
              reminders: _reminders,
              onChanged: _load,
            ),
            SectionCard(
              title: 'Contactar después',
              icon: Icons.history_toggle_off,
              subtitle: 'Oculta este contacto y lo reactiva automáticamente '
                  'en el proceso después del tiempo seleccionado.',
              child: contact.isSnoozed(now)
                  ? OutlinedButton.icon(
                      onPressed: () async {
                        await _service.snooze(contact.id, null);
                        _load();
                      },
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: const Text('Reactivar ahora'),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (label, months) in const [
                          ('3 meses', 3),
                          ('6 meses', 6),
                          ('10 meses', 10),
                          ('1 año', 12),
                        ])
                          ActionChip(
                            label: Text(label),
                            onPressed: () => _snooze(months),
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'Notas',
              child: AutoSaveField(
                initialValue: contact.notes,
                hintText: 'Agrega notas sobre este contacto...',
                onSave: (v) => _service.updateFields(contact.id, {'notes': v}),
              ),
            ),
            SectionCard(
              title: 'Su Porqué',
              icon: Icons.favorite_border,
              subtitle: 'Anota lo que conoces de '
                  '${contact.name.split(' ').first} para conectar '
                  'emocionalmente en la presentación.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('💰 ¿POR QUÉ NECESITA INGRESOS ADICIONALES?'),
                  const SizedBox(height: 8),
                  AutoSaveField(
                    initialValue: contact.whyIncome,
                    minLines: 2,
                    onSave: (v) =>
                        _service.updateFields(contact.id, {'why_income': v}),
                  ),
                  const SizedBox(height: 16),
                  const Text('❤️ ¿POR QUÉ NECESITA CUIDAR SU SALUD?'),
                  const SizedBox(height: 8),
                  AutoSaveField(
                    initialValue: contact.whyHealth,
                    minLines: 2,
                    onSave: (v) =>
                        _service.updateFields(contact.id, {'why_health': v}),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Historial',
              icon: Icons.history,
              trailing: TextButton.icon(
                onPressed: _addInteraction,
                icon: const Icon(Icons.add),
                label: const Text('Registrar'),
              ),
              child: _interactions.isEmpty
                  ? const Text('Todavía no registras interacciones.')
                  : Column(
                      children: [
                        for (final i in _interactions)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(child: Icon(i.kind.icon, size: 20)),
                            title: Text(i.note.isEmpty ? i.kind.label : i.note),
                            subtitle: Text('${i.kind.label} · '
                                '${DateFormat('d MMM y, HH:mm', 'es').format(i.occurredAt)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                await _service.deleteInteraction(i.id);
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'Compras',
              icon: Icons.shopping_bag_outlined,
              trailing: TextButton.icon(
                onPressed: () async {
                  if (await showAddSaleSheet(context, contact: contact)) _load();
                },
                icon: const Icon(Icons.add),
                label: const Text('Venta'),
              ),
              child: _sales.isEmpty
                  ? const Text('Sin compras registradas.')
                  : Column(
                      children: [
                        for (final s in _sales)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.product),
                            subtitle: Text(
                                DateFormat('d MMM y', 'es').format(s.saleDate)),
                            trailing: Text(currencyFormat.format(s.amount)),
                          ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Total'),
                          trailing: Text(
                            currencyFormat.format(
                                _sales.fold<double>(0, (s, e) => s + e.amount)),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Teléfono',
      icon: Icons.phone_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.phone.isEmpty ? 'Sin teléfono' : contact.phone,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: contact.hasPhone
                    ? () => callContact(context, contact)
                    : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Llamar'),
              ),
              FilledButton.tonalIcon(
                onPressed: contact.hasPhone
                    ? () => whatsappContact(context, contact)
                    : null,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: () => showSuggestSheet(context, contact),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Sugerir'),
              ),
            ],
          ),
          if (contact.tags.isNotEmpty ||
              contact.referredBy.isNotEmpty ||
              contact.source.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (contact.referredBy.isNotEmpty)
                  Pill(label: 'Ref: ${contact.referredBy}'),
                if (contact.source.isNotEmpty)
                  Pill(label: 'Origen: ${contact.source}'),
                for (final t in contact.tags)
                  Pill(label: t, color: theme.colorScheme.outline),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text(
                'Creado: ${DateFormat('d/M/y').format(contact.createdAt)}',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.contact, required this.onQualify});

  final Contact contact;
  final VoidCallback onQualify;

  @override
  Widget build(BuildContext context) {
    final q = contact.qualification;
    return SectionCard(
      title: 'Puntuación',
      icon: Icons.star_outline,
      trailing: TextButton(
        onPressed: onQualify,
        child: Text(q == null ? 'Calificar' : 'Recalificar'),
      ),
      child: q == null
          ? const Text(
              'Aún no lo calificas. Responde 4 preguntas para saber si es '
              'Ideal 🦈, Potencial 🐬 o Incierto 🦔.')
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.2,
              crossAxisSpacing: 16,
              children: [
                for (var i = 0; i < qualificationQuestions.length; i++)
                  _ScoreBar(
                    label: qualificationQuestions[i].shortLabel,
                    value: q.points[i],
                    max: qualificationQuestions[i].maxPoints,
                  ),
              ],
            ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value, required this.max});

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value / max,
                  minHeight: 8,
                  color: gold,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _RemindersCard extends StatelessWidget {
  const _RemindersCard({
    required this.contact,
    required this.reminders,
    required this.onChanged,
  });

  final Contact contact;
  final List<Reminder> reminders;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return SectionCard(
      title: 'Recordatorios (${reminders.length})',
      icon: Icons.notifications_outlined,
      subtitle: 'Agrega varios recordatorios. Al completar uno, aparece el '
          'siguiente automáticamente.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, r) in reminders.indexed)
            Card(
              color: index == 0
                  ? (r.isOverdue(now)
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
                      : gold.withValues(alpha: 0.12))
                  : null,
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 12, right: 4),
                leading: Icon(
                  r.isOverdue(now)
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_outlined,
                  color: r.isOverdue(now) ? theme.colorScheme.error : gold,
                ),
                title: Text(
                    DateFormat("EEE d MMM y · HH:mm", 'es').format(r.dueAt)),
                subtitle: r.note.isEmpty ? null : Text('📝 ${r.note}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Enviar o agendar',
                      icon: const Icon(Icons.ios_share, size: 20),
                      onPressed: () =>
                          showReminderShareSheet(context, contact, r),
                    ),
                    IconButton(
                      tooltip: 'Hecho',
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        await completeReminderFlow(context, r, contact);
                        onChanged();
                      },
                    ),
                  ],
                ),
                onLongPress: () async {
                  final ok = await confirm(context,
                      title: '¿Eliminar este recordatorio?');
                  if (!ok) return;
                  await CrmService(Supabase.instance.client)
                      .deleteReminder(r.id);
                  onChanged();
                },
              ),
            ),
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No hay recordatorios pendientes.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              if (await showNewReminderSheet(context, contact) != null) {
                onChanged();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar recordatorio'),
          ),
        ],
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
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registrar interacción',
              style: Theme.of(context).textTheme.titleLarge),
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
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop((_kind, _noteController.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
