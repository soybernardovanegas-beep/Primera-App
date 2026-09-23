import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import 'crm_service.dart';

/// Un contacto leído de un archivo, antes de guardarlo.
class ImportRow {
  ImportRow({
    required this.name,
    this.phone = '',
    this.referredBy = '',
    this.source = '',
    this.tags = const [],
    this.city = '',
    this.email = '',
    this.notes = '',
  });

  final String name;
  final String phone;
  final String referredBy;
  final String source;
  final List<String> tags;
  final String city;
  final String email;
  final String notes;

  ContactInput toInput() => ContactInput(
        name: name,
        phone: phone,
        referredBy: referredBy,
        source: source,
        tags: tags,
        city: city,
        email: email,
        notes: notes,
      );
}

/// Clave para detectar duplicados: los últimos 10 dígitos del teléfono o,
/// si no hay teléfono, el nombre en minúsculas.
String dedupeKey(String name, String phone) {
  final digits = digitsOnly(phone);
  if (digits.length >= 7) {
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }
  return name.trim().toLowerCase();
}

enum _Field { name, phone, referredBy, source, tags, city, email, notes }

String _normalize(String header) => header
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úù]'), 'u');

_Field? _fieldForHeader(String header) {
  final h = _normalize(header);
  if (h.startsWith('nombre') || h == 'name' || h == 'contacto') {
    return _Field.name;
  }
  if (h.contains('telefono') ||
      h.contains('celular') ||
      h.contains('movil') ||
      h.contains('phone') ||
      h == 'whatsapp' ||
      h == 'numero') {
    return _Field.phone;
  }
  if (h.startsWith('referido') || h == 'ref') return _Field.referredBy;
  if (h.startsWith('origen') || h == 'fuente' || h == 'source') {
    return _Field.source;
  }
  if (h.startsWith('etiqueta') || h == 'tags') return _Field.tags;
  if (h == 'ciudad' || h == 'city') return _Field.city;
  if (h == 'correo' || h.contains('email')) return _Field.email;
  if (h.startsWith('nota') || h == 'notes') return _Field.notes;
  return null;
}

