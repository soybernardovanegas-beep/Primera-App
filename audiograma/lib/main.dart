import 'package:flutter/material.dart';

import 'screens/editor_screen.dart';

void main() {
  runApp(const AudiogramaApp());
}

class AudiogramaApp extends StatelessWidget {
  const AudiogramaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio a vídeo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD84315)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8A65),
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorScreen(),
    );
  }
}
