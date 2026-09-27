import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/calendar_links.dart';
import '../services/crm_service.dart';
import '../services/import_export.dart';
import '../widgets/common.dart';
import 'guides_screen.dart';

const privacyPolicyAsset = 'assets/legal/politica_privacidad.md';

/// Texto completo de la política de privacidad (el mismo que se publica en
/// la web para Google Play).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de privacidad')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(privacyPolicyAsset),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [GuideContent(content: text)],
          );
        },
      ),
    );
  }
}

/// Privacidad y datos: qué guarda la app, exportar, borrar datos y
/// eliminar la cuenta.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _service = CrmService(Supabase.instance.client);
  bool _busy = false;

  Future<void> _export() async {
    final contacts = await _service.fetchContacts();
    await shareTextFile(
      fileName: 'contactos_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      mimeType: 'text/csv',
      content: exportContactsCsv(contacts),
    );
  }

  /// Pide escribir una palabra para confirmar una acción irreversible.
  Future<bool> _confirmTyping({
    required String title,
    required String message,
    required String word,
  }) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Text('Escribe $word para confirmar:'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setDialog(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: controller.text.trim().toUpperCase() == word
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Borrar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return ok ?? false;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnack(context, done);
    } catch (_) {
      if (mounted) {
        showSnack(context,
            'No se pudo completar. Revisa tu conexión e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteData() async {
    final ok = await _confirmTyping(
      title: 'Borrar mis datos de Mi Red',
      message: 'Se borrarán para siempre tus contactos, recordatorios, '
          'historial, ventas, perfil y guías editadas. Tu cuenta sigue '
          'activa. Te recomendamos exportar tus contactos antes.',
      word: 'BORRAR',
    );
    if (!ok) return;
    await _run(_service.deleteMyCrmData, 'Tus datos de Mi Red fueron borrados.');
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirmTyping(
      title: 'Eliminar mi cuenta',
      message: 'Se eliminará tu cuenta y todos sus datos de forma '
          'permanente. Si usas esta misma cuenta en otras apps conectadas '
          'al mismo proyecto (por ejemplo el lector EPUB o Bitácora), sus '
          'datos también se borrarán.',
      word: 'ELIMINAR',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.deleteMyAccount();
      // Al cerrarse la sesión, la app vuelve sola a la pantalla de inicio.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context,
          'No se pudo eliminar la cuenta. Revisa tu conexión e inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            const SectionCard(
              title: 'Qué guarda la app',
              icon: Icons.shield_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Tu correo y contraseña (cifrada) para iniciar sesión.'),
                  Text('• Los contactos, recordatorios, historial y ventas que tú registras.'),
                  Text('• Tu perfil: nombre, tu porqué y tu meta.'),
                  SizedBox(height: 8),
                  Text(
                    'Todo viaja cifrado y solo tú puedes ver tus datos. No hay '
                    'publicidad, no se venden ni se comparten datos, y la app no '
                    'lee los contactos, la ubicación ni las fotos del teléfono.',
                  ),
                ],
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.policy_outlined, color: gold),
                    title: const Text('Política de privacidad'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined, color: gold),
                    title: const Text('Exportar mis contactos'),
                    subtitle: const Text('Archivo CSV con todos tus contactos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _export,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('ZONA DE PELIGRO',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: error, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.delete_sweep_outlined, color: error),
                    title: const Text('Borrar mis datos de Mi Red'),
                    subtitle: const Text('Conservas tu cuenta'),
                    onTap: _deleteData,
                  ),
                  ListTile(
                    leading: Icon(Icons.person_remove_outlined, color: error),
                    title: Text('Eliminar mi cuenta',
                        style: TextStyle(color: error)),
                    subtitle: const Text('Borra tu cuenta y todos tus datos'),
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
