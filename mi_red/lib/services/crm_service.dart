import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/interaction.dart';
import '../models/profile.dart';
import '../models/qualification.dart';
import '../models/reminder.dart';
import '../models/sale.dart';
import 'notification_service.dart';

String formatDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Datos editables de un contacto, usados para crear o actualizar.
class ContactInput {
  const ContactInput({
    required this.name,
    this.phone = '',
    this.email = '',
    this.city = '',
    this.source = '',
    this.referredBy = '',
    this.tags = const [],
    this.interest = Interest.cliente,
    this.stage = Stage.nuevo,
    this.temperature = Temperature.frio,
    this.sponsorId,
    this.notes = '',
  });

  final String name;
  final String phone;
  final String email;
  final String city;
  final String source;
  final String referredBy;
  final List<String> tags;
  final Interest interest;
  final Stage stage;
  final Temperature temperature;
  final String? sponsorId;
  final String notes;

  Map<String, dynamic> toRow() => {
        'name': name,
        'phone': phone,
        'email': email,
        'city': city,
        'source': source,
        'referred_by': referredBy,
        'tags': tags,
        'interest': interest.name,
        'stage': stage.name,
        'temperature': temperature.name,
        'sponsor_id': sponsorId,
        'notes': notes,
      };
}

class CrmService {
  CrmService(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  // ---------- Contactos ----------

  Future<List<Contact>> fetchContacts() async {
    final rows = await _client.from('crm_contacts').select().order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Contact.fromRow)
        .toList();
  }

  Future<Contact> fetchContact(String id) async {
    final row =
        await _client.from('crm_contacts').select().eq('id', id).single();
    return Contact.fromRow(row);
  }

  Future<Contact> addContact(ContactInput input) async {
    final row = await _client
        .from('crm_contacts')
        .insert({'user_id': _userId, ...input.toRow()})
        .select()
        .single();
    return Contact.fromRow(row);
  }

  /// Inserta muchos contactos de una vez (importación).
  Future<void> addContacts(List<ContactInput> inputs) async {
    if (inputs.isEmpty) return;
    const chunk = 200;
    for (var i = 0; i < inputs.length; i += chunk) {
      await _client.from('crm_contacts').insert([
        for (final input in inputs.skip(i).take(chunk))
          {'user_id': _userId, ...input.toRow()},
      ]);
    }
  }

  Future<void> updateContact(String id, ContactInput input) async {
    await _client.from('crm_contacts').update(input.toRow()).eq('id', id);
  }

