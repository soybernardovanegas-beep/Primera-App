import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_item.dart';
import '../services/agenda_service.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  final _service = AgendaService(Supabase.instance.client);
  final _textController = TextEditingController();

  List<AgendaItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.fetchItemsForRange(widget.date, widget.date);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _addItem() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _service.addItem(widget.date, text);
    _load();
  }

  Future<void> _toggleDone(AgendaItem item) async {
    await _service.setDone(item.id, !item.done);
    _load();
  }

  Future<void> _deleteItem(AgendaItem item) async {
    await _service.deleteItem(item.id);
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('EEEE d MMMM', 'es').format(widget.date);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('Sin pendientes para este día.'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            leading: Checkbox(
                              value: item.done,
                              onChanged: (_) => _toggleDone(item),
                            ),
                            title: Text(
                              item.text,
                              style: item.done
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteItem(item),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Agregar pendiente...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: _addItem,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
