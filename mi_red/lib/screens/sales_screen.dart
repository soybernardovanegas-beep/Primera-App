import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/sale.dart';
import '../services/crm_service.dart';
import '../widgets/common.dart';

/// Ventas por mes con totales de monto y puntos.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _service = CrmService(Supabase.instance.client);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Sale> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final sales = await _service.fetchSales(
      start: _month,
      end: DateTime(_month.year, _month.month + 1, 0),
    );
    if (!mounted) return;
    setState(() {
      _sales = sales;
      _isLoading = false;
    });
  }

  void _shiftMonth(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    _load();
  }

  Future<void> _add() async {
    if (await showAddSaleSheet(context)) _load();
  }

  Future<void> _delete(Sale sale) async {
    await _service.deleteSale(sale.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _sales.fold<double>(0, (s, e) => s + e.amount);
    final points = _sales.fold<double>(0, (s, e) => s + e.points);
    final isCurrentMonth = _month.year == DateTime.now().year &&
        _month.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Venta'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Text(
                toBeginningOfSentenceCase(
                  DateFormat('MMMM y', 'es').format(_month),
                ),
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Total(
                        label: 'Total vendido',
                        value: currencyFormat.format(total),
                      ),
                    ),
                    Expanded(
                      child: _Total(
                        label: 'Puntos (PV)',
                        value: pointsFormat.format(points),
                      ),
                    ),
                    Expanded(
                      child: _Total(label: 'Pedidos', value: '${_sales.length}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'Sin ventas registradas este mes.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _sales.length,
                        itemBuilder: (context, index) {
                          final s = _sales[index];
                          return Dismissible(
                            key: ValueKey(s.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: theme.colorScheme.errorContainer,
                              child: const Icon(Icons.delete_outline),
                            ),
                            confirmDismiss: (_) => showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('¿Eliminar esta venta?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) => _delete(s),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.shopping_bag_outlined),
                              ),
                              title: Text(s.product),
                              subtitle: Text([
                                DateFormat('d MMM', 'es').format(s.saleDate),
                                s.contactName ?? 'Consumo propio',
                              ].join(' · ')),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(currencyFormat.format(s.amount)),
                                  if (s.points > 0)
                                    Text(
                                      '${pointsFormat.format(s.points)} PV',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

/// Muestra el formulario para registrar una venta. Si se pasa [contact], la
/// venta queda asignada a él; si no, se puede elegir de la lista. Devuelve
/// `true` si se guardó.
Future<bool> showAddSaleSheet(BuildContext context, {Contact? contact}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddSaleSheet(contact: contact),
  );
  return saved ?? false;
}

class _AddSaleSheet extends StatefulWidget {
  const _AddSaleSheet({this.contact});

  final Contact? contact;

  @override
  State<_AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<_AddSaleSheet> {
  final _service = CrmService(Supabase.instance.client);
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _amountController = TextEditingController();
  final _pointsController = TextEditingController();

  late String? _contactId = widget.contact?.id;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<Contact> _contacts = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.contact == null) _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _service.fetchContacts();
    if (mounted) setState(() => _contacts = contacts);
  }

  @override
  void dispose() {
    _productController.dispose();
    _amountController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  double _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _service.addSale(
        product: _productController.text.trim(),
        amount: _parse(_amountController.text),
        points: _parse(_pointsController.text),
        saleDate: _date,
        contactId: _contactId,
      );
      // Quien compra deja de ser prospecto: pasa a cliente (sin degradar a
      // quien ya es socio).
      final contact = widget.contact ??
          _contacts.where((c) => c.id == _contactId).firstOrNull;
      if (contact != null &&
          contact.stage != Stage.cliente &&
          contact.stage != Stage.socio) {
        await _service.setStage(contact.id, Stage.cliente);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la venta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.contact == null
                    ? 'Nueva venta'
                    : 'Venta a ${widget.contact!.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _productController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Producto(s) *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe el producto'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto *',
                        prefixText: r'$ ',
                      ),
                      validator: (v) => _parse(v ?? '') <= 0
                          ? 'Monto inválido'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pointsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Puntos (PV)'),
                    ),
                  ),
                ],
              ),
              if (widget.contact == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _contactId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Consumo propio / sin asignar'),
                    ),
                    for (final c in _contacts)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _contactId = v),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(DateFormat('EEEE d MMMM y', 'es').format(_date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(_date.year - 2),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('Guardar venta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