/// Convierte una tabla (filas de celdas) en contactos. Si la primera fila
/// trae encabezados (Nombre, Teléfono...) se usan para ubicar las columnas;
/// si no, se asume el orden Nombre, Teléfono, Referido, Origen.
List<ImportRow> rowsFromTable(List<List<String>> table) {
  final rows = table
      .map((r) => r.map((c) => c.trim()).toList())
      .where((r) => r.any((c) => c.isNotEmpty))
      .toList();
  if (rows.isEmpty) return [];

  var columns = <int, _Field>{};
  var data = rows;
  final header = {
    for (var i = 0; i < rows.first.length; i++)
      if (_fieldForHeader(rows.first[i]) != null)
        i: _fieldForHeader(rows.first[i])!,
  };
  if (header.containsValue(_Field.name)) {
    columns = header;
    data = rows.skip(1).toList();
  } else {
    columns = {
      0: _Field.name,
      1: _Field.phone,
      2: _Field.referredBy,
      3: _Field.source,
    };
  }

  final result = <ImportRow>[];
  for (final row in data) {
    String get(_Field f) {
      final index =
          columns.entries.where((e) => e.value == f).map((e) => e.key).firstOrNull;
      return index != null && index < row.length ? row[index] : '';
    }

    final name = get(_Field.name);
    if (name.isEmpty) continue;
    result.add(ImportRow(
      name: name,
      phone: get(_Field.phone),
      referredBy: get(_Field.referredBy),
      source: get(_Field.source),
      tags: get(_Field.tags)
          .split(RegExp('[,;|]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      city: get(_Field.city),
      email: get(_Field.email),
      notes: get(_Field.notes),
    ));
  }
  return result;
}

/// Texto CSV o pegado desde Excel (separado por tabulaciones).
List<ImportRow> parseDelimitedText(String text) {
  final codec = text.contains('\t')
      ? Csv(fieldDelimiter: '\t', autoDetect: false)
      : Csv();
  final table = codec
      .decode(text.replaceFirst('﻿', ''))
      .map((r) => r.map((c) => '$c').toList())
      .toList();
  return rowsFromTable(table);
}

/// Archivo .xlsx: se lee la primera hoja.
List<ImportRow> parseExcel(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return [];
  final sheet = excel.tables.values.first;
  final table = [
    for (final row in sheet.rows)
      [
        for (final cell in row)
          switch (cell?.value) {
            null => '',
            // Los teléfonos llegan como números: 3151644445.0 → 3151644445.
            DoubleCellValue(:final value) when value == value.truncate() =>
              value.toInt().toString(),
            final value => value.toString(),
          },
      ],
  ];
  return rowsFromTable(table);
}

/// Contactos exportados del teléfono o del iPhone (.vcf / vCard).
List<ImportRow> parseVcf(String text) {
  final result = <ImportRow>[];
  // Las líneas largas se "doblan" empezando la siguiente con espacio.
  final unfolded = text.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  String? name;
  String? structuredName;
  String phone = '';
  String email = '';
  String notes = '';
  for (final raw in unfolded.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    final upper = line.toUpperCase();
    if (upper == 'BEGIN:VCARD') {
      name = null;
      structuredName = null;
      phone = '';
      email = '';
      notes = '';
    } else if (upper == 'END:VCARD') {
      final finalName = (name?.isNotEmpty ?? false) ? name! : structuredName;
      if (finalName != null && finalName.isNotEmpty) {
        result.add(ImportRow(
          name: finalName,
          phone: phone,
          email: email,
          notes: notes,
          source: 'Contactos del teléfono',
        ));
      }
    } else {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = upper.substring(0, colon).split(';').first;
      final value = line.substring(colon + 1).replaceAll(r'\,', ',').trim();
      switch (key) {
        case 'FN':
          name = value;
        case 'N':
          final parts = value.split(';');
          structuredName = [
            if (parts.length > 1) parts[1],
            parts[0],
          ].where((p) => p.isNotEmpty).join(' ');
        case 'TEL' when phone.isEmpty:
          phone = value;
        case 'EMAIL' when email.isEmpty:
          email = value;
        case 'NOTE':
          notes = value.replaceAll(r'\n', '\n');
      }
    }
  }
  return result;
}

const _exportHeaders = [
  'Nombre',
  'Teléfono',
  'Referido',
  'Origen',
  'Etiquetas',
  'Etapa',
  'Enfoque',
  'Temperatura',
  'Puntaje',
  'Categoría',
  'Ciudad',
  'Correo',
  'Notas',
  'Porqué ingresos',
  'Porqué salud',
  'Creado',
];

/// CSV con todos los contactos (se puede abrir en Excel o Google Sheets y
/// volver a importar en la app).
String exportContactsCsv(List<Contact> contacts) {
  final date = DateFormat('yyyy-MM-dd');
  return Csv(lineDelimiter: '\n', addBom: true).encode([
    _exportHeaders,
    for (final c in contacts)
      [
        c.name,
        c.phone,
        c.referredBy,
        c.source,
        c.tags.join(', '),
        c.stage.label,
        c.interest.label,
        c.temperature.label,
        c.score?.toString() ?? '',
        c.category?.label ?? '',
        c.city,
        c.email,
        c.notes,
        c.whyIncome,
        c.whyHealth,
        date.format(c.createdAt),
      ],
  ]);
}

String importTemplateCsv() => Csv(lineDelimiter: '\n', addBom: true).encode([
      ['Nombre', 'Teléfono', 'Referido', 'Origen', 'Etiquetas'],
      ['Andrés Pérez', '3124578790', 'Nora', 'Evento', 'Amigo, Gym'],
      ['María Gómez', '+57 310 522 8185', '', 'Instagram', 'Red social'],
    ]);
