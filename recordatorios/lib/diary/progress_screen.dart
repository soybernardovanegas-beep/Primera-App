import 'package:flutter/material.dart';

import '../theme.dart';
import 'content.dart';
import 'diary_store.dart';
import 'widgets.dart';

/// Pestaña PROGRESO: la cuenta acumulada de los 90 días.
class ProgressScreen extends StatelessWidget {
  final DiaryStore store;

  const ProgressScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final energy = store.energySeries();
        final rates = store.commitmentRates();
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          children: [
            const Text(
              'Progreso',
              style: TextStyle(
                fontFamily: serif,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text('LA CUENTA DE LOS $programDays DÍAS', style: labelStyle()),
            const SizedBox(height: 40),
            StatGrid(
              cells: [
                StatCell(
                  value: '${store.totalContacted}',
                  label: 'Personas contactadas',
                ),
                StatCell(
                  value: '${store.totalPresented}',
                  label: 'Presentaciones',
                ),
                StatCell(
                  value: '${store.totalFollowed}',
                  label: 'Seguimientos',
                ),
                StatCell(
                  value: '${store.totalNewProspects}',
                  label: 'Prospectos nuevos',
                ),
                StatCell(
                  value: '${store.streak()}',
                  label: 'Racha de días completos',
                  color: AppColors.accent,
                ),
                StatCell(
                  value: '${store.daysTeamMovedWithoutMe}',
                  label: 'Días que el equipo se movió sin ti',
                ),
              ],
            ),
            const SectionGap(),
            const SectionLabel('Energía · inicio vs. cierre'),
            if (energy.isEmpty)
              const Text(
                'Registra tu energía en la mañana y en la noche para ver la '
                'gráfica.',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              )
            else ...[
              SizedBox(
                height: 280,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _EnergyChartPainter(energy),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(width: 28, height: 3, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Text('INICIO', style: labelStyle()),
                  const SizedBox(width: 40),
                  Container(width: 28, height: 3, color: AppColors.ink),
                  const SizedBox(width: 12),
                  Text('CIERRE', style: labelStyle()),
                ],
              ),
            ],
            const SectionGap(),
            const SectionLabel('Cumplimiento de compromisos'),
            for (final (i, c) in nightCommitments.indexed)
              _RateBar(label: c, rate: rates[i]),
          ],
        );
      },
    );
  }
}

class _RateBar extends StatelessWidget {
  final String label;
  final double rate;

  const _RateBar({required this.label, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 17, color: AppColors.ink),
                ),
              ),
              Text(
                '${(rate * 100).round()}%',
                style: const TextStyle(
                  fontFamily: serif,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(height: 4, color: AppColors.line),
              FractionallySizedBox(
                widthFactor: rate,
                child: Container(height: 4, color: AppColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dos curvas suaves de energía (1–10) por día: inicio en rojo continuo y
/// cierre en negro punteado.
class _EnergyChartPainter extends CustomPainter {
  final List<({int day, int? start, int? end})> data;

  _EnergyChartPainter(this.data);

  static const _left = 16.0;
  static const _bottom = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left - 8;
    final h = size.height - _bottom;
    double x(int i) =>
        _left + (data.length == 1 ? w / 2 : w * i / (data.length - 1));
    double y(int v) => h - h * (v - 1) / 9;

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (final v in [4, 7, 10]) {
      _dashed(canvas, Offset(_left, y(v)), Offset(size.width, y(v)), grid, 3);
    }
    canvas.drawLine(Offset(_left, 0), Offset(_left, h), grid);
    canvas.drawLine(Offset(_left, h), Offset(size.width, h), grid);

    for (final (i, d) in data.indexed) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${d.day}',
          style: const TextStyle(
            fontFamily: sans,
            color: AppColors.muted,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, h + 10));
    }

    _series(
      canvas,
      [
        for (final (i, d) in data.indexed)
          if (d.start != null) Offset(x(i), y(d.start!)),
      ],
      AppColors.accent,
      dashed: false,
    );
    _series(
      canvas,
      [
        for (final (i, d) in data.indexed)
          if (d.end != null) Offset(x(i), y(d.end!)),
      ],
      AppColors.ink,
      dashed: true,
    );
  }

  void _series(
    Canvas canvas,
    List<Offset> pts,
    Color color, {
    required bool dashed,
  }) {
    if (pts.isEmpty) return;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mid = (b.dx - a.dx) / 2;
      path.cubicTo(a.dx + mid, a.dy, b.dx - mid, b.dy, b.dx, b.dy);
    }
    if (dashed) {
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 9) {
          canvas.drawPath(metric.extractPath(d, d + 5), line);
        }
      }
    } else {
      canvas.drawPath(path, line);
    }
    final dot = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 6, dot);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, double dash) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash * 2) {
      canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, total), paint);
    }
  }

  @override
  bool shouldRepaint(_EnergyChartPainter old) => old.data != data;
}
