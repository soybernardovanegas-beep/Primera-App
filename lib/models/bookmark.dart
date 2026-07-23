class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.cfi,
    required this.label,
    required this.createdAt,
  });

  factory Bookmark.fromRow(Map<String, dynamic> row) {
    return Bookmark(
      id: row['id'] as String,
      bookId: row['book_id'] as String,
      cfi: row['cfi'] as String,
      label: row['label'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String bookId;
  final String cfi;
  final String? label;
  final DateTime createdAt;
}
