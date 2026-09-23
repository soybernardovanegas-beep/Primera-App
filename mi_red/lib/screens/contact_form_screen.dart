import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'qualification_screen.dart';

const sourceSuggestions = [
  'Instagram',
  'Facebook',
  'WhatsApp',
  'Evento',
  'Mercado en frío',
  'Lista caliente',
  'Referido directo',
];

const defaultTags = [
  'Amigo',
  'Familia',
  'Trabajo',
  'Gym',
  'Evento',
  'Red social',
  'Referido',
  'Desconocido',
];

/// Alta o edición de un contacto. Al crear, sigue con el cuestionario de
/// calificación. Al editar, devuelve `true` si se guardó.
class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({super.key, this.contact});

  final Contact? contact;

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _service = CrmService(Supabase.instance.client);
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.contact?.name);
  late final _phoneController = TextEditingController(text: widget.contact?.phone);
  late final _referredController =
      TextEditingController(text: widget.contact?.referredBy);
  late final _sourceController = TextEditingController(text: widget.contact?.source);
  late final _emailController = TextEditingController(text: widget.contact?.email);
  late final _cityController = TextEditingController(text: widget.contact?.city);
  late final _notesController = TextEditingController(text: widget.contact?.notes);

  late final Set<String> _tags = {...?widget.contact?.tags};
  late Interest _interest = widget.contact?.interest ?? Interest.ambos;
  late Temperature _temperature = widget.contact?.temperature ?? Temperature.frio;
  late Stage _stage = widget.contact?.stage ?? Stage.nuevo;
  late String? _sponsorId = widget.contact?.sponsorId;

  List<Contact> _partners = [];
  bool _saving = false;

  bool get _isNew => widget.contact == null;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    try {
      final all = await _service.fetchContacts();
      if (!mounted) return;
      setState(() {
        _partners = all
            .where((c) => c.stage == Stage.socio && c.id != widget.contact?.id)
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _phoneController,
      _referredController,
      _sourceController,
      _emailController,
      _cityController,
      _notesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickSource(String source) {
    setState(() {
      _sourceController.text = source;
      if (source == 'Mercado en frío') _temperature = Temperature.frio;
      if (source == 'Lista caliente') _temperature = Temperature.caliente;
    });
  }

  Future<void> _addCustomTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva etiqueta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = tag?.trim() ?? '';
    if (clean.isNotEmpty) setState(() => _tags.add(clean));
  }

  ContactInput _input() => ContactInput(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        referredBy: _referredController.text.trim(),
        source: _sourceController.text.trim(),
        tags: _tags.toList(),
        interest: _interest,
        temperature: _temperature,
        stage: _stage,
        sponsorId: _partners.any((p) => p.id == _sponsorId) ? _sponsorId : null,
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        notes: _notesController.text.trim(),
      );

  Future<void> _save({required bool qualify}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isNew) {
        final created = await _service.addContact(_input());
        if (!mounted) return;
        if (qualify) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QualificationScreen(contact: created),
            ),
          );
        } else {
          Navigator.of(context).pop(created);
        }
      } else {
        await _service.updateContact(widget.contact!.id, _input());
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'No se pudo guardar. Intenta de nuevo.');
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final allTags = {...defaultTags, ..._tags};
    final sponsorValue =
        _partners.any((p) => p.id == _sponsorId) ? _sponsorId : null;
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              _isNew ? 'Nuevo Contacto' : 'Editar Contacto',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_isNew)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '"Tu libertad financiera se construye contacto a contacto" ✨',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            _label('Nombre *'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
            ),
            _label('Teléfono (opcional)'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Ej: 3124578790'),
            ),
            _label('👤 Referido por (opcional)'),
            TextFormField(
              controller: _referredController,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(hintText: 'Nombre de quien lo refirió'),
            ),
            _label('📍 Origen del contacto (opcional)'),
            TextFormField(
              controller: _sourceController,
              decoration: const InputDecoration(
                  hintText: 'Ej: Instagram, Evento, WhatsApp...'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in sourceSuggestions)
                  ChoiceChip(
                    label: Text(s),
                    selected: _sourceController.text == s,
                    onSelected: (_) => _pickSource(s),
                  ),
              ],
            ),
            _label('Etiquetas (opcional)'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in allTags)
                  FilterChip(
                    label: Text(t),
                    selected: _tags.contains(t),
                    onSelected: (on) =>
                        setState(() => on ? _tags.add(t) : _tags.remove(t)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Otra'),
                  onPressed: _addCustomTag,
                ),
              ],
            ),
            _label('Enfoque de conversación'),
            SegmentedButton<Interest>(
              segments: [
                for (final i in Interest.values)
                  ButtonSegment(value: i, label: Text('${i.emoji} ${i.label}')),
              ],
              selected: {_interest},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _interest = v.first),
            ),
            _label('Temperatura'),
            SegmentedButton<Temperature>(
              segments: [
                for (final t in Temperature.values)
                  ButtonSegment(value: t, label: Text('${t.emoji} ${t.label}')),
              ],
              selected: {_temperature},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _temperature = v.first),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Más datos'),
              subtitle: const Text('Correo, ciudad, etapa, patrocinador, notas'),
              initiallyExpanded: !_isNew,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Stage>(
                  initialValue: _stage,
                  decoration: const InputDecoration(
                    labelText: 'Etapa',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: [
                    for (final s in Stage.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _stage = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: sponsorValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Patrocinado por (en tu equipo)',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Yo (directo)')),
                    for (final p in _partners)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _sponsorId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isNew) ...[
              FilledButton(
                onPressed: _saving ? null : () => _save(qualify: true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Comenzar Calificación'),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward),
                  ],
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => _save(qualify: false),
                child: const Text('Guardar sin calificar'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(qualify: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
          ],
        ),
      ),
    );
  }
}
