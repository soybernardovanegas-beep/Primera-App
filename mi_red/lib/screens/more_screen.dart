import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/profile.dart';
import '../services/calendar_links.dart';
import '../services/crm_service.dart';
import '../services/import_export.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import 'contact_detail_screen.dart';
import 'guides_screen.dart';
import 'import_screen.dart';
import 'profile_screen.dart';
import 'sales_screen.dart';
import 'team_screen.dart';

/// Más: perfil, equipo, ventas, guías, importar/exportar y cuenta.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _service = CrmService(Supabase.instance.client);
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.fetchProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) setState(() => _profile = const Profile());
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _export() async {
    final contacts = await _service.fetchContacts();
    await shareTextFile(
      fileName: 'contactos_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      mimeType: 'text/csv',
      content: exportContactsCsv(contacts),
    );
  }

  Future<void> _signOut() async {
    final ok = await confirm(context,
        title: '¿Cerrar sesión?', action: 'Cerrar sesión');
    if (!ok) return;
    await NotificationService.instance.clear();
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    Widget item(IconData icon, String title, VoidCallback onTap,
            {String? subtitle}) =>
        ListTile(
          leading: Icon(icon, color: gold),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const ScreenHeader(title: 'Más'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: gold.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: gold, size: 32),
              ),
              title: Text(
                (profile?.displayName.isNotEmpty ?? false)
                    ? profile!.displayName
                    : 'Mi perfil',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                (profile?.myWhy.isNotEmpty ?? false)
                    ? '❤️ ${profile!.myWhy}'
                    : 'Escribe tu porqué y tu meta de contactos ideales',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _push(ProfileScreen(profile: profile ?? const Profile())),
            ),
          ),
        ),
        const _SectionLabel('Tu negocio'),
        item(Icons.account_tree_outlined, 'Mi equipo', () => _push(const TeamScreen()),
            subtitle: 'Árbol de socios y patrocinio'),
        item(Icons.point_of_sale_outlined, 'Ventas', () => _push(const SalesScreen()),
            subtitle: 'Pedidos, montos y puntos por mes'),
        item(Icons.menu_book_outlined, 'Guías y guiones',
            () => _push(const GuidesListScreen()),
            subtitle: 'Objeciones, prospección, redes, seguimiento'),
        item(Icons.pause_circle_outline, 'Contactar después',
            () => _push(const _PausedScreen()),
            subtitle: 'Contactos pausados y descartados'),
        const _SectionLabel('Datos'),
        item(Icons.upload_file_outlined, 'Importar contactos',
            () => _push(const ImportScreen()),
            subtitle: 'Excel, CSV, contactos del teléfono (.vcf)'),
        item(Icons.download_outlined, 'Exportar contactos', _export,
            subtitle: 'Archivo CSV para Excel o respaldo'),
        const _SectionLabel('Cuenta'),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión'),
          subtitle: Text(email),
          onTap: _signOut,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

/// Contactos que no están en el proceso: pausados ("Contactar después") y
/// descartados ("No interesado").
class _PausedScreen extends StatefulWidget {
  const _PausedScreen();

  @override
  State<_PausedScreen> createState() => _PausedScreenState();
}

class _PausedScreenState extends State<_PausedScreen> {
  final _service = CrmService(Supabase.instance.client);
  List<Contact>? _contacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final all = await _service.fetchContacts();
    if (!mounted) return;
    setState(() => _contacts = all.where((c) => !c.isActive(now)).toList()
      ..sort((a, b) => (a.snoozedUntil ?? DateTime(9999))
          .compareTo(b.snoozedUntil ?? DateTime(9999))));
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Contactar después')),
      body: contacts == null
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? const EmptyState(
                  icon: Icons.pause_circle_outline,
                  message: 'No tienes contactos pausados ni descartados.',
                )
              : ListView(
                  children: [
                    for (final c in contacts)
                      ListTile(
                        leading: ContactAvatar(contact: c),
                        title: Text(c.name),
                        subtitle: Text(c.isSnoozed(now)
                            ? '⏸ Vuelve el ${DateFormat('d MMM y', 'es').format(c.snoozedUntil!)}'
                            : c.stage.label),
                        trailing: TextButton(
                          onPressed: () async {
                            if (c.isSnoozed(now)) {
                              await _service.snooze(c.id, null);
                            }
                            if (c.stage == Stage.descartado) {
                              await _service.setStage(c.id, Stage.nuevo);
                            }
                            _load();
                          },
                          child: const Text('Reactivar'),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ContactDetailScreen(contactId: c.id)));
                          _load();
                        },
                      ),
                  ],
                ),
    );
  }
}
