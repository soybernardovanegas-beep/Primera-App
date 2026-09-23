import 'package:flutter/material.dart';

enum InteractionKind {
  llamada('Llamada', Icons.call_outlined),
  whatsapp('WhatsApp', Icons.chat_outlined),
  reunion('Reunión', Icons.coffee_outlined),
  presentacion('Presentación', Icons.slideshow_outlined),
  otro('Otro', Icons.notes_outlined);

  const InteractionKind(this.label, this.icon);

  final String label;
  final IconData icon;

  static InteractionKind fromName(String name) => InteractionKind.values
      .firstWhere((k) => k.name == name, orElse: () => otro);
}

class Interaction {
  const Interaction({
    required this.id,
    required this.contactId,
    required this.kind,
    required this.note,
    required this.occurredAt,
  });

  factory Interaction.fromRow(Map<String, dynamic> row) {
    return Interaction(
      id: row['id'] as String,
      contactId: row['contact_id'] as String,
      kind: InteractionKind.fromName(row['kind'] as String),
      note: row['note'] as String,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
    );
  }

  final String id;
  final String contactId;
  final InteractionKind kind;
  final String note;
  final DateTime occurredAt;
}
