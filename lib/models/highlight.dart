import 'package:flutter/material.dart';

const Map<String, Color> highlightColors = {
  'yellow': Color(0xFFFFF59D),
  'green': Color(0xFFA5D6A7),
  'blue': Color(0xFF90CAF9),
  'pink': Color(0xFFF48FB1),
};

class Highlight {
  const Highlight({
    required this.id,
    required this.bookId,
    required this.cfi,
    required this.snippet,
    required this.color,
    required this.note,
    required this.createdAt,
  });

  factory Highlight.fromRow(Map<String, dynamic> row) {
    return Highlight(
      id: row['id'] as String,
      bookId: row['book_id'] as String,
      cfi: row['cfi'] as String,
      snippet: row['snippet'] as String,
      color: row['color'] as String,
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String bookId;
  final String cfi;
  final String snippet;
  final String color;
  final String? note;
  final DateTime createdAt;

  Color get displayColor => highlightColors[color] ?? highlightColors['yellow']!;
}
