import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up English word definitions using the free dictionaryapi.dev
/// service. There's no local dictionary bundled with the app, so this only
/// works for single English words and requires internet access.
class DictionaryService {
  Future<List<String>> lookup(String word) async {
    final cleaned = word.trim().split(RegExp(r'\s+')).first.replaceAll(
          RegExp(r'[^\p{L}\-]', unicode: true),
          '',
        );
    if (cleaned.isEmpty) return [];

    final uri = Uri.parse(
      'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(cleaned)}',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as List;
    final definitions = <String>[];
    for (final entry in data) {
      final meanings = entry['meanings'] as List? ?? [];
      for (final meaning in meanings) {
        final partOfSpeech = meaning['partOfSpeech'] as String? ?? '';
        final defs = meaning['definitions'] as List? ?? [];
        for (final def in defs.take(2)) {
          final text = def['definition'] as String?;
          if (text != null) {
            definitions.add(
              partOfSpeech.isNotEmpty ? '($partOfSpeech) $text' : text,
            );
          }
        }
      }
    }
    return definitions;
  }
}
