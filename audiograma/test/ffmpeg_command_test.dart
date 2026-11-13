import 'dart:io';

import 'package:audiograma/models/video_options.dart';
import 'package:audiograma/services/ffmpeg_command.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildFfmpegArgs', () {
    test('usa la imagen en bucle y termina en la ruta de salida', () {
      final args = buildFfmpegArgs(
        const VideoOptions(
          audioPath: '/audio con espacios.mp3',
          outputPath: '/salida.mp4',
          imagePath: '/fondo.jpg',
        ),
      );
      expect(args.sublist(2, 7), ['-loop', '1', '-framerate', '30', '-i']);
      expect(args[7], '/fondo.jpg');
      expect(args, containsAllInOrder(['-i', '/audio con espacios.mp3']));
      expect(args.last, '/salida.mp4');
    });

    test('sin imagen usa un fondo de color del tamaño del formato', () {
      final args = buildFfmpegArgs(
        const VideoOptions(
          audioPath: 'a.mp3',
          outputPath: 'o.mp4',
          format: VideoFormat.horizontal,
        ),
      );
      expect(args, contains('color=c=0x1E1E2E:s=1920x1080:r=30'));
    });

    test('aplica estilo, color y dimensiones pares de la onda', () {
      final args = buildFfmpegArgs(
        const VideoOptions(
          audioPath: 'a.mp3',
          outputPath: 'o.mp4',
          format: VideoFormat.square,
          waveStyle: WaveStyle.trace,
          waveColor: Color(0xFFFFD54F),
        ),
      );
      final filter = args[args.indexOf('-filter_complex') + 1];
      expect(filter, contains('crop=1080:1080'));
      expect(filter, contains('showwaves=s=1080x216:mode=p2p'));
      expect(filter, contains('colors=0xFFD54F'));
    });
  });

  // Ejecuta el comando real con el ffmpeg del sistema, si está instalado,
  // para comprobar que el grafo de filtros es válido en cada formato.
  final ffmpeg = Process.runSync('which', ['ffmpeg']).exitCode == 0;
  group('ffmpeg del sistema', () {
    late Directory tmp;
    late String audio;
    late String image;

    setUpAll(() {
      tmp = Directory.systemTemp.createTempSync('audiograma');
      audio = '${tmp.path}/tono de prueba.mp3';
      image = '${tmp.path}/fondo.png';
      Process.runSync('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=330:duration=2',
        audio,
      ]);
      Process.runSync('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=s=1200x900',
        '-frames:v',
        '1',
        image,
      ]);
    });

    tearDownAll(() => tmp.deleteSync(recursive: true));

    for (final format in VideoFormat.values) {
      for (final withImage in [true, false]) {
        test('${format.name}, ${withImage ? 'con' : 'sin'} imagen', () {
          final out = '${tmp.path}/${format.name}_$withImage.mp4';
          final run = Process.runSync('ffmpeg', [
            '-loglevel',
            'error',
            ...buildFfmpegArgs(
              VideoOptions(
                audioPath: audio,
                outputPath: out,
                imagePath: withImage ? image : null,
                format: format,
              ),
            ),
          ]);
          expect(run.exitCode, 0, reason: run.stderr as String);

          final probe =
              Process.runSync('ffprobe', [
                    '-v',
                    'error',
                    '-select_streams',
                    'v:0',
                    '-show_entries',
                    'stream=width,height:format=duration',
                    '-of',
                    'default=noprint_wrappers=1',
                    out,
                  ]).stdout
                  as String;
          expect(probe, contains('width=${format.width}'));
          expect(probe, contains('height=${format.height}'));
          final duration = double.parse(
            RegExp(r'duration=([\d.]+)').firstMatch(probe)!.group(1)!,
          );
          expect(duration, closeTo(2.0, 0.15));
        });
      }
    }
  }, skip: ffmpeg ? false : 'ffmpeg no está instalado');
}
