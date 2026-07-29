import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_item.dart';
import '../services/agenda_service.dart';
import 'day_screen.dart';
import 'notes_screen.dart';
import 'search_screen.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  final _service = AgendaService(Supabase.instance.client);

  late DateTime _weekStart = _mondayOf(DateTime.now());
  Map<String, List<AgendaItem>> _itemsByDate = {};
  bool _isLoading = true;

  DateTime _mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final items = await _service.fetchItemsForRange(_weekStart, weekEnd);
    final grouped = <String, List<AgendaItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(formatDateOnly(item.itemDate), () => []).add(item);
    }
    if (!mounted) return;
    setState(() {
      _itemsByDate = grouped;
      _isLoading = false;
    });
  }

  void _changeWeek(int deltaWeeks) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks)));
    _load();
  }

  void _goToToday() {
    setState(() => _weekStart = _mondayOf(DateTime.now()));
    _load();
  }

  Future<void> _openDay(DateTime date) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DayScreen(date: date)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(_weekStart);

    return Scaffold(
      appBar: AppBar(
        title: Text(monthLabel[0].toUpperCase() + monthLabel.substring(1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.note_outlined),
            tooltip: 'Notas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeWeek(-1),
              ),
              TextButton(onPressed: _goToToday, child: const Text('Hoy')),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeWeek(1),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final items = _itemsByDate[formatDateOnly(date)] ?? [];
                final isToday = formatDateOnly(date) ==
                    formatDateOnly(DateTime.now());
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isToday
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    onTap: () => _openDay(date),
                    title: Text(
                      DateFormat('EEEE d', 'es').format(date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: items.isEmpty
                        ? const Text('Sin pendientes')
                        : Text(
                            items
                                .take(3)
                                .map((i) => i.done ? '✓ ${i.text}' : i.text)
                                .join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: items.isEmpty
                        ? null
                        : CircleAvatar(
                            radius: 12,
                            child: Text(
                              '${items.length}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
