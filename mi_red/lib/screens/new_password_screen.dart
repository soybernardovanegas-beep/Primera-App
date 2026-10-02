import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_messages.dart';
import '../widgets/common.dart';

/// Elegir una contraseña nueva: tras tocar el enlace de recuperación del
/// correo, o desde Más → Cambiar contraseña.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, this.onDone, this.fromRecovery = false});

  /// Se llama al guardar (o al cancelar la recuperación).
  final VoidCallback? onDone;
  final bool fromRecovery;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      showSnack(context, 'Contraseña actualizada ✅');
      _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = authErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
        automaticallyImplyLeading: !widget.fromRecovery,
        actions: [
          if (widget.fromRecovery)
            TextButton(onPressed: _finish, child: const Text('Ahora no')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (email.isNotEmpty)
              Text('Cuenta: $email',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña nueva',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Mínimo 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              decoration:
                  const InputDecoration(labelText: 'Repite la contraseña'),
              validator: (v) => v != _passwordController.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Guardar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}
