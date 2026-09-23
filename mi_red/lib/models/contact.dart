import 'package:flutter/material.dart';

import 'qualification.dart';

/// Etapas del embudo de un contacto, en el orden en que suelen avanzar.
enum Stage {
  nuevo('Nuevo', Icons.fiber_new_outlined, Color(0xFF90A4AE)),
  contactado('Contactado', Icons.chat_bubble_outline, Color(0xFF42A5F5)),
  presentacion('Presentación', Icons.slideshow_outlined, Color(0xFFAB47BC)),
  seguimiento('Seguimiento', Icons.schedule_outlined, Color(0xFFFFA726)),
  cliente('Cliente', Icons.shopping_bag_outlined, Color(0xFF66BB6A)),
  socio('Socio', Icons.handshake_outlined, Color(0xFF26A69A)),
  descartado('No interesado', Icons.block_outlined, Color(0xFFEF5350));

  const Stage(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static Stage fromName(String name) =>
      Stage.values.firstWhere((s) => s.name == name, orElse: () => nuevo);
}

/// Enfoque de la conversación: el producto, el negocio o ambos.
enum Interest {
  cliente('Producto', '🛍️'),
  socio('Negocio', '💼'),
  ambos('Ambos', '✨');

  const Interest(this.label, this.emoji);

  final String label;
  final String emoji;

  static Interest fromName(String name) =>
      Interest.values.firstWhere((i) => i.name == name, orElse: () => cliente);
}

enum Temperature {
  frio('Frío', '❄️', Color(0xFF64B5F6)),
  caliente('Caliente', '🔥', Color(0xFFFF7043));

  const Temperature(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;

  static Temperature fromName(String? name) => Temperature.values
      .firstWhere((t) => t.name == name, orElse: () => frio);
}

/// Deja solo los dígitos de un teléfono.
String digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

/// true si el texto parece un número de teléfono (y no una nota escrita en
/// el campo del teléfono, como "está en Instagram").
bool looksLikePhone(String phone) => digitsOnly(phone).length >= 7;

/// Número listo para wa.me: a los números locales de 10 dígitos o menos se
/// les antepone la clave de país.
String whatsappNumber(String phone, {String countryCode = '57'}) {
  final digits = digitsOnly(phone);
  if (phone.trim().startsWith('+') || digits.length > 10) return digits;
  return '$countryCode$digits';
}

/// Siguiente etapa al pulsar "Avanzar". Desde Seguimiento pasa a Socio si le
/// interesa el negocio, o a Cliente si solo el producto.
Stage? nextStage(Stage stage, Interest interest) => switch (stage) {
      Stage.nuevo => Stage.contactado,
      Stage.contactado => Stage.presentacion,
      Stage.presentacion => Stage.seguimiento,
      Stage.seguimiento =>
        interest == Interest.cliente ? Stage.cliente : Stage.socio,
      Stage.cliente => Stage.socio,
      Stage.socio => null,
      Stage.descartado => Stage.nuevo,
    };

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.source,
    required this.referredBy,
    required this.tags,
    required this.interest,
    required this.stage,
    required this.temperature,
    required this.favorite,
    required this.sponsorId,
    required this.notes,
    required this.qualification,
    required this.whyIncome,
    required this.whyHealth,
    required this.snoozedUntil,
    required this.createdAt,
  });

  factory Contact.fromRow(Map<String, dynamic> row) {
    final snoozed = row['snoozed_until'] as String?;
    return Contact(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String? ?? '',
      email: row['email'] as String? ?? '',
      city: row['city'] as String? ?? '',
      source: row['source'] as String? ?? '',
      referredBy: row['referred_by'] as String? ?? '',
      tags: ((row['tags'] as List?) ?? const []).cast<String>(),
      interest: Interest.fromName(row['interest'] as String? ?? ''),
      stage: Stage.fromName(row['stage'] as String? ?? ''),
      temperature: Temperature.fromName(row['temperature'] as String?),
      favorite: row['favorite'] as bool? ?? false,
      sponsorId: row['sponsor_id'] as String?,
      notes: row['notes'] as String? ?? '',
      qualification: Qualification.fromRow(row),
      whyIncome: row['why_income'] as String? ?? '',
      whyHealth: row['why_health'] as String? ?? '',
      snoozedUntil: snoozed == null ? null : DateTime.parse(snoozed),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
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
  final bool favorite;
  final String? sponsorId;
  final String notes;
  final Qualification? qualification;
  final String whyIncome;
  final String whyHealth;
  final DateTime? snoozedUntil;
  final DateTime createdAt;

  int? get score => qualification?.total;
  Category? get category => qualification?.category;
  bool get hasPhone => looksLikePhone(phone);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  /// true mientras esté en "Contactar después".
  bool isSnoozed(DateTime today) {
    final until = snoozedUntil;
    return until != null && until.isAfter(DateUtils.dateOnly(today));
  }

  /// Aparece en el tablero de Proceso: ni descartado ni pausado.
  bool isActive(DateTime today) =>
      stage != Stage.descartado && !isSnoozed(today);
}
