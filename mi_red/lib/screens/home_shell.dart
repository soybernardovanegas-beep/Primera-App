import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'contact_form_screen.dart';
import 'crm_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'process_screen.dart';

/// Navegación principal: Inicio · CRM · (+) · Proceso · Más. Cada pestaña se
/// reconstruye al seleccionarla, así siempre muestra datos recientes.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _refresh = 0;

  void _goTo(int index) => setState(() => _index = index);

  Future<void> _newContact() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContactFormScreen()),
    );
    setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('$_index-$_refresh');
    final body = switch (_index) {
      0 => HomeScreen(key: key, onOpenTab: _goTo),
      1 => CrmScreen(key: key),
      2 => ProcessScreen(key: key),
      _ => MoreScreen(key: key),
    };
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          tooltip: 'Nuevo contacto',
          shape: const CircleBorder(),
          backgroundColor: gold,
          foregroundColor: Colors.black87,
          onPressed: _newContact,
          child: const Icon(Icons.add, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          children: [
            _NavItem(Icons.grid_view_outlined, 'Inicio', 0, _index, _goTo),
            _NavItem(Icons.people_outline, 'CRM', 1, _index, _goTo),
            const SizedBox(width: 80),
            _NavItem(Icons.calendar_month_outlined, 'Proceso', 2, _index, _goTo),
            _NavItem(Icons.more_horiz, 'Más', 3, _index, _goTo),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.icon, this.label, this.index, this.current, this.onTap);

  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final color = selected ? gold : Theme.of(context).colorScheme.outline;
    return Expanded(
      child: InkResponse(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
