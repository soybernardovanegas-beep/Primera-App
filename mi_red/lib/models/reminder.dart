class Reminder {
  const Reminder({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.dueAt,
    required this.note,
    required this.done,
  });

  factory Reminder.fromRow(Map<String, dynamic> row) {
    final contact = row['crm_contacts'] as Map<String, dynamic>?;
    return Reminder(
      id: row['id'] as String,
      contactId: row['contact_id'] as String,
      contactName: contact?['name'] as String? ?? '',
      dueAt: DateTime.parse(row['due_at'] as String).toLocal(),
      note: row['note'] as String,
      done: row['done'] as bool,
    );
  }

  final String id;
  final String contactId;
  final String contactName;
  final DateTime dueAt;
  final String note;
  final bool done;

  bool isOverdue(DateTime now) => dueAt.isBefore(now);
}

/// El recordatorio vigente de cada contacto: el pendiente más próximo. Los
/// demás quedan en cola y aparecen al completar el anterior.
Map<String, Reminder> currentReminderByContact(List<Reminder> pending) {
  final sorted = [...pending]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  final result = <String, Reminder>{};
  for (final r in sorted) {
    result.putIfAbsent(r.contactId, () => r);
  }
  return result;
}
