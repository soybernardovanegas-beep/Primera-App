import 'package:supabase_flutter/supabase_flutter.dart';

class BookStats {
  const BookStats({required this.totalSeconds, required this.streakDays});

  final int totalSeconds;
  final int streakDays;
}

class StatsService {
  StatsService(this._client);

  final SupabaseClient _client;

  Future<void> logSession(String bookId, int seconds) async {
    if (seconds < 5) return;
    final userId = _client.auth.currentUser!.id;
    await _client.from('reading_sessions').insert({
      'user_id': userId,
      'book_id': bookId,
      'seconds': seconds,
    });
  }

  Future<BookStats> fetchStats(String bookId) async {
    final rows = await _client
        .from('reading_sessions')
        .select('seconds, read_on')
        .eq('book_id', bookId);

    final sessions = (rows as List).cast<Map<String, dynamic>>();
    final totalSeconds =
        sessions.fold<int>(0, (sum, row) => sum + (row['seconds'] as int));

    final days = sessions.map((row) => row['read_on'] as String).toSet();
    final streak = _computeStreak(days);

    return BookStats(totalSeconds: totalSeconds, streakDays: streak);
  }

  int _computeStreak(Set<String> readOnDates) {
    if (readOnDates.isEmpty) return 0;
    final dates = readOnDates.map(DateTime.parse).toSet();
    final now = DateTime.now();
    var cursorDay = DateTime(now.year, now.month, now.day);
    var streak = 0;
    while (dates.contains(cursorDay)) {
      streak++;
      cursorDay = cursorDay.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
