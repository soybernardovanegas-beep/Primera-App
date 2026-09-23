import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';

/// Tu nombre, tu porqué (se inserta en recordatorios y guiones) y tu meta
/// de contactos ideales.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = CrmService(Supabase.instance.client);
  late final _nameController =
      TextEditingController(text: widget.profile.displayName);
  late final _whyController = TextEditingController(text: widget.profile.myWhy);
  late int _goal = widget.profile.idealGoal;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveProfile(Profile(
        displayName: _nameController.text.trim(),
        myWhy: _whyController.text.trim(),
        idealGoal: _goal,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'No se pudo guardar el perfil.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Tu nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Mi Porqué',
            icon: Icons.favorite_border,
            subtitle: '¿Por qué haces este negocio? Se inserta en tus '
                'recordatorios y en el guion de llamada de negocio.',
            child: TextField(
              controller: _whyController,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ej: Quiero pasar más tiempo con mis hijos y '
                    'darle una mejor vida a mis padres.',
              ),
            ),
          ),
          SectionCard(
            title: 'Meta de contactos ideales',
            icon: Icons.track_changes,
            subtitle: '¿Cuántos contactos Ideales 🦈 quieres tener en tu lista?',
            child: Row(
              children: [
                IconButton.outlined(
                  onPressed: _goal > 1 ? () => setState(() => _goal--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '$_goal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => _goal++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
