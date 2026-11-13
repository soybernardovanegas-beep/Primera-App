import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';

import '../models/video_options.dart';
import 'ffmpeg_command.dart';

class RenderException implements Exception {
  RenderException(this.message, [this.log]);

  final String message;
  final String? log;

  @override
  String toString() => message;
}

class RenderCancelled implements Exception {}

/// Ejecuta FFmpeg en el dispositivo (sin servidores ni internet).
class VideoRenderer {
  int? _sessionId;

  /// Duración del audio, o null si FFprobe no la puede leer.
  static Future<Duration?> audioDuration(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final seconds = double.tryParse(
      session.getMediaInformation()?.getDuration() ?? '',
    );
    if (seconds == null) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Genera el vídeo. [onProgress] recibe valores entre 0 y 1.
  Future<void> render(
    VideoOptions options, {
    required Duration audioLength,
    void Function(double progress)? onProgress,
  }) async {
    final done = Completer<void>();
    final totalMs = audioLength.inMilliseconds;

    final session = await FFmpegKit.executeWithArgumentsAsync(
      buildFfmpegArgs(options),
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          done.complete();
        } else if (ReturnCode.isCancel(code)) {
          done.completeError(RenderCancelled());
        } else {
          done.completeError(
            RenderException(
              'FFmpeg no pudo generar el vídeo (código ${code?.getValue()}).',
              await session.getAllLogsAsString(),
            ),
          );
        }
      },
      null,
      (stats) {
        if (onProgress == null || totalMs <= 0) return;
        onProgress((stats.getTime() / totalMs).clamp(0.0, 1.0));
      },
    );
    _sessionId = session.getSessionId();

    try {
      await done.future;
    } finally {
      _sessionId = null;
    }
  }

  Future<void> cancel() async {
    final id = _sessionId;
    if (id != null) await FFmpegKit.cancel(id);
  }
}
