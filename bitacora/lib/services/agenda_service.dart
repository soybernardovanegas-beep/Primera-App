import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_item.dart';

String formatDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class AgendaService {
  AgendaService(this._client);

  final SupabaseClient _client;

  Future<List<AgendaItem>> fetchItemsForRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _client
        .from('agenda_items')
        .select()
        .gte('item_date', formatDateOnly(start))
        .lte('item_date', formatDateOnly(end))
        .order('item_date')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AgendaItem.fromRow)
        .toList();
  }

  Future<AgendaItem> addItem(DateTime date, String text) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('agenda_items')
        .insert({
          'user_id': userId,
          'item_date': formatDateOnly(date),
          'text': text,
        })
        .select()
        .single();
    return AgendaItem.fromRow(row);
  }

  Future<void> setDone(String id, bool done) async {
    await _client.from('agenda_items').update({'done': done}).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('agenda_items').delete().eq('id', id);
  }

  Future<List<AgendaItem>> search(String query) async {
    final rows = await _client
        .from('agenda_items')
        .select()
        .ilike('text', '%$query%')
        .order('item_date', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AgendaItem.fromRow)
        .toList();
  }
}
