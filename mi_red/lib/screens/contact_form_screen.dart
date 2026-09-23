import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../services/crm_service.dart';

/// Alta o edición de un contacto. Devuelve el [Contact] creado al hacer pop
/// (o `true` al editar).
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
  late final _emailController = TextEditingController(text: widget.contact?.email);
  late final _cityController = TextEditingController(text: widget.contact?.city);
  late final _sourceController = TextEditingController(text: widget.contact?.source);
  late final _notesController = TextEditingController(text: widget.contact?.notes);

  late Interest _interest = widget.contact?.interest ?? Interest.cliente;
  late Stage _stage = widget.contact?.stage ?? Stage.nuevo;
  late String? _sponsorId = widget.contact?.sponsorId;
  late DateTime? _nextFollowUp = widget.contact?.nextFollowUp;

  List<Contact> _partners = [];
  bool _isSaving = false;

  static const _sourceSuggestions = [
    'Mercado cálido',
    'Referido',
    'Redes sociales',
    'Evento',
    'Mercado frío',
  ];

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    final all = await _service.fetchContacts();
    if (!mounted) return;
    setState(() {
      _partners = all
          .where((c) => c.stage == Stage.socio && c.id != widget.contact?.id)
          .toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowUp ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _nextFollowUp = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final input = ContactInput(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      city: _cityController.text.trim(),
      source: _sourceController.text.trim(),
      interest: _interest,
      stage: _stage,
      sponsorId: _sponsorId,
      notes: _notesController.text.trim(),
      nextFollowUp: _nextFollowUp,
    );
    try {
      final existing = widget.contact;
      if (existing == null) {
        final created = await _service.addContact(input);
        if (mounted) Navigator.of(context).pop(created);
      } else {
        await _service.updateContact(existing.id, input);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si el patrocinador guardado ya no es socio, se muestra como "sin
    // patrocinador" para no romper el dropdown.
    final sponsorValue =
        _partners.any((p) => p.id == _sponsorId) ? _sponsorId : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'Nuevo contacto' : 'Editar contacto'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono / WhatsApp',
                helperText: 'Incluye la clave de país, ej. 52 55 1234 5678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
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
            TextFormField(
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: '¿De dónde viene?',
                prefixIcon: Icon(Icons.call_split_outlined),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final s in _sourceSuggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => _sourceController.text = s),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Le interesa', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<Interest>(
              segments: [
                for (final i in Interest.values)
                  ButtonSegment(value: i, label: Text(i.label)),
              ],
              selected: {_interest},
              onSelectionChanged: (v) => setState(() => _interest = v.first),
            ),
            const SizedBox(height: 20),
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
              decoration: const InputDecoration(
                labelText: 'Patrocinado por',
                helperText: 'Déjalo vacío si lo patrocinas tú directamente',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Yo (directo)')),
                for (final p in _partners)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _sponsorId = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Próximo seguimiento'),
              subtitle: Text(
                _nextFollowUp == null
                    ? 'Sin programar'
                    : DateFormat('EEEE d MMMM y', 'es').format(_nextFollowUp!),
              ),
              trailing: _nextFollowUp == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _nextFollowUp = null),
                    ),
              onTap: _pickFollowUp,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Notas (necesidades, objeciones, familia...)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
