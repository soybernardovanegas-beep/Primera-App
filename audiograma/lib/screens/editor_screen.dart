import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_options.dart';
import '../services/video_renderer.dart';
import '../widgets/video_preview.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _renderer = VideoRenderer();

  String? _audioPath;
  Duration? _audioLength;
  String? _imagePath;
  VideoFormat _format = VideoFormat.vertical;
  WaveStyle _waveStyle = WaveStyle.centered;
  Color _waveColor = waveColors.first;

  bool _rendering = false;
  double _progress = 0;
  String? _resultPath;

  Future<void> _pickAudio() async {
    final path = await _pickLocalFile(FileType.audio);
    if (path == null) return;
    final length = await VideoRenderer.audioDuration(path);
    if (!mounted) return;
    if (length == null) {
      _showError('No se pudo leer el audio. Prueba con un MP3, M4A o WAV.');
      return;
    }
    setState(() {
      _audioPath = path;
      _audioLength = length;
      _resultPath = null;
    });
  }

  Future<void> _pickImage() async {
    final path = await _pickLocalFile(FileType.image);
    if (path == null) return;
    setState(() {
      _imagePath = path;
      _resultPath = null;
    });
  }

  /// FFmpeg necesita una ruta en disco. Si el selector devuelve un archivo
  /// que no está en disco (p. ej. un `content://` de Android), se copia
  /// primero a la carpeta temporal de la app.
  Future<String?> _pickLocalFile(FileType type) async {
    final file = await FilePicker.pickFile(type: type);
    if (file == null) return null;
    if (file.path != null) return file.path;
    final dir = await getTemporaryDirectory();
    final copy = File(p.join(dir.path, file.name));
    final sink = copy.openWrite();
    await sink.addStream(file.readAsByteStream());
    await sink.close();
    return copy.path;
  }

  Future<void> _render() async {
    final audioPath = _audioPath;
    final audioLength = _audioLength;
    if (audioPath == null || audioLength == null) return;

    final dir = await getTemporaryDirectory();
    final output = p.join(
      dir.path,
      'audiograma_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    setState(() {
      _rendering = true;
      _progress = 0;
      _resultPath = null;
    });

    try {
      await _renderer.render(
        VideoOptions(
          audioPath: audioPath,
          outputPath: output,
          imagePath: _imagePath,
          format: _format,
          waveStyle: _waveStyle,
          waveColor: _waveColor,
        ),
        audioLength: audioLength,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) setState(() => _resultPath = output);
    } on RenderCancelled {
      _deleteQuietly(output);
    } on RenderException catch (e) {
      _deleteQuietly(output);
      debugPrint(e.log);
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  Future<void> _save() async {
    final path = _resultPath;
    if (path == null) return;
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Guardar vídeo',
      fileName: 'audiograma_${_format.name}.mp4',
      mimeType: 'video/mp4',
      bytes: await File(path).readAsBytes(),
    );
    if (saved == null) return;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vídeo guardado')));
    }
  }

  Future<void> _share() async {
    final path = _resultPath;
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'video/mp4')]),
    );
  }

  void _deleteQuietly(String path) {
    File(path).delete().ignore();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _resultPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Audio a vídeo')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(theme, '1. Audio'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.audiotrack),
                    title: Text(
                      _audioPath == null
                          ? 'Elegir audio'
                          : p.basename(_audioPath!),
                    ),
                    subtitle: _audioLength == null
                        ? const Text('MP3, M4A, WAV, OGG…')
                        : Text('Duración ${_formatDuration(_audioLength!)}'),
                    trailing: const Icon(Icons.folder_open),
                    onTap: _rendering ? null : _pickAudio,
                  ),
                ),
                _section(theme, '2. Imagen de fondo'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.image),
                    title: Text(
                      _imagePath == null
                          ? 'Elegir imagen (opcional)'
                          : p.basename(_imagePath!),
                    ),
                    subtitle: const Text(
                      'Se recorta al centro para llenar el formato',
                    ),
                    trailing: _imagePath == null
                        ? const Icon(Icons.folder_open)
                        : IconButton(
                            tooltip: 'Quitar imagen',
                            icon: const Icon(Icons.close),
                            onPressed: _rendering
                                ? null
                                : () => _update(() => _imagePath = null),
                          ),
                    onTap: _rendering ? null : _pickImage,
                  ),
                ),
                _section(theme, '3. Formato'),
                SegmentedButton<VideoFormat>(
                  segments: [
                    for (final f in VideoFormat.values)
                      ButtonSegment(
                        value: f,
                        label: Text(f.label.split(' ').last),
                        tooltip: '${f.label} · ${f.hint}',
                      ),
                  ],
                  selected: {_format},
                  onSelectionChanged: _rendering
                      ? null
                      : (s) => _update(() => _format = s.single),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_format.label} · ${_format.hint}',
                  style: theme.textTheme.bodySmall,
                ),
                _section(theme, '4. Onda'),
                SegmentedButton<WaveStyle>(
                  segments: [
                    for (final s in WaveStyle.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_waveStyle},
                  onSelectionChanged: _rendering
                      ? null
                      : (s) => _update(() => _waveStyle = s.single),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final c in waveColors)
                      _ColorSwatch(
                        color: c,
                        selected: c == _waveColor,
                        onTap: _rendering
                            ? null
                            : () => _update(() => _waveColor = c),
                      ),
                  ],
                ),
                _section(theme, 'Vista previa'),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: VideoPreview(
                      format: _format,
                      waveStyle: _waveStyle,
                      waveColor: _waveColor,
                      imagePath: _imagePath,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_rendering) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Generando… ${(_progress * 100).round()} %',
                        ),
                      ),
                      TextButton(
                        onPressed: _renderer.cancel,
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ] else if (_resultPath != null) ...[
                  Text('¡Vídeo listo!', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                        ),
                      ),
                    ],
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _audioPath == null ? null : _render,
                    icon: const Icon(Icons.movie_creation),
                    label: const Text('Generar vídeo'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: theme.textTheme.titleSmall),
  );
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
