import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/content/guides.dart';
import 'package:mi_red/content/message_templates.dart';
import 'package:mi_red/models/contact.dart';
import 'package:mi_red/models/qualification.dart';
import 'package:mi_red/models/reminder.dart';
import 'package:mi_red/screens/call_mode_screen.dart';
import 'package:mi_red/screens/power_hour_screen.dart';
import 'package:mi_red/services/calendar_links.dart';
import 'package:mi_red/services/crm_service.dart';

Map<String, dynamic> _row({
  String id = '1',
  String name = 'Ana María López',
  String phone = '3151644445',
  String stage = 'presentacion',
  String interest = 'socio',
  List<int>? scores,
  String? snoozed,
  String whyIncome = '',
  String temperature = 'frio',
}) =>
    {
      'id': id,
      'name': name,
      'phone': phone,
      'email': '',
      'city': 'Pereira',
      'source': 'Evento',
      'referred_by': 'Nora',
      'tags': ['Amigo', 'Gym'],
      'interest': interest,
      'stage': stage,
      'temperature': temperature,
      'favorite': false,
      'sponsor_id': null,
      'notes': '',
      'score_age': scores?[0],
      'score_credibility': scores?[1],
      'score_solvency': scores?[2],
      'score_social': scores?[3],
      'why_income': whyIncome,
      'why_health': '',
      'snoozed_until': snoozed,
      'created_at': '2026-09-01T10:00:00Z',
    };

