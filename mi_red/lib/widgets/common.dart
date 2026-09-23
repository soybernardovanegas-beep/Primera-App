import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contact.dart';
import '../models/reminder.dart';

// Pesos colombianos sin decimales: "$ 525.000". Cambia el patrón si usas
// otra moneda.
final currencyFormat = NumberFormat(r'$ #,##0', 'es');
final pointsFormat = NumberFormat.decimalPattern('es');

const gold = Color(0xFFC9A45C);

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.radius = 20});

  final Contact contact;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = contact.category?.color ?? contact.stage.color;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      foregroundColor: color,
      child: Text(
        contact.initials,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
  }
}

class StageChip extends StatelessWidget {
  const StageChip({super.key, required this.stage, this.dense = false});

  final Stage stage;
  final bool dense;

  @override
  Widget build(BuildContext context) =>
      Pill(label: stage.label, color: stage.color, dense: dense);
}

/// Etiqueta redondeada pequeña (Ref: Nora, Origen: Cartago, ❄️ Frío...).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.color,
    this.dense = true,
    this.onTap,
  });

  final String label;
  final Color? color;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? gold;
    return Material(
      color: c.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 3 : 6,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: dense ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Potencial 🐬 · 12 pts" o "Sin calificar".
class CategoryLabel extends StatelessWidget {
  const CategoryLabel({super.key, required this.contact, this.style});

  final Contact contact;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final category = contact.category;
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    if (category == null) {
      return Text(
        'Sin calificar',
        style: base?.copyWith(color: Theme.of(context).colorScheme.outline),
      );
    }
    return Text(
      '${category.label} ${category.emoji} · ${contact.score} pts',
      style: base?.copyWith(color: category.color),
    );
  }
}

/// Campana del recordatorio: roja si está vencido, dorada si hay uno
/// programado y gris si no hay ninguno.
class ReminderBell extends StatelessWidget {
  const ReminderBell({super.key, required this.reminder, this.onPressed});

  final Reminder? reminder;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final Color color;
    final IconData icon;
    if (r == null) {
      color = Theme.of(context).colorScheme.outline;
      icon = Icons.notifications_none;
    } else if (r.isOverdue(DateTime.now())) {
      color = Theme.of(context).colorScheme.error;
      icon = Icons.notifications_active_outlined;
    } else {
      color = gold;
      icon = Icons.notifications_outlined;
    }
    return IconButton(
      tooltip: r == null
          ? 'Agregar recordatorio'
          : DateFormat('d MMM, HH:mm', 'es').format(r.dueAt),
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );
  }
}

/// Tarjeta de sección con título e ícono, como en la ficha del contacto.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.subtitle,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: gold, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(title!, style: theme.textTheme.titleMedium),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Abre el marcador del teléfono con el número del contacto.
Future<void> callContact(BuildContext context, Contact contact) =>
    launchExternal(context, Uri(scheme: 'tel', path: digitsOnly(contact.phone)));

/// Abre un chat de WhatsApp con el contacto, opcionalmente con un mensaje
/// ya escrito. A números locales se les agrega la clave de Colombia (57).
Future<void> whatsappContact(
  BuildContext context,
  Contact contact, {
  String? text,
}) =>
    launchExternal(
      context,
      Uri.https('wa.me', '/${whatsappNumber(contact.phone)}', {
        if (text != null && text.isNotEmpty) 'text': text,
      }),
    );

Future<void> launchExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la aplicación.')),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Pide confirmación antes de una acción destructiva.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String action = 'Eliminar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Estado vacío con ícono y mensaje centrados.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Título grande de pantalla con subtítulo, como "Proceso de Negocios".
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
