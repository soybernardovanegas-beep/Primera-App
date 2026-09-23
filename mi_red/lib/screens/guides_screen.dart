import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/guides.dart';
import '../models/profile.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';

/// Carga el texto vigente de una guía: el editado por el usuario o el de
/// la app, con {mi_porque} ya reemplazado.
Future<({String raw, String myWhy, bool edited})> loadGuide(Guide guide) async {
  final service = CrmService(Supabase.instance.client);
  final results = await Future.wait([
    service.fetchGuideOverrides(),
    service.fetchProfile(),
  ]);
  final overrides = results[0] as Map<String, String>;
  final profile = results[1] as Profile;
  return (
    raw: overrides[guide.key] ?? guide.defaultContent,
    myWhy: profile.myWhy,
    edited: overrides.containsKey(guide.key),
  );
}

/// Lista de todas las guías (desde Más).
class GuidesListScreen extends StatelessWidget {
  const GuidesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guías')),
      body: ListView(
        children: [
          for (final g in allGuides)
            ListTile(
              leading: Icon(g.icon, color: gold),
              title: Text(g.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GuideScreen(guide: g)),
              ),
            ),
        ],
      ),
    );
  }
}

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.guide});

  final Guide guide;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _service = CrmService(Supabase.instance.client);
  final _editController = TextEditingController();

  String? _raw;
  String _myWhy = '';
  bool _edited = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final g = await loadGuide(widget.guide);
      if (!mounted) return;
      setState(() {
        _raw = g.raw;
        _myWhy = g.myWhy;
        _edited = g.edited;
      });
    } catch (_) {
      if (mounted) setState(() => _raw = widget.guide.defaultContent);
    }
  }

  Future<void> _save() async {
    await _service.saveGuide(widget.guide.key, _editController.text);
    setState(() => _editing = false);
    _load();
  }

  Future<void> _reset() async {
    final ok = await confirm(
      context,
      title: '¿Restaurar el texto original?',
      message: 'Se perderán tus cambios en esta guía.',
      action: 'Restaurar',
    );
    if (!ok) return;
    await _service.resetGuide(widget.guide.key);
    setState(() => _editing = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final raw = _raw;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guide.title),
        actions: [
          if (_editing) ...[
            if (_edited)
              IconButton(
                tooltip: 'Restaurar original',
                icon: const Icon(Icons.restore),
                onPressed: _reset,
              ),
            TextButton(onPressed: _save, child: const Text('Guardar')),
          ] else if (raw != null)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() {
                _editController.text = raw;
                _editing = true;
              }),
            ),
        ],
      ),
      body: raw == null
          ? const Center(child: CircularProgressIndicator())
          : _editing
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Usa "## " para títulos y "- " para viñetas.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _editController,
                          expands: true,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GuideContent(
                      content: fillPlaceholders(raw, myWhy: _myWhy),
                      collapsible: widget.guide.key == guideObjeciones.key,
                    ),
                  ],
                ),
    );
  }
}

/// Muestra el texto de una guía con títulos, viñetas y párrafos. Con
/// [collapsible], cada sección se muestra como un desplegable.
class GuideContent extends StatelessWidget {
  const GuideContent({
    super.key,
    required this.content,
    this.collapsible = false,
  });

  final String content;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = parseSections(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in sections)
          if (collapsible && s.title.isNotEmpty)
            Card(
              child: ExpansionTile(
                shape: const Border(),
                title: Text(s.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [_Body(s.body)],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        s.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: gold, fontWeight: FontWeight.w600),
                      ),
                    ),
                  _Body(s.body),
                ],
              ),
            ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in text.split('\n'))
          if (line.trim().isEmpty)
            const SizedBox(height: 8)
          else if (line.trimLeft().startsWith('- '))
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: style?.copyWith(color: gold)),
                  Expanded(
                    child: Text(line.trimLeft().substring(2), style: style),
                  ),
                ],
              ),
            )
          else
            Text(line, style: style),
      ],
    );
  }
}
