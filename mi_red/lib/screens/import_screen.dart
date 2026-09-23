import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/calendar_links.dart';
import '../services/crm_service.dart';
import '../services/import_export.dart';
import '../widgets/common.dart';

class _Candidate {
  _Candidate(this.row, {required this.duplicate}) : selected = !duplicate;

  final ImportRow row;
  final bool duplicate;
  bool selected;
}

/// Importar contactos desde .csv, .xlsx, .vcf o pegando desde Excel.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _service = CrmService(Supabase.instance.client);

  List<_Candidate>? _candidates;
  bool _busy = false;

  Future<void> _preview(List<ImportRow> rows) async {
    if (rows.isEmpty) {
      showSnack(context, 'No se encontraron contactos. Revisa que haya una '
          'columna "Nombre".');
      return;
    }
    final existing = await _service.fetchContacts();
    final seen = {for (final c in existing) dedupeKey(c.name, c.phone)};
    final candidates = <_Candidate>[];
    for (final row in rows) {
      final key = dedupeKey(row.name, row.phone);
      candidates.add(_Candidate(row, duplicate: !seen.add(key)));
    }
    if (mounted) setState(() => _candidates = candidates);
  }

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'vcf', 'txt', 'tsv'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.xFile.readAsBytes();
      final ext = (file.extension ?? '').toLowerCase();
      final rows = switch (ext) {
        'xlsx' => parseExcel(bytes),
        'vcf' => parseVcf(utf8.decode(bytes, allowMalformed: true)),
        _ => parseDelimitedText(utf8.decode(bytes, allowMalformed: true)),
      };
      await _preview(rows);
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo leer el archivo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null) controller.text = clip!.text!;
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pegar desde Excel'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Copia las filas en Excel o Google Sheets y pégalas '
                  'aquí (Nombre, Teléfono, Referido, Origen)',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    await _preview(parseDelimitedText(text));
  }

  Future<void> _import() async {
    final chosen = _candidates!.where((c) => c.selected).toList();
    if (chosen.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.addContacts([for (final c in chosen) c.row.toInput()]);
      if (!mounted) return;
      showSnack(context, '${chosen.length} contactos importados ✅');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, 'No se pudo completar la importación.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    return Scaffold(
      appBar: AppBar(
        title: candidates == null ? null : const Text('Revisar contactos'),
      ),
      body: candidates == null ? _buildStart(context) : _buildPreview(candidates),
    );
  }

  Widget _buildStart(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.description_outlined, size: 48, color: gold),
              ),
            ),
            const SizedBox(height: 24),
            Text('Importar Contactos',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Sube contactos desde tu teléfono o iPhone (.vcf), Excel, CSV o '
              'pega desde tu hoja de cálculo. También sirve para traer tus '
              'contactos exportados de otra app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text(
              'Columnas: Nombre (obligatoria), Teléfono, Referido, Origen, Etiquetas',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Seleccionar archivo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Pegar desde Excel'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => shareTextFile(
                fileName: 'plantilla_contactos.csv',
                mimeType: 'text/csv',
                content: importTemplateCsv(),
              ),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Descargar plantilla de ejemplo'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(List<_Candidate> candidates) {
    final selectedCount = candidates.where((c) => c.selected).length;
    final duplicates = candidates.where((c) => c.duplicate).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${candidates.length} encontrados'
            '${duplicates > 0 ? ' · $duplicates posibles duplicados (desmarcados)' : ''}',
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final c = candidates[index];
              final details = [
                if (c.row.phone.isNotEmpty) c.row.phone,
                if (c.row.referredBy.isNotEmpty) 'Ref: ${c.row.referredBy}',
                if (c.row.source.isNotEmpty) c.row.source,
              ].join(' · ');
              return CheckboxListTile(
                value: c.selected,
                onChanged: (v) => setState(() => c.selected = v ?? false),
                title: Text(c.row.name),
                subtitle: Text(
                  c.duplicate ? '⚠️ Ya existe · $details' : details,
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _candidates = null),
                  child: const Text('Volver'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || selectedCount == 0 ? null : _import,
                    child: Text('Importar $selectedCount contactos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
