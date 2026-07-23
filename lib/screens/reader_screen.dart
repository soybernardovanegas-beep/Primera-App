import 'dart:async';
import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../services/progress_service.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _progressService = ProgressService(Supabase.instance.client);

  EpubController? _controller;
  Timer? _saveDebounce;
  bool _isLoadingProgress = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final progress = await _progressService.fetchProgress(widget.book.id);
    if (!mounted) return;
    setState(() {
      _controller = EpubController(
        document: EpubDocument.openFile(File(widget.book.localPath)),
        epubCfi: progress?.location,
      );
      _isLoadingProgress = false;
    });
  }

  void _onChapterChanged(dynamic value) {
    if (value == null || _controller == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () => _saveProgress());
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

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_saveProgress());
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProgress || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: EpubViewActualChapter(
          controller: _controller!,
          builder: (chapterValue) => Text(
            chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ??
                widget.book.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      drawer: Drawer(
        child: EpubViewTableOfContents(controller: _controller!),
      ),
      body: EpubView(
        controller: _controller!,
        onChapterChanged: _onChapterChanged,
        onDocumentError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir el libro: $error')),
          );
        },
      ),
    );
  }
}
