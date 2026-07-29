import 'package:supabase_flutter/supabase_flutter.dart';

class NotesService {
  NotesService(this._client);

  final SupabaseClient _client;

  Future<String> fetchNotes() async {
    final row =
        await _client.from('agenda_notes').select('content').maybeSingle();
    return row?['content'] as String? ?? '';
  }

  Future<void> saveNotes(String content) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('agenda_notes').upsert({
      'user_id': userId,
      'content': content,
    });
  }
}
