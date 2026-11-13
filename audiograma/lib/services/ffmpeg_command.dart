import 'dart:ui';

import '../models/video_options.dart';

const frameRate = 30;

/// Construye los argumentos de FFmpeg para generar el vídeo.
///
/// Se pasan como lista (no como un único string) para que las rutas con
/// espacios o acentos no necesiten escaparse.
///
/// Composición:
/// - Fondo: la imagen escalada para cubrir todo el cuadro y recortada al
///   centro, o un color liso si no hay imagen.
/// - Una franja semitransparente en el tercio inferior para que la onda se
///   lea sobre cualquier imagen.
/// - La onda (`showwaves`) encima de esa franja.
/// - Audio recodificado a AAC; el vídeo dura lo mismo que el audio.
List<String> buildFfmpegArgs(VideoOptions o) {
  final w = o.format.width;
  final h = o.format.height;
  final waveHeight = _even(h * 0.2);
  final bottomMargin = _even(h * 0.1);
  final bandPadding = _even(h * 0.02);
  final bandY = h - bottomMargin - waveHeight - bandPadding;
  final bandHeight = waveHeight + bandPadding * 2;

  final background = o.imagePath == null
      ? [
          '-f',
          'lavfi',
          '-i',
          'color=c=${_hex(fallbackBackground)}:s=${w}x$h:r=$frameRate',
        ]
      : ['-loop', '1', '-framerate', '$frameRate', '-i', o.imagePath!];

  final filter = [
    '[0:v]scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1,'
        'drawbox=x=0:y=$bandY:w=iw:h=$bandHeight:color=black@0.35:t=fill,'
        'format=rgba[bg]',
    '[1:a]aformat=channel_layouts=mono,'
        'showwaves=s=${w}x$waveHeight:mode=${o.waveStyle.ffmpegMode}'
        ':rate=$frameRate:scale=sqrt:colors=${_hex(o.waveColor)}[wave]',
    '[bg][wave]overlay=0:${h - bottomMargin - waveHeight}:shortest=1,'
        'format=yuv420p[v]',
  ].join(';');

  return [
    '-y',
    '-hide_banner',
    ...background,
    '-i',
    o.audioPath,
    '-filter_complex',
    filter,
    '-map',
    '[v]',
    '-map',
    '1:a',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-crf',
    '23',
    '-r',
    '$frameRate',
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-shortest',
    '-movflags',
    '+faststart',
    o.outputPath,
  ];
}

/// libx264 con yuv420p exige dimensiones pares.
int _even(double v) => (v ~/ 2) * 2;

String _hex(Color c) =>
    '0x${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
