import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/message_templates.dart';
import '../models/contact.dart';
import '../models/reminder.dart';
import '../services/calendar_links.dart';
import '../services/crm_service.dart';
import 'common.dart';

/// Formulario para crear un recordatorio con fecha, hora y nota. Devuelve
/// el recordatorio creado, o null si se canceló.
Future<Reminder?> showNewReminderSheet(
  BuildContext context,
  Contact contact, {
  DateTime? initialDate,
  String initialNote = '',
}) {
  return showModalBottomSheet<Reminder>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NewReminderSheet(
      contact: contact,
      initialDate: initialDate,
      initialNote: initialNote,
    ),
  );
}

class _NewReminderSheet extends StatefulWidget {
  const _NewReminderSheet({
    required this.contact,
    required this.initialDate,
    required this.initialNote,
  });

  final Contact contact;
  final DateTime? initialDate;
  final String initialNote;

  @override
  State<_NewReminderSheet> createState() => _NewReminderSheetState();
}

class _NewReminderSheetState extends State<_NewReminderSheet> {
  final _service = CrmService(Supabase.instance.client);
  late final _noteController = TextEditingController(text: widget.initialNote);
  late DateTime _dueAt = widget.initialDate ?? _defaultDue();
  bool _saving = false;

  /// Mañana a las 9:00 a.m.
  static DateTime _defaultDue() {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, 9);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _quick(int days) {
    final t = DateTime.now().add(Duration(days: days));
    setState(() => _dueAt = DateTime(t.year, t.month, t.day, _dueAt.hour, _dueAt.minute));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt.isBefore(now) ? now : _dueAt,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() => _dueAt = DateTime(
        picked.year, picked.month, picked.day, _dueAt.hour, _dueAt.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (picked == null) return;
    setState(() => _dueAt = DateTime(
        _dueAt.year, _dueAt.month, _dueAt.day, picked.hour, picked.minute));
  }

  Future<void> _insertMyWhy() async {
    final profile = await _service.fetchProfile();
    if (!mounted) return;
    if (profile.myWhy.isEmpty) {
      showSnack(context, 'Escribe tu porqué en Más → Mi perfil.');
      return;
    }
    final text = _noteController.text.trim();
    _noteController.text =
        text.isEmpty ? profile.myWhy : '$text\n\nMi porqué: ${profile.myWhy}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final reminder = await _service.addReminder(
        widget.contact.id,
        _dueAt,
        _noteController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(reminder);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'No se pudo guardar el recordatorio.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recordatorio para ${widget.contact.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(label: const Text('Mañana'), onPressed: () => _quick(1)),
                ActionChip(label: const Text('En 3 días'), onPressed: () => _quick(3)),
                ActionChip(label: const Text('En 1 semana'), onPressed: () => _quick(7)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(DateFormat('EEE d MMM y', 'es').format(_dueAt)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(DateFormat('HH:mm').format(_dueAt)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: '¿Qué hacer? Ej: Confirmar asistencia al evento',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _insertMyWhy,
                icon: const Icon(Icons.favorite_border),
                label: const Text('Insertar Mi Porqué'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Guardar recordatorio'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opciones para llevar un recordatorio fuera de la app: enviarlo por
/// WhatsApp al contacto, o agregarlo a Google Calendar o como .ics.
Future<void> showReminderShareSheet(
  BuildContext context,
  Contact contact,
  Reminder reminder,
) {
  final title = 'Contactar a ${contact.name}';
  final details = [
    if (reminder.note.isNotEmpty) reminder.note,
    if (contact.phone.isNotEmpty) 'Tel: ${contact.phone}',
  ].join('\n');
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title),
            subtitle: Text(
                DateFormat("EEEE d 'de' MMMM, HH:mm", 'es').format(reminder.dueAt)),
          ),
          if (contact.hasPhone)
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('WhatsApp'),
              subtitle: const Text('Abre el chat con la nota del recordatorio'),
              onTap: () {
                Navigator.pop(sheetContext);
                whatsappContact(context, contact, text: reminder.note);
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Google Calendar'),
            onTap: () {
              Navigator.pop(sheetContext);
              launchExternal(
                context,
                googleCalendarUrl(
                    title: title, details: details, start: reminder.dueAt),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Archivo .ics'),
            subtitle: const Text('Para cualquier app de calendario'),
            onTap: () {
              Navigator.pop(sheetContext);
              shareTextFile(
                fileName: 'recordatorio.ics',
                mimeType: 'text/calendar',
                content: buildIcs(
                  uid: reminder.id,
                  title: title,
                  details: details,
                  start: reminder.dueAt,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// "Sugerir": elige un mensaje de plantilla, edítalo y envíalo por
/// WhatsApp.
Future<void> showSuggestSheet(BuildContext context, Contact contact) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SuggestSheet(contact: contact),
  );
}

class _SuggestSheet extends StatefulWidget {
  const _SuggestSheet({required this.contact});

  final Contact contact;

  @override
  State<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends State<_SuggestSheet> {
  final _controller = TextEditingController();
  late final _templates = templatesFor(widget.contact);
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    if (_templates.isNotEmpty) {
      _controller.text = fillTemplate(_templates.first, widget.contact);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _showAll ? messageTemplates : _templates;
    final contact = widget.contact;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mensaje sugerido', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${contact.stage.label} · ${contact.interest.emoji} ${contact.interest.label}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in options)
                  ActionChip(
                    label: Text(t.title),
                    onPressed: () => setState(
                        () => _controller.text = fillTemplate(t, contact)),
                  ),
                if (!_showAll)
                  ActionChip(
                    avatar: const Icon(Icons.more_horiz, size: 18),
                    label: const Text('Ver todas'),
                    onPressed: () => setState(() => _showAll = true),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: _controller.text));
                      if (context.mounted) showSnack(context, 'Mensaje copiado');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: contact.hasPhone
                        ? () {
                            whatsappContact(context, contact,
                                text: _controller.text);
                            Navigator.pop(context);
                          }
                        : null,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Marca un recordatorio como hecho. Si el contacto ya no tiene más
/// pendientes, ofrece programar el siguiente para no perderle el rastro.
Future<void> completeReminderFlow(
  BuildContext context,
  Reminder reminder,
  Contact? contact,
) async {
  final service = CrmService(Supabase.instance.client);
  await service.completeReminder(reminder.id);
  final pending =
      await service.fetchPendingReminders(contactId: reminder.contactId);
  if (!context.mounted || contact == null || pending.isNotEmpty) return;
  if (contact.stage == Stage.descartado) return;
  final schedule = await confirm(
    context,
    title: '¿Programar el siguiente?',
    message: '${contact.name} no tiene más recordatorios pendientes.',
    action: 'Programar',
  );
  if (schedule && context.mounted) {
    await showNewReminderSheet(context, contact);
  }
}

/// Campo de texto que se guarda solo mientras escribes (notas, porqué...).
class AutoSaveField extends StatefulWidget {
  const AutoSaveField({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.hintText,
    this.minLines = 3,
  });

  final String initialValue;
  final Future<void> Function(String value) onSave;
  final String? hintText;
  final int minLines;

  @override
  State<AutoSaveField> createState() => _AutoSaveFieldState();
}

class _AutoSaveFieldState extends State<AutoSaveField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  late String _saved = widget.initialValue;
  Timer? _debounce;
  bool _saving = false;

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _save);
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value == _saved) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(value);
      _saved = value;
    } catch (_) {
      if (mounted) showSnack(context, 'No se pudo guardar el texto.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Guarda lo último escrito al salir de la pantalla.
    final value = _controller.text.trim();
    if (value != _saved) widget.onSave(value);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: widget.minLines,
      maxLines: 10,
      textCapitalization: TextCapitalization.sentences,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        suffixIcon: _saving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }
}
