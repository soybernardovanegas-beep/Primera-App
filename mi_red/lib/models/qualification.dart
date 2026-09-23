import 'package:flutter/material.dart';

/// Clasificación del prospecto según su puntaje (máximo 20).
enum Category {
  ideal('Ideal', '🦈', Color(0xFFD4AF6A),
      'Perfil ideal. ¡Contáctalo cuanto antes! 🚀'),
  potencial('Potencial', '🐬', Color(0xFF26C6A0),
      'Buen prospecto. Vale la pena darle seguimiento 🌟'),
  incierto('Incierto', '🦔', Color(0xFF90A4AE),
      'Tómalo con calma: primero construye confianza 🤝');

  const Category(this.label, this.emoji, this.color, this.message);

  final String label;
  final String emoji;
  final Color color;
  final String message;

  static Category fromScore(int score) {
    if (score >= 15) return ideal;
    if (score >= 10) return potencial;
    return incierto;
  }
}

class QualificationOption {
  const QualificationOption(this.emoji, this.title, this.subtitle, this.points);

  final String emoji;
  final String title;
  final String subtitle;
  final int points;
}

class QualificationQuestion {
  const QualificationQuestion({
    required this.column,
    required this.shortLabel,
    required this.title,
    required this.question,
    required this.options,
  });

  /// Columna de crm_contacts donde se guarda la respuesta.
  final String column;
  final String shortLabel;
  final String title;
  final String question;
  final List<QualificationOption> options;

  int get maxPoints =>
      options.map((o) => o.points).reduce((a, b) => a > b ? a : b);
}

const qualificationQuestions = [
  QualificationQuestion(
    column: 'score_age',
    shortLabel: 'Edad',
    title: 'Edad',
    question: '¿En qué rango de edad se encuentra esta persona?',
    options: [
      QualificationOption('🌱', '18–25 años', 'Joven, en formación', 2),
      QualificationOption('💪', '26–45 años', 'Edad productiva ideal', 3),
      QualificationOption('🌳', '46 o más', 'Experiencia y estabilidad', 1),
    ],
  ),
  QualificationQuestion(
    column: 'score_credibility',
    shortLabel: 'Credibilidad',
    title: 'Credibilidad',
    question: '¿Qué nivel de confianza hay entre usted y esta persona?',
    options: [
      QualificationOption('🤝', 'Nulo', 'No nos conocemos bien', 1),
      QualificationOption('😊', 'Parcial', 'Hay cierta confianza', 3),
      QualificationOption('💎', 'Total', 'Confianza plena', 5),
    ],
  ),
  QualificationQuestion(
    column: 'score_solvency',
    shortLabel: 'Solvencia',
    title: 'Actitud y Solvencia',
    question: '¿Es emprendedor(a)? ¿Tiene solvencia económica?',
    options: [
      QualificationOption('😐', 'No emprendedor / Sin solvencia',
          'Bajo potencial de inversión', 1),
      QualificationOption('💰', 'No emprendedor / Con solvencia',
          'Tiene recursos pero no mentalidad', 2),
      QualificationOption('🚀', 'Emprendedor / Sin solvencia',
          'Mentalidad pero sin recursos aún', 4),
      QualificationOption('🔥', 'Emprendedor / Con solvencia',
          'Perfil ideal de inversión', 6),
    ],
  ),
  QualificationQuestion(
    column: 'score_social',
    shortLabel: 'Social',
    title: 'Comportamiento Social',
    question: '¿Cómo se relaciona esta persona socialmente?',
    options: [
      QualificationOption('🦔', 'Erizo', 'Incrédulo y escéptico', 1),
      QualificationOption('🐋', 'Ballena', 'Servicial, le gusta ayudar', 2),
      QualificationOption('🐬', 'Delfín', 'Sociable, le gusta estar con todos', 4),
      QualificationOption('🦈', 'Tiburón', 'Directo y decidido', 6),
    ],
  ),
];

/// Respuestas del cuestionario, en el mismo orden que
/// [qualificationQuestions].
class Qualification {
  const Qualification(this.points);

  /// null si el contacto aún no se ha calificado por completo.
  static Qualification? fromRow(Map<String, dynamic> row) {
    final points = [
      for (final q in qualificationQuestions) (row[q.column] as num?)?.toInt(),
    ];
    if (points.any((p) => p == null)) return null;
    return Qualification(points.cast<int>());
  }

  final List<int> points;

  int get total => points.fold(0, (a, b) => a + b);
  Category get category => Category.fromScore(total);

  Map<String, dynamic> toRow() => {
        for (var i = 0; i < qualificationQuestions.length; i++)
          qualificationQuestions[i].column: points[i],
      };
}
