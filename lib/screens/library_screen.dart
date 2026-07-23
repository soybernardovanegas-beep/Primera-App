import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../services/library_service.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _libraryService = LibraryService(Supabase.instance.client);

  late Future<List<Book>> _libraryFuture;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _libraryFuture = _libraryService.fetchLibrary();
  }

  void _refresh() {
    setState(() => _libraryFuture = _libraryService.fetchLibrary());
  }

  Future<void> _importBook() async {
    setState(() => _isImporting = true);
    try {
      final book = await _libraryService.pickAndImportBook();
      if (book != null) _refresh();
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
    _refresh();
  }

  Future<void> _deleteBook(Book book) async {
    await _libraryService.deleteBook(book);
    _refresh();
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
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _libraryFuture;
        },
        child: FutureBuilder<List<Book>>(
          future: _libraryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final books = snapshot.data ?? [];
            if (books.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
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
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return ListTile(
                  leading: Icon(
                    Icons.menu_book,
                    color: book.availableLocally
                        ? null
                        : Theme.of(context).disabledColor,
                  ),
                  title: Text(book.title),
                  subtitle: Text(book.author?.isNotEmpty == true
                      ? book.author!
                      : (book.availableLocally
                          ? ''
                          : 'No disponible en este dispositivo')),
                  onTap: () => _openBook(book),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBook(book),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
