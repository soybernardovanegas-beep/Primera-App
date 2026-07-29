class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.itemDate,
    required this.text,
    required this.done,
    required this.createdAt,
  });

  factory AgendaItem.fromRow(Map<String, dynamic> row) {
    return AgendaItem(
      id: row['id'] as String,
      itemDate: DateTime.parse(row['item_date'] as String),
      text: row['text'] as String,
      done: row['done'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final DateTime itemDate;
  final String text;
  final bool done;
  final DateTime createdAt;
}
