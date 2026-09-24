import 'package:flutter/material.dart';

import '../theme.dart';

/// Separación estándar entre secciones de un formulario del diario.
class SectionGap extends StatelessWidget {
  const SectionGap({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Divider(height: 1, color: AppColors.line),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(text.toUpperCase(), style: labelStyle()),
  );
}

/// Botón rectangular de opción ("CONTACTAR", "NINGUNO", "SÍ, SUMÉ"...).
class ChoiceBox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceBox({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label.toUpperCase(),
          style: labelStyle(
            color: selected ? Colors.white : AppColors.muted,
            size: 14,
          ).copyWith(letterSpacing: 2.2),
        ),
      ),
    );
  }
}

/// Opciones de las que se elige una (o ninguna al tocar la elegida).
class ChoiceGroup<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T?> onChanged;

  const ChoiceGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (v, label) in options)
          ChoiceBox(
            label: label,
            selected: v == value,
            onTap: () => onChanged(v == value ? null : v),
          ),
      ],
    );
  }
}

/// Escala de números en cuadros (energía 1–10, prospectos 0–6...).
class ScaleSelector extends StatelessWidget {
  final int min;
  final int max;
  final int? value;
  final ValueChanged<int?> onChanged;

  const ScaleSelector({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var n = min; n <= max; n++)
          InkWell(
            onTap: () => onChanged(n == value ? null : n),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: n == value ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: n == value ? AppColors.accent : AppColors.line,
                ),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 18,
                  color: n == value ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Casilla cuadrada con texto ("Madrugar").
class CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const CheckRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: checked ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: checked ? AppColors.accent : AppColors.line,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: checked ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto sin caja, con una línea debajo.
class LineField extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final int minLines;

  const LineField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint = '',
    this.minLines = 1,
  });

  @override
  State<LineField> createState() => _LineFieldState();
}

class _LineFieldState extends State<LineField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: widget.minLines,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 19, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: AppColors.faint),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class Quote extends StatelessWidget {
  final String text;

  const Quote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      '"$text"',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: serif,
        fontStyle: FontStyle.italic,
        fontSize: 22,
        height: 1.6,
        color: AppColors.ink,
      ),
    ),
  );
}

/// Botón principal ("SELLAR LA INTENCIÓN") con la nota de guardado debajo.
class SealButton extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback onPressed;

  const SealButton({
    super.key,
    required this.label,
    required this.done,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: done ? Colors.transparent : AppColors.accent,
          shape: done
              ? const Border.fromBorderSide(BorderSide(color: AppColors.accent))
              : null,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                (done ? 'Sellado · toca para reabrir' : label).toUpperCase(),
                textAlign: TextAlign.center,
                style: labelStyle(
                  color: done ? AppColors.accent : Colors.white,
                  size: 15,
                ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GUARDADO AUTOMÁTICO',
          textAlign: TextAlign.center,
          style: labelStyle(color: AppColors.faint, size: 12),
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final bool done;

  const StatusBadge({super.key, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.accent : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.5)),
      child: Text(
        done ? 'COMPLETADO' : 'PENDIENTE',
        style: labelStyle(
          color: color,
          size: 11,
        ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 2.4),
      ),
    );
  }
}

/// Cabecera de las pantallas Mañana y Noche.
class EntryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final int day;
  final int totalDays;

  const EntryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.day,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, color: AppColors.muted),
                const SizedBox(width: 16),
                Text('VOLVER', style: labelStyle()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: serif,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text('DÍA $day / $totalDays', style: labelStyle()),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '— $subtitle',
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 18,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(date.toUpperCase(), style: labelStyle(color: AppColors.faint)),
        const SizedBox(height: 40),
      ],
    );
  }
}

/// Cuadro de estadística: número grande con su etiqueta, y opcionalmente la
/// etiqueta arriba y una nota abajo ("RACHA · 0 · DÍAS SEGUIDOS").
class StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String? caption;
  final Color color;

  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label.toUpperCase(),
      textAlign: TextAlign.center,
      style: labelStyle(size: 12).copyWith(height: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
      child: Column(
        children: [
          if (caption != null) ...[labelText, const SizedBox(height: 8)],
          Text(
            value,
            style: TextStyle(
              fontFamily: serif,
              fontSize: 44,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          if (caption == null)
            labelText
          else
            Text(
              caption!.toUpperCase(),
              textAlign: TextAlign.center,
              style: labelStyle(
                color: AppColors.faint,
                size: 11,
              ).copyWith(letterSpacing: 1.6),
            ),
        ],
      ),
    );
  }
}

/// Rejilla de celdas con bordes finos, de [columns] columnas.
class StatGrid extends StatelessWidget {
  final List<Widget> cells;
  final int columns;

  const StatGrid({super.key, required this.cells, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += columns) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columns; j++)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: j % columns < columns - 1
                            ? const BorderSide(color: AppColors.line)
                            : BorderSide.none,
                        bottom: i + columns < cells.length
                            ? const BorderSide(color: AppColors.line)
                            : BorderSide.none,
                      ),
                    ),
                    child: j < cells.length ? cells[j] : null,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.line)),
      child: Column(children: rows),
    );
  }
}
