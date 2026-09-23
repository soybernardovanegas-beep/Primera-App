import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'contact_detail_screen.dart';
import 'contact_form_screen.dart';

/// Lista de todos los contactos con búsqueda y filtro por etapa.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _service = CrmService(Supabase.instance.client);
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  Stage? _stageFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = await _service.fetchContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _openContact(Contact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: contact.id)),
    );
    _load();
  }

  Future<void> _addContact() async {
    final created = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(builder: (_) => const ContactFormScreen()),
    );
    if (created != null) _load();
  }

  List<Contact> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    return _contacts.where((c) {
      if (_stageFilter != null && c.stage != _stageFilter) return false;
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.phone.contains(query) ||
          c.city.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar por nombre, teléfono o ciudad',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('Todos (${_contacts.length})'),
                    selected: _stageFilter == null,
                    onSelected: (_) => setState(() => _stageFilter = null),
                  ),
                ),
                for (final s in Stage.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      avatar: Icon(s.icon, size: 18, color: s.color),
                      label: Text(
                        '${s.label} (${_contacts.where((c) => c.stage == s).length})',
                      ),
                      selected: _stageFilter == s,
                      onSelected: (_) => setState(
                        () => _stageFilter = _stageFilter == s ? null : s,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        message: _contacts.isEmpty
                            ? 'Aún no tienes contactos.\nAgrega tu lista de prospectos con el botón "Nuevo".'
                            : 'Ningún contacto coincide con el filtro.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final c = visible[index];
                            final details = [
                              if (c.city.isNotEmpty) c.city,
                              c.interest.label,
                            ].join(' · ');
                            return ListTile(
                              onTap: () => _openContact(c),
                              leading: ContactAvatar(contact: c),
                              title: Text(c.name),
                              subtitle: Text(details),
                              trailing: StageChip(stage: c.stage, dense: true),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
