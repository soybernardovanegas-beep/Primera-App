class BookCollection {
  const BookCollection({required this.id, required this.name});

  factory BookCollection.fromRow(Map<String, dynamic> row) {
    return BookCollection(id: row['id'] as String, name: row['name'] as String);
  }

  final String id;
  final String name;
}
