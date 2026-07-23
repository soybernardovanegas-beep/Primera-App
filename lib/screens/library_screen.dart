import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/collection.dart';
import '../services/collections_service.dart';
import '../services/library_service.dart';
import 'bookmarks_screen.dart';
import 'highlights_screen.dart';
import 'reader_screen.dart';
import 'stats_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _libraryService = LibraryService(Supabase.instance.client);
  final _collectionsService = CollectionsService(Supabase.instance.client);

  List<Book> _books = [];
  List<BookCollection> _collections = [];
  Map<String, Set<String>> _bookCollections = {};
  String? _selectedCollectionId;
  bool _isLoading = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _libraryService.fetchLibrary(),
      _collectionsService.fetchCollections(),
      _collectionsService.fetchBookCollections(),
    ]);
    if (!mounted) return;
    setState(() {
      _books = results[0] as List<Book>;
      _collections = results[1] as List<BookCollection>;
      _bookCollections = results[2] as Map<String, Set<String>>;
      _isLoading = false;
    });
  }

  List<Book> get _visibleBooks {
    if (_selectedCollectionId == null) return _books;
    return _books
        .where((b) =>
            _bookCollections[b.id]?.contains(_selectedCollectionId) ?? false)
        .toList();
  }

  Future<void> _importBook() async {
    setState(() => _isImporting = true);
    try {
      final book = await _libraryService.pickAndImportBook();
      if (book != null) await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo importar el libro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openBook(Book book) async {
    if (!book.availableLocally) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este libro no está en este dispositivo. Impórtalo aquí también '
            'para poder leerlo (el progreso ya se sincronizará).',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
    _loadAll();
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva colección'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej. Ciencia ficción'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _collectionsService.createCollection(name);
    _loadAll();
  }

  Future<void> _editBookCollections(Book book) async {
    final selected = Set<String>.from(_bookCollections[book.id] ?? {});
    final saved = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Colecciones', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_collections.isEmpty)
                      const Text('Aún no tienes colecciones.'),
                    Wrap(
                      spacing: 8,
                      children: _collections.map((c) {
                        return FilterChip(
                          label: Text(c.name),
                          selected: selected.contains(c.id),
                          onSelected: (value) => setSheetState(() {
                            if (value) {
                              selected.add(c.id);
                            } else {
                              selected.remove(c.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved == true) {
      await _collectionsService.setBookCollections(book.id, selected);
      _loadAll();
    }
  }

  Future<void> _showBookOptions(Book book) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Marcadores'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BookmarksScreen(bookId: book.id),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.border_color_outlined),
              title: const Text('Resaltados y notas'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HighlightsScreen(bookId: book.id),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Estadísticas'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StatsScreen(bookId: book.id, title: book.title),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Asignar a colecciones'),
              onTap: () {
                Navigator.of(context).pop();
                _editBookCollections(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar de la biblioteca'),
              onTap: () async {
                Navigator.of(context).pop();
                await _libraryService.deleteBook(book);
                _loadAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isImporting ? null : _importBook,
        child: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: const Text('Todos'),
                            selected: _selectedCollectionId == null,
                            onSelected: (_) =>
                                setState(() => _selectedCollectionId = null),
                          ),
                        ),
                        for (final collection in _collections)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(collection.name),
                              selected: _selectedCollectionId == collection.id,
                              onSelected: (_) => setState(
                                () => _selectedCollectionId = collection.id,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('Nueva'),
                            onPressed: _createCollection,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _buildGrid()),
                ],
              ),
            ),
    );
  }

  Widget _buildGrid() {
    final books = _visibleBooks;
    if (books.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Text(
                'Aún no tienes libros.\nToca + para importar un EPUB.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return InkWell(
          onTap: () => _openBook(book),
          onLongPress: () => _showBookOptions(book),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: book.hasCover
                      ? Image.file(File(book.coverPath), fit: BoxFit.cover)
                      : Center(
                          child: Icon(
                            Icons.menu_book,
                            size: 36,
                            color: book.availableLocally
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!book.availableLocally)
                Text(
                  'No disponible aquí',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Theme.of(context).disabledColor),
                ),
            ],
          ),
        );
      },
    );
  }
}
