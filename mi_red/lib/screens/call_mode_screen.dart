import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/guides.dart';
import '../models/contact.dart';
import '../models/interaction.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'guides_screen.dart';

/// Resultado de una llamada, registrado con un toque.
enum CallOutcome {
  noContesto('No contestó', Icons.phone_missed_outlined, Color(0xFF90A4AE)),
  agendo('Agendó cita', Icons.event_available_outlined, Color(0xFF2EBD85)),
  seguimiento('Seguimiento', Icons.schedule_outlined, Color(0xFFFFA726)),
  noInteresado('No interesado', Icons.block_outlined, Color(0xFFEF5350));

  const CallOutcome(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Etapa a la que pasa el contacto según el resultado. Solo avanza (nunca
/// regresa a un cliente o socio a una etapa anterior).
Stage? stageAfterCall(Stage current, CallOutcome outcome) {
  final target = switch (outcome) {
    CallOutcome.noContesto => null,
    CallOutcome.agendo => Stage.presentacion,
    CallOutcome.seguimiento => Stage.seguimiento,
    CallOutcome.noInteresado => Stage.descartado,
  };
  if (target == null) return null;
  if (target == Stage.descartado) {
    return current == Stage.cliente || current == Stage.socio ? null : target;
  }
  return current.index < target.index ? target : null;
}

/// Pantalla para usar durante la llamada: guion según el enfoque, su
/// porqué, respuestas a objeciones y botones de resultado. Al registrar un
/// resultado hace pop con el [CallOutcome].
class CallModeScreen extends StatefulWidget {
  const CallModeScreen({super.key, required this.contactId, this.powerHour = false});

  final String contactId;

  /// En la Hora de Poder muestra "Siguiente" en lugar de cerrar.
  final bool powerHour;

  @override
  State<CallModeScreen> createState() => _CallModeScreenState();
}

class _CallModeScreenState extends State<CallModeScreen> {
  final _service = CrmService(Supabase.instance.client);
  final _noteController = TextEditingController();

  Contact? _contact;
  String _productScript = guideGuionProducto.defaultContent;
  String _businessScript = guideGuionNegocio.defaultContent;
  String _objections = guideObjeciones.defaultContent;
  String _myWhy = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contact = await _service.fetchContact(widget.contactId);
    if (mounted) setState(() => _contact = contact);
    try {
      final guides = await Future.wait([
        loadGuide(guideGuionProducto),
        loadGuide(guideGuionNegocio),
        loadGuide(guideObjeciones),
      ]);
      if (!mounted) return;
      setState(() {
        _productScript = guides[0].raw;
        _businessScript = guides[1].raw;
        _objections = guides[2].raw;
        _myWhy = guides[0].myWhy;
      });
    } catch (_) {
      // Se quedan los textos por defecto.
    }
  }

  Future<DateTime?> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: '¿Qué día es la cita?',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: '¿A qué hora?',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _register(CallOutcome outcome) async {
    final contact = _contact!;
    final note = _noteController.text.trim();
    final now = DateTime.now();

    DateTime? reminderAt;
    String reminderNote = '';
    switch (outcome) {
      case CallOutcome.noContesto:
        reminderAt = DateTime(now.year, now.month, now.day + 1, now.hour, now.minute);
        reminderNote = 'Volver a llamar (no contestó)';
      case CallOutcome.agendo:
        reminderAt = await _pickDateTime();
        if (reminderAt == null) return;
        reminderNote = note.isEmpty ? 'Cita / presentación' : 'Cita: $note';
      case CallOutcome.seguimiento:
        reminderAt = DateTime(now.year, now.month, now.day + 3, 10);
        reminderNote = note.isEmpty ? 'Seguimiento de la llamada' : note;
      case CallOutcome.noInteresado:
        break;
    }

    setState(() => _saving = true);
    try {
      await _service.addInteraction(
        contact.id,
        InteractionKind.llamada,
        [outcome.label, if (note.isNotEmpty) note].join(': '),
      );
      final stage = stageAfterCall(contact.stage, outcome);
      if (stage != null) await _service.setStage(contact.id, stage);
      if (reminderAt != null) {
        await _service.addReminder(contact.id, reminderAt, reminderNote);
      }
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'No se pudo registrar la llamada.');
    }
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
    final scripts = [
      if (contact.interest != Interest.socio)
        ('🛍️ Producto', _productScript),
      if (contact.interest != Interest.cliente)
        ('💼 Negocio', _businessScript),
    ];

    return DefaultTabController(
      length: scripts.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Llamada en Vivo 📞'),
          actions: [
            if (widget.powerHour)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Saltar'),
              ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(contact.name,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    CategoryLabel(contact: contact),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StageChip(stage: contact.stage),
                        Pill(label: '${contact.interest.emoji} ${contact.interest.label}'),
                        Pill(
                          label: '${contact.temperature.emoji} ${contact.temperature.label}',
                          color: contact.temperature.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: contact.hasPhone
                                ? () => callContact(context, contact)
                                : null,
                            icon: const Icon(Icons.call),
                            label: Text(contact.hasPhone
                                ? 'Llamar ${contact.phone}'
                                : 'Sin teléfono'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'WhatsApp',
                          onPressed: contact.hasPhone
                              ? () => whatsappContact(context, contact)
                              : null,
                          icon: const Icon(Icons.chat_outlined),
                        ),
                      ],
                    ),
                    if (contact.whyIncome.isNotEmpty ||
                        contact.whyHealth.isNotEmpty ||
                        contact.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: gold.withValues(alpha: 0.10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (contact.whyIncome.isNotEmpty)
                                Text('💰 ${contact.whyIncome}'),
                              if (contact.whyHealth.isNotEmpty)
                                Text('❤️ ${contact.whyHealth}'),
                              if (contact.notes.isNotEmpty)
                                Text('📝 ${contact.notes}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final s in scripts) Tab(text: 'Guion ${s.$1}'),
                  const Tab(text: 'Objeciones'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              for (final s in scripts)
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GuideContent(
                      content: fillPlaceholders(s.$2,
                          name: contact.name, myWhy: _myWhy),
                    ),
                  ],
                ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GuideContent(
                    content: fillPlaceholders(_objections, name: contact.name),
                    collapsible: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Nota rápida de la llamada (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 4,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (final o in CallOutcome.values)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: o.color,
                          side: BorderSide(color: o.color.withValues(alpha: 0.5)),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _saving ? null : () => _register(o),
                        icon: Icon(o.icon, size: 18),
                        label: Text(o.label),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