  /// Actualiza solo algunos campos (etapa, favorito, notas, porqué...).
  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    await _client.from('crm_contacts').update(fields).eq('id', id);
  }

  Future<void> updateFieldsMany(
    List<String> ids,
    Map<String, dynamic> fields,
  ) async {
    if (ids.isEmpty) return;
    await _client.from('crm_contacts').update(fields).inFilter('id', ids);
  }

  Future<void> setStage(String id, Stage stage) =>
      updateFields(id, {'stage': stage.name});

  Future<void> setQualification(String id, Qualification q) =>
      updateFields(id, q.toRow());

  Future<void> snooze(String id, DateTime? until) => updateFields(id, {
        'snoozed_until': until == null ? null : formatDateOnly(until),
      });

  Future<void> deleteContacts(List<String> ids) async {
    if (ids.isEmpty) return;
    // Los recordatorios se borran en cascada; hay que cancelar sus avisos.
    final reminders = await _client
        .from('crm_reminders')
        .select('id')
        .inFilter('contact_id', ids);
    for (final r in (reminders as List).cast<Map<String, dynamic>>()) {
      await NotificationService.instance.cancel(r['id'] as String);
    }
    await _client.from('crm_contacts').delete().inFilter('id', ids);
  }

  Future<void> deleteContact(String id) => deleteContacts([id]);

  // ---------- Recordatorios ----------

  static const _reminderSelect = '*, crm_contacts(name)';

  Future<List<Reminder>> fetchPendingReminders({String? contactId}) async {
    var query = _client
        .from('crm_reminders')
        .select(_reminderSelect)
        .eq('done', false);
    if (contactId != null) query = query.eq('contact_id', contactId);
    final rows = await query.order('due_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Reminder.fromRow)
        .toList();
  }

  Future<Reminder> addReminder(
    String contactId,
    DateTime dueAt,
    String note,
  ) async {
    final row = await _client
        .from('crm_reminders')
        .insert({
          'user_id': _userId,
          'contact_id': contactId,
          'due_at': dueAt.toUtc().toIso8601String(),
          'note': note,
        })
        .select(_reminderSelect)
        .single();
    final reminder = Reminder.fromRow(row);
    await NotificationService.instance.schedule(reminder);
    return reminder;
  }

  Future<void> completeReminder(String id) async {
    await _client.from('crm_reminders').update({'done': true}).eq('id', id);
    await NotificationService.instance.cancel(id);
  }

  Future<void> deleteReminder(String id) async {
    await _client.from('crm_reminders').delete().eq('id', id);
    await NotificationService.instance.cancel(id);
  }

  // ---------- Interacciones ----------

  Future<List<Interaction>> fetchInteractions(String contactId) async {
    final rows = await _client
        .from('crm_interactions')
        .select()
        .eq('contact_id', contactId)
        .order('occurred_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Interaction.fromRow)
        .toList();
  }

  /// Cuántas interacciones de un tipo hubo desde [since] (p. ej. llamadas
  /// de hoy).
  Future<int> countInteractionsSince(
    DateTime since, {
    InteractionKind? kind,
  }) async {
    var query = _client
        .from('crm_interactions')
        .select('id')
        .gte('occurred_at', since.toUtc().toIso8601String());
    if (kind != null) query = query.eq('kind', kind.name);
    final rows = await query;
    return (rows as List).length;
  }

  Future<void> addInteraction(
    String contactId,
    InteractionKind kind,
    String note,
  ) async {
    await _client.from('crm_interactions').insert({
      'user_id': _userId,
      'contact_id': contactId,
      'kind': kind.name,
      'note': note,
    });
  }

  Future<void> deleteInteraction(String id) async {
    await _client.from('crm_interactions').delete().eq('id', id);
  }

  // ---------- Ventas ----------

  Future<List<Sale>> fetchSales({
    DateTime? start,
    DateTime? end,
    String? contactId,
  }) async {
    var query = _client.from('crm_sales').select('*, crm_contacts(name)');
    if (start != null) query = query.gte('sale_date', formatDateOnly(start));
    if (end != null) query = query.lte('sale_date', formatDateOnly(end));
    if (contactId != null) query = query.eq('contact_id', contactId);
    final rows = await query
        .order('sale_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Sale.fromRow)
        .toList();
  }

  Future<void> addSale({
    required String product,
    required double amount,
    required double points,
    required DateTime saleDate,
    String? contactId,
  }) async {
    await _client.from('crm_sales').insert({
      'user_id': _userId,
      'contact_id': contactId,
      'product': product,
      'amount': amount,
      'points': points,
      'sale_date': formatDateOnly(saleDate),
    });
  }

  Future<void> deleteSale(String id) async {
    await _client.from('crm_sales').delete().eq('id', id);
  }

  // ---------- Perfil ----------

  Future<Profile> fetchProfile() async {
    final row = await _client
        .from('crm_profile')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    return Profile.fromRow(row);
  }

  Future<void> saveProfile(Profile profile) async {
    await _client
        .from('crm_profile')
        .upsert({'user_id': _userId, ...profile.toRow()});
  }

  // ---------- Guías ----------

  Future<Map<String, String>> fetchGuideOverrides() async {
    final rows = await _client.from('crm_guides').select('key, content');
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['key'] as String: r['content'] as String,
    };
  }

  Future<void> saveGuide(String key, String content) async {
    await _client
        .from('crm_guides')
        .upsert({'user_id': _userId, 'key': key, 'content': content});
  }

  Future<void> resetGuide(String key) async {
    await _client.from('crm_guides').delete().eq('key', key);
  }
}
