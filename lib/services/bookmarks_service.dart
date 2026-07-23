import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bookmark.dart';

class BookmarksService {
  BookmarksService(this._client);

  final SupabaseClient _client;

  Future<List<Bookmark>> fetchBookmarks(String bookId) async {
    final rows = await _client
        .from('bookmarks')
        .select()
        .eq('book_id', bookId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Bookmark.fromRow)
        .toList();
  }

  Future<void> addBookmark(String bookId, String cfi, String? label) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('bookmarks').insert({
      'user_id': userId,
      'book_id': bookId,
      'cfi': cfi,
      'label': label,
    });
  }

  Future<void> deleteBookmark(String id) async {
    await _client.from('bookmarks').delete().eq('id', id);
  }
}