void main() {
  group('Contacto', () {
    test('parsea una fila de Supabase', () {
      final c = Contact.fromRow(_row());
      expect(c.stage, Stage.presentacion);
      expect(c.interest, Interest.socio);
      expect(c.initials, 'AM');
      expect(c.tags, ['Amigo', 'Gym']);
      expect(c.qualification, isNull);
      expect(c.category, isNull);
    });

    test('valores desconocidos caen en el default', () {
      expect(Stage.fromName('otra'), Stage.nuevo);
      expect(Interest.fromName(''), Interest.cliente);
      expect(Temperature.fromName(null), Temperature.frio);
    });

    test('pausado: fuera del proceso hasta la fecha', () {
      final today = DateTime(2026, 9, 23, 18);
      final paused = Contact.fromRow(_row(snoozed: '2026-12-23'));
      expect(paused.isSnoozed(today), isTrue);
      expect(paused.isActive(today), isFalse);
      final back = Contact.fromRow(_row(snoozed: '2026-09-23'));
      expect(back.isActive(today), isTrue);
      expect(Contact.fromRow(_row(stage: 'descartado')).isActive(today), isFalse);
    });

    test('teléfono y WhatsApp', () {
      expect(looksLikePhone('está en Instagram'), isFalse);
      expect(looksLikePhone('315 164 4445'), isTrue);
      expect(whatsappNumber('3151644445'), '573151644445');
      expect(whatsappNumber('+57 310 5228185'), '573105228185');
      expect(whatsappNumber('+1 (305) 555-1234'), '13055551234');
    });

    test('Avanzar sigue el embudo según el enfoque', () {
      expect(nextStage(Stage.nuevo, Interest.ambos), Stage.contactado);
      expect(nextStage(Stage.seguimiento, Interest.cliente), Stage.cliente);
      expect(nextStage(Stage.seguimiento, Interest.socio), Stage.socio);
      expect(nextStage(Stage.cliente, Interest.cliente), Stage.socio);
      expect(nextStage(Stage.socio, Interest.socio), isNull);
    });

    test('ContactInput serializa los campos nuevos', () {
      final row = const ContactInput(
        name: 'Luis',
        referredBy: 'Nora',
        tags: ['Gym'],
        temperature: Temperature.caliente,
      ).toRow();
      expect(row['referred_by'], 'Nora');
      expect(row['tags'], ['Gym']);
      expect(row['temperature'], 'caliente');
      expect(row['stage'], 'nuevo');
    });
  });

  group('Calificación', () {
    test('suma y categoría como en las capturas', () {
      // Edad 26-45 (3), Parcial (3), Emprendedor sin solvencia (4), Social 2.
      final c = Contact.fromRow(_row(scores: [3, 3, 4, 2]));
      expect(c.score, 12);
      expect(c.category, Category.potencial);
    });

    test('umbrales: ideal 15-20, potencial 10-14, incierto <=9', () {
      expect(Category.fromScore(20), Category.ideal);
      expect(Category.fromScore(15), Category.ideal);
      expect(Category.fromScore(14), Category.potencial);
      expect(Category.fromScore(10), Category.potencial);
      expect(Category.fromScore(9), Category.incierto);
      expect(Category.fromScore(4), Category.incierto);
    });

    test('el máximo posible es 20', () {
      final max = qualificationQuestions.fold(0, (s, q) => s + q.maxPoints);
      expect(max, 20);
    });

    test('toRow usa las columnas de la tabla', () {
      expect(const Qualification([2, 5, 6, 6]).toRow(), {
        'score_age': 2,
        'score_credibility': 5,
        'score_solvency': 6,
        'score_social': 6,
      });
    });
  });

  group('Recordatorios', () {
    Reminder r(String id, String contact, DateTime due) => Reminder(
          id: id,
          contactId: contact,
          contactName: contact,
          dueAt: due,
          note: '',
          done: false,
        );

    test('el vigente es el más próximo de cada contacto', () {
      final current = currentReminderByContact([
        r('a', 'x', DateTime(2026, 10, 5)),
        r('b', 'x', DateTime(2026, 9, 20)),
        r('c', 'y', DateTime(2026, 9, 30)),
      ]);
      expect(current['x']!.id, 'b');
      expect(current['y']!.id, 'c');
    });
  });

  group('Llamadas', () {
    test('el resultado solo hace avanzar la etapa', () {
      expect(stageAfterCall(Stage.nuevo, CallOutcome.agendo), Stage.presentacion);
      expect(stageAfterCall(Stage.seguimiento, CallOutcome.agendo), isNull);
      expect(stageAfterCall(Stage.nuevo, CallOutcome.noContesto), isNull);
      expect(stageAfterCall(Stage.contactado, CallOutcome.noInteresado),
          Stage.descartado);
      expect(stageAfterCall(Stage.cliente, CallOutcome.noInteresado), isNull);
    });

    test('Hora de Poder: vencidos primero, luego mayor puntaje', () {
      final now = DateTime(2026, 9, 23, 12);
      final contacts = [
        Contact.fromRow(_row(id: 'bajo', scores: [1, 1, 1, 1])),
        Contact.fromRow(_row(id: 'alto', scores: [3, 5, 6, 6])),
        Contact.fromRow(_row(id: 'vencido', scores: [1, 1, 1, 2])),
        Contact.fromRow(_row(id: 'sinTel', phone: 'está en Instagram')),
        Contact.fromRow(_row(id: 'socio', stage: 'socio')),
      ];
      final reminders = {
        'vencido': Reminder(
          id: 'r',
          contactId: 'vencido',
          contactName: '',
          dueAt: DateTime(2026, 9, 20),
          note: '',
          done: false,
        ),
      };
      final queue = powerHourQueue(contacts, reminders, now);
      expect(queue.map((c) => c.id), ['vencido', 'alto', 'bajo']);
    });
  });

  group('Mensajes y guías', () {
    test('las plantillas usan el primer nombre y su porqué', () {
      final c = Contact.fromRow(_row(
        stage: 'contactado',
        whyIncome: 'Tiene deudas del carro.',
      ));
      final templates = templatesFor(c);
      final why = templates.firstWhere((t) => t.title == 'Con su porqué: ingresos');
      expect(fillTemplate(why, c), contains('Hola Ana'));
      expect(fillTemplate(why, c), contains('tiene deudas del carro'));
      // Sin porqué de salud, esa plantilla no se ofrece.
      expect(templates.any((t) => t.title == 'Con su porqué: salud'), isFalse);
    });

    test('todas las etapas tienen al menos una plantilla', () {
      for (final stage in Stage.values) {
        final c = Contact.fromRow(_row(stage: stage.name, interest: 'ambos'));
        expect(templatesFor(c), isNotEmpty, reason: stage.label);
      }
    });

    test('secciones y marcadores de las guías', () {
      final sections = parseSections(guideObjeciones.defaultContent);
      expect(sections.first.title, isEmpty);
      expect(sections.map((s) => s.title), contains('"No tengo tiempo"'));
      expect(
        fillPlaceholders('Hola {nombre}. {mi_porque}',
            name: 'Carlos Pérez', myWhy: 'Mis hijos'),
        'Hola Carlos. Mis hijos',
      );
    });
  });

  group('Calendario', () {
    final start = DateTime.utc(2026, 9, 19, 11, 2);

    test('enlace de Google Calendar', () {
      final url = googleCalendarUrl(title: 'Llamar', details: 'Nota', start: start);
      expect(url.host, 'calendar.google.com');
      expect(url.queryParameters['dates'], '20260919T110200Z/20260919T113200Z');
    });

    test('archivo .ics', () {
      final ics = buildIcs(
        uid: 'abc',
        title: 'Llamar a Juan, hoy',
        details: 'Línea 1\nLínea 2',
        start: start,
        now: start,
      );
      expect(ics, contains('DTSTART:20260919T110200Z'));
      expect(ics, contains(r'SUMMARY:Llamar a Juan\, hoy'));
      expect(ics, contains(r'DESCRIPTION:Línea 1\nLínea 2'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
    });
  });

  test('formatDateOnly', () {
    expect(formatDateOnly(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
