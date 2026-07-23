import 'dart:async';
import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:html/parser.dart' show parse;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/bookmark.dart';
import '../models/highlight.dart';
import '../models/reading_settings.dart';
import '../services/bookmarks_service.dart';
import '../services/dictionary_service.dart';
import '../services/highlights_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../services/stats_service.dart';
import 'bookmarks_screen.dart';
import 'highlights_screen.dart';
import 'settings_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _progressService = ProgressService(Supabase.instance.client);
  final _bookmarksService = BookmarksService(Supabase.instance.client);
  final _highlightsService = HighlightsService(Supabase.instance.client);
  final _settingsService = SettingsService(Supabase.instance.client);
  final _statsService = StatsService(Supabase.instance.client);
  final _dictionaryService = DictionaryService();
  final _tts = FlutterTts();

  EpubController? _controller;
  List<String> _chapterTexts = [];
  ReadingSettings _settings = const ReadingSettings();
  bool _isLoading = true;
  bool _isSpeaking = false;
  int? _speakingChapterIndex;
  Timer? _saveDebounce;
  final DateTime _sessionStart = DateTime.now();
  String _lastSelectedText = '';

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(_onTtsChapterDone);
    _init();
  }

  Future<void> _init() async {
    final progress = await _progressService.fetchProgress(widget.book.id);
    final settings = await _settingsService.fetchSettings();

    final documentFuture = EpubDocument.openFile(File(widget.book.localPath));
    documentFuture.then((EpubBook book) {
      final texts = <String>[];
      for (final chapter in book.Chapters ?? const <EpubChapter>[]) {
        texts.add(_plainText(chapter.HtmlContent));
        for (final sub in chapter.SubChapters ?? const <EpubChapter>[]) {
          texts.add(_plainText(sub.HtmlContent));
        }
      }
      if (mounted) setState(() => _chapterTexts = texts);
    });

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _controller = EpubController(
        document: documentFuture,
        epubCfi: progress?.location,
      );
      _isLoading = false;
    });
  }

  String _plainText(String? html) {
    if (html == null || html.isEmpty) return '';
    try {
      return parse(html).body?.text ?? '';
    } catch (_) {
      return '';
    }
  }

  void _onChapterChanged(dynamic value) {
    if (value == null || _controller == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _saveProgress);
  }

  Future<void> _saveProgress() async {
    final controller = _controller;
    if (controller == null) return;
    final cfi = controller.generateEpubCfi();
    if (cfi == null) return;

    final totalChapters = controller.tableOfContents().length;
    final value = controller.currentValueListenable.value;
    double percentage = 0;
    if (value != null && totalChapters > 0) {
      percentage = ((value.chapterNumber - 1 + value.progress / 100) /
              totalChapters) *
          100;
      percentage = percentage.clamp(0, 100);
    }

    await _progressService.saveProgress(
      widget.book.id,
      location: cfi,
      percentage: percentage,
    );
  }

  Future<void> _addBookmark() async {
    final controller = _controller;
    if (controller == null) return;
    final cfi = controller.generateEpubCfi();
    if (cfi == null) return;
    final chapterTitle =
        controller.currentValueListenable.value?.chapter?.Title
            ?.replaceAll('\n', '')
            .trim();

    await _bookmarksService.addBookmark(widget.book.id, cfi, chapterTitle);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marcador guardado')));
    }
  }

  Future<void> _openBookmarks() async {
    final bookmark = await Navigator.of(context).push<Bookmark>(
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(bookId: widget.book.id),
      ),
    );
    if (bookmark != null) _controller?.gotoEpubCfi(bookmark.cfi);
  }

  Future<void> _openHighlights() async {
    final highlight = await Navigator.of(context).push<Highlight>(
      MaterialPageRoute(
        builder: (_) => HighlightsScreen(bookId: widget.book.id),
      ),
    );
    if (highlight != null) _controller?.gotoEpubCfi(highlight.cfi);
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReaderSettingsSheet(
        initialSettings: _settings,
        onChanged: (settings) {
          setState(() => _settings = settings);
          _settingsService.saveSettings(settings);
        },
      ),
    );
  }

  Future<void> _saveHighlight(String text) async {
    final controller = _controller;
    if (controller == null || text.trim().isEmpty) return;
    final cfi = controller.generateEpubCfi();
    if (cfi == null) return;

    var color = 'yellow';
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resaltar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: highlightColors.entries.map((entry) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => color = entry.key),
                      child: CircleAvatar(
                        backgroundColor: entry.value,
                        child: color == entry.key
                            ? const Icon(Icons.check, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(hintText: 'Nota (opcional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _highlightsService.addHighlight(
      bookId: widget.book.id,
      cfi: cfi,
      snippet: text.trim(),
      color: color,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Resaltado guardado')));
    }
  }

  void _showDefinition(String text) {
    final word = text.trim().split(RegExp(r'\s+')).first;
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder<List<String>>(
        future: _dictionaryService.lookup(word),
        builder: (context, snapshot) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    const Text(
                      'No se encontró definición (el diccionario solo cubre inglés y requiere internet).',
                    )
                  else
                    ...snapshot.data!.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(d),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _selectionToolbarBuilder(
    BuildContext context,
    SelectableRegionState state,
  ) {
    final content = _lastSelectedText;
    final items = List<ContextMenuButtonItem>.from(state.contextMenuButtonItems);
    if (content.trim().isNotEmpty) {
      items.addAll([
        ContextMenuButtonItem(
          label: 'Definir',
          onPressed: () {
            state.hideToolbar();
            _showDefinition(content);
          },
        ),
        ContextMenuButtonItem(
          label: 'Resaltar',
          onPressed: () {
            state.hideToolbar();
            _saveHighlight(content);
          },
        ),
      ]);
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Future<void> _search() async {
    final controller = _controller;
    if (controller == null) return;

    final query = await showDialog<String>(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        return AlertDialog(
          title: const Text('Buscar en el libro'),
          content: TextField(controller: searchController, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(searchController.text.trim()),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
    if (query == null || query.isEmpty) return;

    final toc = controller.tableOfContents();
    final lowerQuery = query.toLowerCase();
    final matchIndexes = <int>[];
    for (var i = 0; i < _chapterTexts.length && i < toc.length; i++) {
      if (_chapterTexts[i].toLowerCase().contains(lowerQuery)) {
        matchIndexes.add(i);
      }
    }

    if (!mounted) return;
    if (matchIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron coincidencias')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: matchIndexes.map((i) {
            final title = toc[i].title?.trim();
            return ListTile(
              leading: const Icon(Icons.search),
              title: Text(title?.isNotEmpty == true ? title! : 'Resultado ${i + 1}'),
              onTap: () => Navigator.of(context).pop(i),
            );
          }).toList(),
        ),
      ),
    );
    if (chosen != null) {
      controller.jumpTo(index: toc[chosen].startIndex);
    }
  }

  Future<void> _toggleTts() async {
    if (_isSpeaking) {
      setState(() => _isSpeaking = false);
      await _tts.stop();
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    final chapterNumber = controller.currentValueListenable.value?.chapterNumber;
    if (chapterNumber == null) return;
    await _speakChapter(chapterNumber - 1);
  }

  Future<void> _speakChapter(int index) async {
    if (index < 0 || index >= _chapterTexts.length) {
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    final text = _chapterTexts[index];
    if (text.trim().isEmpty) {
      await _speakChapter(index + 1);
      return;
    }
    setState(() {
      _isSpeaking = true;
      _speakingChapterIndex = index;
    });
    final toc = _controller?.tableOfContents();
    if (toc != null && index < toc.length) {
      _controller?.jumpTo(index: toc[index].startIndex);
    }
    await _tts.speak(text);
  }

  void _onTtsChapterDone() {
    if (!_isSpeaking || _speakingChapterIndex == null) return;
    _speakChapter(_speakingChapterIndex! + 1);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _tts.stop();
    unawaited(_saveProgress());
    final seconds = DateTime.now().difference(_sessionStart).inSeconds;
    unawaited(_statsService.logSession(widget.book.id, seconds));
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _settings.backgroundColor,
      appBar: AppBar(
        title: EpubViewActualChapter(
          controller: _controller!,
          builder: (chapterValue) => Text(
            chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ??
                widget.book.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
            onPressed: _search,
          ),
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up_outlined),
            tooltip: 'Leer en voz alta',
            onPressed: _toggleTts,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Guardar marcador',
            onPressed: _addBookmark,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'bookmarks':
                  _openBookmarks();
                case 'highlights':
                  _openHighlights();
                case 'settings':
                  _openSettings();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'bookmarks', child: Text('Marcadores')),
              PopupMenuItem(value: 'highlights', child: Text('Resaltados y notas')),
              PopupMenuItem(value: 'settings', child: Text('Apariencia')),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: EpubViewTableOfContents(controller: _controller!),
      ),
      body: Container(
        color: _settings.backgroundColor,
        child: SelectionArea(
          contextMenuBuilder: _selectionToolbarBuilder,
          onSelectionChanged: (content) =>
              _lastSelectedText = content?.plainText ?? '',
          child: EpubView(
            controller: _controller!,
            onChapterChanged: _onChapterChanged,
            builders: EpubViewBuilders<DefaultBuilderOptions>(
              options: DefaultBuilderOptions(
                textStyle: _settings.textStyle,
                paragraphPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            onDocumentError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No se pudo abrir el libro: $error')),
              );
            },
          ),
        ),
      ),
    );
  }
}
