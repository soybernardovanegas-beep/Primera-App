import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';
import 'contact_detail_screen.dart';

/// Árbol de tu equipo: socios de primera línea y, debajo de cada uno, a
/// quiénes han patrocinado.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _service = CrmService(Supabase.instance.client);

  List<Contact> _partners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _service.fetchContacts();
    if (!mounted) return;
    setState(() {
      _partners = all.where((c) => c.stage == Stage.socio).toList();
      _isLoading = false;
    });
  }

  Future<void> _open(Contact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: contact.id)),
    );
    _load();
  }

  List<Contact> _childrenOf(String id) =>
      _partners.where((p) => p.sponsorId == id).toList();

  int _downlineSize(String id, Set<String> visited) {
    var total = 0;
    for (final child in _childrenOf(id)) {
      if (!visited.add(child.id)) continue;
      total += 1 + _downlineSize(child.id, visited);
    }
    return total;
  }

  Widget _buildNode(Contact contact, Set<String> path) {
    final children =
        _childrenOf(contact.id).where((c) => !path.contains(c.id)).toList();
    final size = _downlineSize(contact.id, {contact.id});
    final subtitle = Text(
      size == 0 ? 'Sin equipo aún' : '$size en su equipo',
    );
    if (children.isEmpty) {
      return ListTile(
        leading: ContactAvatar(contact: contact),
        title: Text(contact.name),
        subtitle: subtitle,
        onTap: () => _open(contact),
      );
    }
    return ExpansionTile(
      leading: ContactAvatar(contact: contact),
      title: GestureDetector(
        onTap: () => _open(contact),
        child: Text(contact.name),
      ),
      subtitle: subtitle,
      childrenPadding: const EdgeInsets.only(left: 24),
      children: [
        for (final child in children)
          _buildNode(child, {...path, contact.id}),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = _partners.map((p) => p.id).toSet();
    // Primera línea: socios sin patrocinador, o cuyo patrocinador ya no es
    // socio (así nadie queda fuera del árbol).
    final frontline = _partners
        .where((p) => p.sponsorId == null || !ids.contains(p.sponsorId))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi equipo')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _partners.isEmpty
              ? const EmptyState(
                  icon: Icons.account_tree_outlined,
                  message:
                      'Cuando un contacto pase a la etapa "Socio" aparecerá aquí.\n'
                      'Indica quién lo patrocinó para armar el árbol de tu red.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TeamStat(
                                label: 'Primera línea',
                                value: frontline.length,
                              ),
                            ),
                            Expanded(
                              child: _TeamStat(
                                label: 'Total en tu red',
                                value: _partners.length,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final p in frontline) _buildNode(p, {}),
                    ],
                  ),
                ),
    );
  }
}

class _TeamStat extends StatelessWidget {
  const _TeamStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
