import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/progress_service.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.bookId, required this.title});

  final String bookId;
  final String title;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _statsService = StatsService(Supabase.instance.client);
  final _progressService = ProgressService(Supabase.instance.client);

  late final Future<(BookStats, ReadingProgress?)> _future = () async {
    final stats = await _statsService.fetchStats(widget.bookId);
    final progress = await _progressService.fetchProgress(widget.bookId);
    return (stats, progress);
  }();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Estadísticas · ${widget.title}')),
      body: FutureBuilder<(BookStats, ReadingProgress?)>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (stats, progress) = snapshot.data!;
          final percentage = progress?.percentage ?? 0;
          final remaining = _estimateRemaining(stats.totalSeconds, percentage);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatTile(
                icon: Icons.donut_large,
                label: 'Progreso',
                value: '${percentage.toStringAsFixed(0)}%',
              ),
              _StatTile(
                icon: Icons.timer_outlined,
                label: 'Tiempo total de lectura',
                value: _formatDuration(stats.totalSeconds),
              ),
              _StatTile(
                icon: Icons.local_fire_department,
                label: 'Racha de lectura',
                value:
                    '${stats.streakDays} día${stats.streakDays == 1 ? '' : 's'}',
              ),
              if (remaining != null)
                _StatTile(
                  icon: Icons.hourglass_bottom,
                  label: 'Tiempo estimado restante',
                  value: _formatDuration(remaining),
                ),
            ],
          );
        },
      ),
    );
  }

  int? _estimateRemaining(int totalSeconds, double percentage) {
    if (totalSeconds <= 0 || percentage <= 0 || percentage >= 100) return null;
    final secondsPerPercent = totalSeconds / percentage;
    return (secondsPerPercent * (100 - percentage)).round();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
