import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/models/contact.dart';
import 'package:mi_red/services/import_export.dart';

void main() {
  test('CSV con encabezados en cualquier orden', () {
    final rows = parseDelimitedText(
      'Origen,Teléfono,Nombre,Referido,Etiquetas\n'
      'Evento,3151644445,Carlitos Gym,Nora,"Amigo, Gym"\n'
      ',,,,\n'
      'Instagram,,Morita Velásquez,,\n',
    );
    expect(rows, hasLength(2));
    expect(rows[0].name, 'Carlitos Gym');
    expect(rows[0].phone, '3151644445');
    expect(rows[0].referredBy, 'Nora');
    expect(rows[0].source, 'Evento');
    expect(rows[0].tags, ['Amigo', 'Gym']);
    expect(rows[1].name, 'Morita Velásquez');
  });

  test('pegado desde Excel sin encabezados (tabulado)', () {
    final rows = parseDelimitedText(
      'Andrés Pérez\t3124578790\tNora\tEvento\n'
      'Luis\t3001234567\n',
    );
    expect(rows, hasLength(2));
    expect(rows[0].referredBy, 'Nora');
    expect(rows[1].phone, '3001234567');
    expect(rows[1].source, '');
  });

  test('vCard con nombre compuesto y líneas dobladas', () {
    final rows = parseVcf(
      'BEGIN:VCARD\r\nVERSION:3.0\r\nN:Pérez;Andrés;;;\r\n'
      'TEL;TYPE=CELL:+57 312 457 8790\r\nEND:VCARD\r\n'
      'BEGIN:VCARD\r\nFN:Marcela uñas\r\n'
      'NOTE:Le gusta el\r\n  café\r\nEND:VCARD\r\n',
    );
    expect(rows, hasLength(2));
    expect(rows[0].name, 'Andrés Pérez');
    expect(rows[0].phone, '+57 312 457 8790');
    expect(rows[1].name, 'Marcela uñas');
    expect(rows[1].notes, 'Le gusta el café');
  });

  test('Excel: teléfonos numéricos sin ".0"', () {
    final excel = Excel.createExcel();
    final sheet = excel.tables.values.first;
    sheet.appendRow([TextCellValue('Nombre'), TextCellValue('Teléfono')]);
    sheet.appendRow([TextCellValue('Hugo'), DoubleCellValue(3151644445)]);
    final rows = parseExcel(excel.encode()!);
    expect(rows.single.name, 'Hugo');
    expect(rows.single.phone, '3151644445');
  });

  test('duplicados por los últimos 10 dígitos o por nombre', () {
    expect(dedupeKey('A', '+57 315 164 4445'), dedupeKey('B', '3151644445'));
    expect(dedupeKey('Hugo Peñafiel', ''), dedupeKey(' hugo peñafiel ', 'x'));
  });

  test('exportar y volver a importar conserva los datos', () {
    final contact = Contact.fromRow({
      'id': '1',
      'name': 'Neftali, invitado Nora',
      'phone': '+57 310 5228185',
      'referred_by': 'Nora',
      'source': 'Cartago',
      'tags': ['Amigo'],
      'interest': 'ambos',
      'stage': 'nuevo',
      'created_at': '2026-06-16T10:00:00Z',
    });
    final csv = exportContactsCsv([contact]);
    final back = parseDelimitedText(csv).single;
    expect(back.name, 'Neftali, invitado Nora');
    expect(back.phone, '+57 310 5228185');
    expect(back.referredBy, 'Nora');
    expect(back.source, 'Cartago');
    expect(back.tags, ['Amigo']);
  });

  test('la plantilla de ejemplo se puede importar', () {
    expect(parseDelimitedText(importTemplateCsv()), hasLength(2));
  });
}
