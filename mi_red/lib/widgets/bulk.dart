import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../services/crm_service.dart';
import 'common.dart';

/// Barra inferior del modo "Seleccionar": acciones sobre varios contactos.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selected,
    required this.onDone,
    required this.onCancel,
  });

  final Set<String> selected;

  /// Se llama tras aplicar una acción, para recargar la lista.
  final VoidCallback onDone;
  final VoidCallback onCancel;

  Future<void> _changeStage(BuildContext context) async {
    final stage = await showDialog<Stage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Mover ${selected.length} a la etapa...'),
        children: [
          for (final s in Stage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Row(
                children: [
                  Icon(s.icon, color: s.color),
                  const SizedBox(width: 12),
                  Text(s.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (stage == null) return;
    await CrmService(Supabase.instance.client)
        .updateFieldsMany(selected.toList(), {'stage': stage.name});
    onDone();
  }

  Future<void> _setTemperature(Temperature t) async {
    await CrmService(Supabase.instance.client)
        .updateFieldsMany(selected.toList(), {'temperature': t.name});
    onDone();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: '¿Eliminar ${selected.length} contactos?',
      message: 'Se borran también sus recordatorios e historial.',
    );
    if (!ok) return;
    await CrmService(Supabase.instance.client).deleteContacts(selected.toList());
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = selected.isNotEmpty;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancelar',
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
              Expanded(child: Text('${selected.length} seleccionados')),
              IconButton(
                tooltip: 'Cambiar etapa',
                icon: const Icon(Icons.flag_outlined),
                onPressed: enabled ? () => _changeStage(context) : null,
              ),
              PopupMenuButton<Temperature>(
                tooltip: 'Temperatura',
                enabled: enabled,
                icon: const Icon(Icons.thermostat_outlined),
                onSelected: _setTemperature,
                itemBuilder: (_) => [
                  for (final t in Temperature.values)
                    PopupMenuItem(value: t, child: Text('${t.emoji} ${t.label}')),
                ],
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: enabled ? () => _delete(context) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
