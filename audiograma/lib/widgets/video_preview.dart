import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/video_options.dart';

/// Vista previa aproximada del vídeo: misma composición y proporciones que
/// el filtro de FFmpeg, con una onda de ejemplo estática.
class VideoPreview extends StatelessWidget {
  const VideoPreview({
    super.key,
    required this.format,
    required this.waveStyle,
    required this.waveColor,
    this.imagePath,
  });

  final VideoFormat format;
  final WaveStyle waveStyle;
  final Color waveColor;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: format.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, box) {
            final h = box.maxHeight;
            final waveHeight = h * 0.2;
            final bottomMargin = h * 0.1;
            final bandPadding = h * 0.02;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (imagePath != null)
                  Image.file(File(imagePath!), fit: BoxFit.cover)
                else
                  const ColoredBox(color: fallbackBackground),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomMargin - bandPadding,
                  height: waveHeight + bandPadding * 2,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomMargin,
                  height: waveHeight,
                  child: CustomPaint(
                    painter: _SampleWavePainter(waveStyle, waveColor),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SampleWavePainter extends CustomPainter {
  _SampleWavePainter(this.style, this.color);

  final WaveStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final mid = size.height / 2;
    final random = Random(7);
    Offset? previous;
    for (var x = 0.0; x < size.width; x += 3) {
      final envelope = 0.35 + 0.65 * sin(x / size.width * pi * 3).abs();
      final amp = envelope * random.nextDouble() * mid;
      switch (style) {
        case WaveStyle.centered:
          canvas.drawLine(Offset(x, mid - amp), Offset(x, mid + amp), paint);
        case WaveStyle.line:
          canvas.drawLine(Offset(x, mid), Offset(x, mid - amp), paint);
        case WaveStyle.trace:
          final y = mid + (random.nextBool() ? amp : -amp);
          if (previous != null) canvas.drawLine(previous, Offset(x, y), paint);
          previous = Offset(x, y);
      }
    }
  }

  @override
  bool shouldRepaint(_SampleWavePainter old) =>
      old.style != style || old.color != color;
}
