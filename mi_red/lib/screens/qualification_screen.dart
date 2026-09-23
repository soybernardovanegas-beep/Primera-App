import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/qualification.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';

/// Cuestionario de 4 preguntas que califica al prospecto (máximo 20 pts).
/// Devuelve `true` al hacer pop si se guardó.
class QualificationScreen extends StatefulWidget {
  const QualificationScreen({super.key, required this.contact});

  final Contact contact;

  @override
  State<QualificationScreen> createState() => _QualificationScreenState();
}

class _QualificationScreenState extends State<QualificationScreen> {
  final _service = CrmService(Supabase.instance.client);
  final List<int> _answers = [];
  Qualification? _result;
  bool _saving = false;

  Future<void> _answer(int points) async {
    _answers.add(points);
    if (_answers.length < qualificationQuestions.length) {
      setState(() {});
      return;
    }
    final q = Qualification(List.of(_answers));
    setState(() => _saving = true);
    try {
      await _service.setQualification(widget.contact.id, q);
      if (mounted) {
        setState(() {
          _result = q;
          _saving = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      _answers.removeLast();
      setState(() => _saving = false);
      showSnack(context, 'No se pudo guardar la calificación.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(),
      body: result != null
          ? _ResultView(contact: widget.contact, result: result)
          : _saving
              ? const Center(child: CircularProgressIndicator())
              : _QuestionView(
                  contact: widget.contact,
                  index: _answers.length,
                  onAnswer: _answer,
                  onBack: _answers.isEmpty
                      ? null
                      : () => setState(() => _answers.removeLast()),
                ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.contact,
    required this.index,
    required this.onAnswer,
    required this.onBack,
  });

  final Contact contact;
  final int index;
  final ValueChanged<int> onAnswer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = qualificationQuestions[index];
    final total = qualificationQuestions.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i <= index ? gold : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(contact.name, style: theme.textTheme.titleLarge),
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'PREGUNTA ${index + 1} DE $total',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: gold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          question.title,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          question.question,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 20),
        for (final option in question.options)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Text(option.emoji, style: const TextStyle(fontSize: 30)),
              title: Text(option.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(option.subtitle),
              trailing: Text(
                '${option.points} pts',
                style: const TextStyle(color: gold, fontWeight: FontWeight.w600),
              ),
              onTap: () => onAnswer(option.points),
            ),
          ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.contact, required this.result});

  final Contact contact;
  final Qualification result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = result.category;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 72,
              backgroundColor: category.color.withValues(alpha: 0.15),
              child: Text(
                '${result.total}',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: category.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              contact.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${category.label} ${category.emoji}',
              style: theme.textTheme.titleLarge?.copyWith(color: category.color),
            ),
            const SizedBox(height: 16),
            Text(
              '"${category.message}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Guardado · Ver Contactos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
