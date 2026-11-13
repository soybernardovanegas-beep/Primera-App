import 'package:audiograma/main.dart';
import 'package:audiograma/models/video_options.dart';
import 'package:audiograma/widgets/video_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pantalla alta para que el ListView construya todas las secciones.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Generar está deshabilitado hasta elegir un audio', (
    tester,
  ) async {
    _tallScreen(tester);
    await tester.pumpWidget(const AudiogramaApp());

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Generar vídeo'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('La vista previa sigue el formato elegido', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(const AudiogramaApp());

    AspectRatio previewRatio() => tester.widget<AspectRatio>(
      find.descendant(
        of: find.byType(VideoPreview),
        matching: find.byType(AspectRatio),
      ),
    );

    expect(previewRatio().aspectRatio, VideoFormat.vertical.aspectRatio);
    await tester.tap(find.text('16:9'));
    await tester.pump();
    expect(previewRatio().aspectRatio, VideoFormat.horizontal.aspectRatio);
  });
}
