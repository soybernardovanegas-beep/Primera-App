import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contact.dart';

// Cambia el símbolo si tu moneda no usa '$'.
final currencyFormat =
    NumberFormat.currency(locale: 'es', symbol: r'$', decimalDigits: 2);
final pointsFormat = NumberFormat.decimalPattern('es');

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.radius = 20});

  final Contact contact;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: contact.stage.color.withValues(alpha: 0.18),
      foregroundColor: contact.stage.color,
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
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: stage.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stage.label,
        style: TextStyle(
          color: stage.color,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Abre el marcador del teléfono con el número del contacto.
Future<void> callContact(BuildContext context, Contact contact) =>
    _launch(context, Uri(scheme: 'tel', path: digitsOnly(contact.phone)));

/// Abre un chat de WhatsApp con el contacto. El número debe incluir la
/// clave de país (p. ej. 52 para México) para que wa.me lo reconozca.
Future<void> whatsappContact(BuildContext context, Contact contact) => _launch(
      context,
      Uri.parse('https://wa.me/${digitsOnly(contact.phone)}'),
    );

Future<void> _launch(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la aplicación.')),
    );
  }
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
