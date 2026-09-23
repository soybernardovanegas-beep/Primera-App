import 'package:flutter/material.dart';

import 'contacts_screen.dart';
import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'team_screen.dart';

/// Navegación principal con las cuatro secciones del CRM. Cada pestaña se
/// reconstruye al seleccionarla, así siempre muestra datos recientes.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => DashboardScreen(onOpenTab: _goTo),
      1 => const ContactsScreen(),
      2 => const TeamScreen(),
      _ => const SalesScreen(),
    };
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contactos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Equipo',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Ventas',
          ),
        ],
      ),
    );
  }
}
