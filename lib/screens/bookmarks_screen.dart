import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bookmark.dart';
import '../services/bookmarks_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _service = BookmarksService(Supabase.instance.client);
  late Future<List<Bookmark>> _future = _service.fetchBookmarks(widget.bookId);

  void _refresh() {
    setState(() => _future = _service.fetchBookmarks(widget.bookId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marcadores')),
      body: FutureBuilder<List<Bookmark>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookmarks = snapshot.data!;
          if (bookmarks.isEmpty) {
            return const Center(child: Text('Aún no tienes marcadores.'));
          }
          return ListView.builder(
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(bookmark.label?.isNotEmpty == true
                    ? bookmark.label!
                    : 'Marcador ${index + 1}'),
                subtitle: Text(_formatDate(bookmark.createdAt)),
                onTap: () => Navigator.of(context).pop(bookmark),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _service.deleteBookmark(bookmark.id);
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
