import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/highlight.dart';
import '../services/highlights_service.dart';

class HighlightsScreen extends StatefulWidget {
  const HighlightsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends State<HighlightsScreen> {
  final _service = HighlightsService(Supabase.instance.client);
  late Future<List<Highlight>> _future =
      _service.fetchHighlights(widget.bookId);

  void _refresh() {
    setState(() => _future = _service.fetchHighlights(widget.bookId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resaltados y notas')),
      body: FutureBuilder<List<Highlight>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final highlights = snapshot.data!;
          if (highlights.isEmpty) {
            return const Center(child: Text('Aún no tienes resaltados.'));
          }
          return ListView.builder(
            itemCount: highlights.length,
            itemBuilder: (context, index) {
              final highlight = highlights[index];
              return ListTile(
                leading: CircleAvatar(backgroundColor: highlight.displayColor),
                title: Text(
                  highlight.snippet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: highlight.note?.isNotEmpty == true
                    ? Text(highlight.note!)
                    : null,
                onTap: () => Navigator.of(context).pop(highlight),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _service.deleteHighlight(highlight.id);
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
