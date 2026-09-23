import 'package:flutter/material.dart';

/// Etapas del embudo de un contacto, en el orden en que suelen avanzar.
enum Stage {
  nuevo('Nuevo', Icons.fiber_new_outlined, Color(0xFF78909C)),
  contactado('Contactado', Icons.chat_bubble_outline, Color(0xFF1E88E5)),
  presentacion('Presentación', Icons.slideshow_outlined, Color(0xFF8E24AA)),
  seguimiento('Seguimiento', Icons.schedule_outlined, Color(0xFFFB8C00)),
  cliente('Cliente', Icons.shopping_bag_outlined, Color(0xFF43A047)),
  socio('Socio', Icons.handshake_outlined, Color(0xFF00897B)),
  descartado('No interesado', Icons.block_outlined, Color(0xFFE53935));

  const Stage(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static Stage fromName(String name) =>
      Stage.values.firstWhere((s) => s.name == name, orElse: () => nuevo);
}

/// Qué le interesa al prospecto: consumir el producto, el negocio o ambos.
enum Interest {
  cliente('Producto'),
  socio('Negocio'),
  ambos('Ambos');

  const Interest(this.label);

  final String label;

  static Interest fromName(String name) =>
      Interest.values.firstWhere((i) => i.name == name, orElse: () => cliente);
}

/// Deja solo los dígitos de un teléfono, para armar enlaces tel: y wa.me.
String digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.source,
    required this.interest,
    required this.stage,
    required this.sponsorId,
    required this.notes,
    required this.nextFollowUp,
    required this.createdAt,
  });

  factory Contact.fromRow(Map<String, dynamic> row) {
    final followUp = row['next_follow_up'] as String?;
    return Contact(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      email: row['email'] as String,
      city: row['city'] as String,
      source: row['source'] as String,
      interest: Interest.fromName(row['interest'] as String),
      stage: Stage.fromName(row['stage'] as String),
      sponsorId: row['sponsor_id'] as String?,
      notes: row['notes'] as String,
      nextFollowUp: followUp == null ? null : DateTime.parse(followUp),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
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
  final DateTime createdAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  /// true si el seguimiento programado es hoy o ya pasó.
  bool isFollowUpDue(DateTime today) {
    final date = nextFollowUp;
    if (date == null) return false;
    return !DateTime(date.year, date.month, date.day)
        .isAfter(DateTime(today.year, today.month, today.day));
  }
}
