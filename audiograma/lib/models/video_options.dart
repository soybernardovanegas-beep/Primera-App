import 'dart:ui';

/// Formatos de salida disponibles. Todos a 30 fps.
enum VideoFormat {
  vertical('Vertical 9:16', 'TikTok, Reels, Shorts', 1080, 1920),
  square('Cuadrado 1:1', 'Feed de Instagram', 1080, 1080),
  horizontal('Horizontal 16:9', 'YouTube', 1920, 1080);

  const VideoFormat(this.label, this.hint, this.width, this.height);

  final String label;
  final String hint;
  final int width;
  final int height;

  double get aspectRatio => width / height;
}

/// Estilos de la onda, mapeados a los modos del filtro `showwaves` de FFmpeg.
enum WaveStyle {
  centered('Onda centrada', 'cline'),
  line('Líneas', 'line'),
  trace('Trazo', 'p2p');

  const WaveStyle(this.label, this.ffmpegMode);

  final String label;
  final String ffmpegMode;
}

/// Colores de onda ofrecidos en la app.
const waveColors = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFFFD54F),
  Color(0xFF4DD0E1),
  Color(0xFFF06292),
  Color(0xFF81C784),
];

/// Color de fondo cuando el usuario no elige imagen.
const fallbackBackground = Color(0xFF1E1E2E);

/// Todo lo que hace falta para generar un vídeo.
class VideoOptions {
  const VideoOptions({
    required this.audioPath,
    required this.outputPath,
    this.imagePath,
    this.format = VideoFormat.vertical,
    this.waveStyle = WaveStyle.centered,
    this.waveColor = const Color(0xFFFFFFFF),
  });

  final String audioPath;
  final String outputPath;

  /// Imagen de fondo; si es null se usa [fallbackBackground].
  final String? imagePath;
  final VideoFormat format;
  final WaveStyle waveStyle;
  final Color waveColor;
}
