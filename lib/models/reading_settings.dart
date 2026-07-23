import 'package:flutter/material.dart';

enum ReaderTheme { light, dark, sepia }

class ReadingSettings {
  const ReadingSettings({
    this.fontSize = 16,
    this.fontFamily = 'Default',
    this.lineHeight = 1.25,
    this.theme = ReaderTheme.light,
  });

  factory ReadingSettings.fromRow(Map<String, dynamic> row) {
    return ReadingSettings(
      fontSize: (row['font_size'] as num).toDouble(),
      fontFamily: row['font_family'] as String,
      lineHeight: (row['line_height'] as num).toDouble(),
      theme: ReaderTheme.values.firstWhere(
        (t) => t.name == row['theme'],
        orElse: () => ReaderTheme.light,
      ),
    );
  }

  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final ReaderTheme theme;

  Map<String, dynamic> toRow() => {
        'font_size': fontSize,
        'font_family': fontFamily,
        'line_height': lineHeight,
        'theme': theme.name,
      };

  ReadingSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
    ReaderTheme? theme,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
    );
  }

  Color get backgroundColor {
    switch (theme) {
      case ReaderTheme.light:
        return Colors.white;
      case ReaderTheme.dark:
        return const Color(0xFF121212);
      case ReaderTheme.sepia:
        return const Color(0xFFF4ECD8);
    }
  }

  Color get textColor {
    switch (theme) {
      case ReaderTheme.light:
        return Colors.black87;
      case ReaderTheme.dark:
        return Colors.white70;
      case ReaderTheme.sepia:
        return const Color(0xFF5B4636);
    }
  }

  TextStyle get textStyle => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: textColor,
        fontFamily: fontFamily == 'Default' ? null : fontFamily,
      );
}
