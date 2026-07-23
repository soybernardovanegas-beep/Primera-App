import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/highlight.dart';

class HighlightsService {
  HighlightsService(this._client);

  final SupabaseClient _client;

  Future<List<Highlight>> fetchHighlights(String bookId) async {
    final rows = await _client
        .from('highlights')
        .select()
        .eq('book_id', bookId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Highlight.fromRow)
        .toList();
  }

  Future<void> addHighlight({
    required String bookId,
    required String cfi,
    required String snippet,
    required String color,
    String? note,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('highlights').insert({
      'user_id': userId,
      'book_id': bookId,
      'cfi': cfi,
      'snippet': snippet,
      'color': color,
      'note': note,
    });
  }

  Future<void> deleteHighlight(String id) async {
    await _client.from('highlights').delete().eq('id', id);
  }
}
