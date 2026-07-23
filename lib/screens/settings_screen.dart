import 'package:flutter/material.dart';

import '../models/reading_settings.dart';

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final ReadingSettings initialSettings;
  final ValueChanged<ReadingSettings> onChanged;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late ReadingSettings _settings = widget.initialSettings;

  static const _fontFamilies = ['Default', 'Serif', 'Georgia', 'Courier'];

  void _update(ReadingSettings Function(ReadingSettings) update) {
    setState(() => _settings = update(_settings));
    widget.onChanged(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Tamaño de letra: ${_settings.fontSize.round()}'),
            Slider(
              min: 12,
              max: 28,
              divisions: 16,
              value: _settings.fontSize,
              onChanged: (v) => _update((s) => s.copyWith(fontSize: v)),
            ),
            Text('Interlineado: ${_settings.lineHeight.toStringAsFixed(2)}'),
            Slider(
              min: 1.0,
              max: 2.0,
              divisions: 10,
              value: _settings.lineHeight,
              onChanged: (v) => _update((s) => s.copyWith(lineHeight: v)),
            ),
            const SizedBox(height: 8),
            const Text('Tipo de letra'),
            Wrap(
              spacing: 8,
              children: _fontFamilies
                  .map((family) => ChoiceChip(
                        label: Text(family),
                        selected: _settings.fontFamily == family,
                        onSelected: (_) =>
                            _update((s) => s.copyWith(fontFamily: family)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text('Tema'),
            Wrap(
              spacing: 8,
              children: ReaderTheme.values.map((theme) {
                return ChoiceChip(
                  label: Text(switch (theme) {
                    ReaderTheme.light => 'Claro',
                    ReaderTheme.dark => 'Oscuro',
                    ReaderTheme.sepia => 'Sepia',
                  }),
                  selected: _settings.theme == theme,
                  onSelected: (_) => _update((s) => s.copyWith(theme: theme)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
