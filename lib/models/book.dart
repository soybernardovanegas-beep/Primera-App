class Book {
  Book({
    required this.id,
    required this.hash,
    required this.title,
    required this.author,
    required this.addedAt,
    required this.localPath,
    required this.coverPath,
  });

  factory Book.fromRow(
    Map<String, dynamic> row,
    String localPath,
    String coverPath,
  ) {
    return Book(
      id: row['id'] as String,
      hash: row['hash'] as String,
      title: row['title'] as String,
      author: row['author'] as String?,
      addedAt: DateTime.parse(row['added_at'] as String),
      localPath: localPath,
      coverPath: coverPath,
    );
  }

  final String id;
  final String hash;
  final String title;
  final String? author;
  final DateTime addedAt;

  /// Path to the EPUB file on this device. Empty when the book exists in
  /// the synced library but hasn't been imported on this device yet.
  final String localPath;

  /// Path to a cached cover thumbnail on this device. Empty when no cover
  /// could be extracted or the book hasn't been imported here yet.
  final String coverPath;

  bool get availableLocally => localPath.isNotEmpty;
  bool get hasCover => coverPath.isNotEmpty;
}
