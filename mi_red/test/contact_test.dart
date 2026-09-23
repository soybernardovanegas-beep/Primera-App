import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/models/contact.dart';
import 'package:mi_red/services/crm_service.dart';

Contact _contact({String name = 'Ana María López', String? followUp}) =>
    Contact.fromRow({
      'id': '1',
      'name': name,
      'phone': '+52 (55) 1234-5678',
      'email': '',
      'city': 'CDMX',
      'source': 'Referido',
      'interest': 'socio',
      'stage': 'presentacion',
      'sponsor_id': null,
      'notes': '',
      'next_follow_up': followUp,
      'created_at': '2026-09-01T10:00:00Z',
    });

void main() {
  test('parsea una fila de Supabase', () {
    final c = _contact();
    expect(c.stage, Stage.presentacion);
    expect(c.interest, Interest.socio);
    expect(c.initials, 'AM');
    expect(digitsOnly(c.phone), '525512345678');
  });

  test('valores desconocidos caen en el default', () {
    expect(Stage.fromName('otra'), Stage.nuevo);
    expect(Interest.fromName(''), Interest.cliente);
  });

  test('seguimiento vencido o de hoy cuenta como pendiente', () {
    final today = DateTime(2026, 9, 23, 18);
    expect(_contact(followUp: '2026-09-23').isFollowUpDue(today), isTrue);
    expect(_contact(followUp: '2026-09-20').isFollowUpDue(today), isTrue);
    expect(_contact(followUp: '2026-09-24').isFollowUpDue(today), isFalse);
    expect(_contact().isFollowUpDue(today), isFalse);
  });

  test('ContactInput serializa la fecha sin hora', () {
    final row = ContactInput(
      name: 'Luis',
      nextFollowUp: DateTime(2026, 1, 5),
    ).toRow();
    expect(row['next_follow_up'], '2026-01-05');
    expect(row['stage'], 'nuevo');
  });
}
