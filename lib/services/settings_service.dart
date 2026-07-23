import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reading_settings.dart';

class SettingsService {
  SettingsService(this._client);

  final SupabaseClient _client;

  Future<ReadingSettings> fetchSettings() async {
    final row = await _client
        .from('reading_settings')
        .select()
        .maybeSingle();
    if (row == null) return const ReadingSettings();
    return ReadingSettings.fromRow(row);
  }

  Future<void> saveSettings(ReadingSettings settings) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('reading_settings').upsert({
      'user_id': userId,
      ...settings.toRow(),
    });
  }
}
