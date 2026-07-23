import 'package:supabase_flutter/supabase_flutter.dart';

class ReadingProgress {
  const ReadingProgress({required this.location, required this.percentage});

  final String? location;
  final double percentage;
}

class ProgressService {
  ProgressService(this._client);

  final SupabaseClient _client;

  Future<ReadingProgress?> fetchProgress(String bookId) async {
    final row = await _client
        .from('reading_progress')
        .select()
        .eq('book_id', bookId)
        .maybeSingle();
    if (row == null) return null;
    return ReadingProgress(
      location: row['location'] as String?,
      percentage: (row['percentage'] as num).toDouble(),
    );
  }

  Future<void> saveProgress(
    String bookId, {
    required String? location,
    required double percentage,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('reading_progress').upsert(
      {
        'user_id': userId,
        'book_id': bookId,
        'location': location,
        'percentage': percentage,
      },
      onConflict: 'user_id,book_id',
    );
  }
}
