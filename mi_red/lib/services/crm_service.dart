import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/interaction.dart';
import '../models/sale.dart';

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
    this.interest = Interest.cliente,
    this.stage = Stage.nuevo,
    this.sponsorId,
    this.notes = '',
    this.nextFollowUp,
  });

  final String name;
  final String phone;
  final String email;
  final String city;
  final String source;
  final Interest interest;
  final Stage stage;
  final String? sponsorId;
  final String notes;
  final DateTime? nextFollowUp;

  Map<String, dynamic> toRow() => {
        'name': name,
        'phone': phone,
        'email': email,
        'city': city,
        'source': source,
        'interest': interest.name,
        'stage': stage.name,
        'sponsor_id': sponsorId,
        'notes': notes,
        'next_follow_up':
            nextFollowUp == null ? null : formatDateOnly(nextFollowUp!),
      };
}

class CrmService {
  CrmService(this._client);

  final SupabaseClient _client;

  // ---------- Contactos ----------

  Future<List<Contact>> fetchContacts() async {
    final rows =
        await _client.from('crm_contacts').select().order('name');
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
        .insert({
          'user_id': _client.auth.currentUser!.id,
          ...input.toRow(),
        })
        .select()
        .single();
    return Contact.fromRow(row);
  }

  Future<void> updateContact(String id, ContactInput input) async {
    await _client.from('crm_contacts').update(input.toRow()).eq('id', id);
  }

  Future<void> setStage(String id, Stage stage) async {
    await _client
        .from('crm_contacts')
        .update({'stage': stage.name}).eq('id', id);
  }

  Future<void> setNextFollowUp(String id, DateTime? date) async {
    await _client.from('crm_contacts').update({
      'next_follow_up': date == null ? null : formatDateOnly(date),
    }).eq('id', id);
  }

  Future<void> deleteContact(String id) async {
    await _client.from('crm_contacts').delete().eq('id', id);
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

  Future<void> addInteraction(
    String contactId,
    InteractionKind kind,
    String note,
  ) async {
    await _client.from('crm_interactions').insert({
      'user_id': _client.auth.currentUser!.id,
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
      'user_id': _client.auth.currentUser!.id,
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
}
