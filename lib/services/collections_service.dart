import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/collection.dart';

class CollectionsService {
  CollectionsService(this._client);

  final SupabaseClient _client;

  Future<List<BookCollection>> fetchCollections() async {
    final rows = await _client.from('collections').select().order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BookCollection.fromRow)
        .toList();
  }

  Future<BookCollection> createCollection(String name) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('collections')
        .insert({'user_id': userId, 'name': name})
        .select()
        .single();
    return BookCollection.fromRow(row);
  }

  Future<void> deleteCollection(String id) async {
    await _client.from('collections').delete().eq('id', id);
  }

  /// Returns a map of bookId -> set of collectionIds for the given books.
  Future<Map<String, Set<String>>> fetchBookCollections() async {
    final rows = await _client
        .from('book_collections')
        .select('book_id, collection_id');
    final result = <String, Set<String>>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final bookId = row['book_id'] as String;
      result.putIfAbsent(bookId, () => {}).add(row['collection_id'] as String);
    }
    return result;
  }

  Future<void> setBookCollections(String bookId, Set<String> collectionIds) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('book_collections').delete().eq('book_id', bookId);
    if (collectionIds.isEmpty) return;
    await _client.from('book_collections').insert([
      for (final collectionId in collectionIds)
        {
          'user_id': userId,
          'book_id': bookId,
          'collection_id': collectionId,
        },
    ]);
  }
}
