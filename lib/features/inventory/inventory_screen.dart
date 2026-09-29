import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../models/models.dart';

const _inventoryCategories = [
  'Groceries',
  'Cleaning',
  'Kitchen',
  'Bathroom',
  'Electronics',
  'Maintenance',
  'Other',
];

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InventoryItem> _filterItems(List<InventoryItem> items) {
    final query = _search.text.trim().toLowerCase();
    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query);
      final status = _stockStatus(item);
      final matchesFilter = switch (_filter) {
        'Low stock' => status == 'Low stock',
        'Out of stock' => status == 'Out of stock',
        'Expiring' =>
          _expiryStatus(item) == 'Expiring soon' ||
              _expiryStatus(item) == 'Expired',
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter inventory',
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'All', child: Text('All items')),
              PopupMenuItem(value: 'Low stock', child: Text('Low stock')),
              PopupMenuItem(value: 'Out of stock', child: Text('Out of stock')),
              PopupMenuItem(
                value: 'Expiring',
                child: Text('Expired or expiring'),
              ),
            ],
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search inventory',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<InventoryItem>>(
              future: state.getInventory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _InventoryMessage(
                    message: 'Inventory could not be loaded.',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _filterItems(snapshot.data!);
                if (items.isEmpty) {
                  final noItems = snapshot.data!.isEmpty;
                  return _InventoryMessage(
                    message: noItems
                        ? 'No household items tracked yet.'
                        : 'No items match this search or filter.',
                    onRetry: noItems ? () => _openEditor(context) : null,
                    actionLabel: 'Add item',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final status = _stockStatus(item);
                    final expiry = _expiryStatus(item);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        child: Icon(_inventoryIcon(item.category)),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} · ${item.category}\n$status${item.expiryDate == null ? '' : ' · $expiry'}',
                      ),
                      isThreeLine: item.expiryDate != null,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openDetail(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add inventory item',
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _openEditor(BuildContext context, [InventoryItem? item]) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InventoryEditorScreen(item: item),
      ),
    );
  }

  void _openDetail(BuildContext context, InventoryItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InventoryDetailScreen(item: item),
      ),
    );
  }
}

class InventoryEditorScreen extends StatefulWidget {
  final InventoryItem? item;

  const InventoryEditorScreen({super.key, this.item});

  @override
  State<InventoryEditorScreen> createState() => _InventoryEditorScreenState();
}

class _InventoryEditorScreenState extends State<InventoryEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _minimum;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  late String _category;
  late DateTime _purchaseDate;
  DateTime? _expiryDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _quantity = TextEditingController(text: item?.quantity.toString() ?? '');
    _unit = TextEditingController(text: item?.unit ?? 'pieces');
    _minimum = TextEditingController(
      text: item?.minimumStock.toString() ?? '0',
    );
    _price = TextEditingController(text: item?.price.toString() ?? '0');
    _notes = TextEditingController(text: item?.notes ?? '');
    _category = item == null || _inventoryCategories.contains(item.category)
        ? item?.category ?? 'Groceries'
        : 'Other';
    _purchaseDate = item?.purchaseDate ?? DateTime.now();
    _expiryDate = item?.expiryDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _minimum.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _datePicker(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_expiryDate != null && _expiryDate!.isBefore(_purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry date must be after purchase date.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      final item = InventoryItem(
        id: widget.item?.id ?? const Uuid().v4(),
        userId: state.currentUser!.id,
        name: _name.text.trim(),
        category: _category,
        quantity: double.parse(_quantity.text.trim()),
        unit: _unit.text.trim(),
        minimumStock: double.parse(_minimum.text.trim()),
        price: double.parse(_price.text.trim()),
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        notes: _notes.text.trim(),
      );
      if (widget.item == null) {
        await state.addInventoryItem(item);
      } else {
        await state.updateInventoryItem(item);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Saving inventory item failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item could not be saved. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nonNegative(String? value, String label) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || !number.isFinite || number < 0
        ? 'Enter a valid $label (0 or more).'
        : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.item == null ? 'Add item' : 'Edit item')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Item name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an item name.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _inventoryCategories
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? 'Other'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) => _nonNegative(value, 'quantity'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a unit.'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _minimum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Minimum stock'),
            validator: (value) => _nonNegative(value, 'minimum stock'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Purchase price',
              prefixText: '${context.read<AppState>().currency} ',
            ),
            validator: (value) => _nonNegative(value, 'price'),
          ),
          const SizedBox(height: 6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Purchase date'),
            subtitle: Text(DateFormat('d MMM yyyy').format(_purchaseDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final date = await _datePicker(_purchaseDate);
              if (date != null) setState(() => _purchaseDate = date);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expiry date'),
            subtitle: Text(
              _expiryDate == null
                  ? 'Not set'
                  : DateFormat('d MMM yyyy').format(_expiryDate!),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_expiryDate != null)
                  IconButton(
                    tooltip: 'Clear expiry date',
                    onPressed: () => setState(() => _expiryDate = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                const Icon(Icons.calendar_month_outlined),
              ],
            ),
            onTap: () async {
              final date = await _datePicker(_expiryDate ?? _purchaseDate);
              if (date != null) setState(() => _expiryDate = date);
            },
          ),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save item'),
          ),
        ],
      ),
    ),
  );
}

class InventoryDetailScreen extends StatelessWidget {
  final InventoryItem item;

  const InventoryDetailScreen({super.key, required this.item});

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppState>().deleteInventoryItem(item.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final expiry = _expiryStatus(item);
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: state.currency,
      decimalDigits: 2,
    );
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${item.quantity} ${item.unit}',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(_stockStatus(item)),
          const SizedBox(height: 18),
          _InventoryDetailLine(label: 'Category', value: item.category),
          _InventoryDetailLine(
            label: 'Minimum stock',
            value: '${item.minimumStock} ${item.unit}',
          ),
          _InventoryDetailLine(
            label: 'Purchase price',
            value: money.format(item.price),
          ),
          _InventoryDetailLine(
            label: 'Purchased',
            value: DateFormat('d MMM yyyy').format(item.purchaseDate),
          ),
          _InventoryDetailLine(label: 'Expiry status', value: expiry),
          _InventoryDetailLine(
            label: 'Expiry date',
            value: item.expiryDate == null
                ? 'Not set'
                : DateFormat('d MMM yyyy').format(item.expiryDate!),
          ),
          _InventoryDetailLine(
            label: 'Notes',
            value: item.notes.isEmpty ? 'None' : item.notes,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => InventoryEditorScreen(item: item),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Update item or quantity'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete item'),
          ),
        ],
      ),
    );
  }
}

class _InventoryDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _InventoryDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _InventoryMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String actionLabel;

  const _InventoryMessage({
    required this.message,
    this.onRetry,
    this.actionLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    ),
  );
}

String _stockStatus(InventoryItem item) => item.quantity <= 0
    ? 'Out of stock'
    : item.quantity <= item.minimumStock
    ? 'Low stock'
    : 'Stock good';

String _expiryStatus(InventoryItem item) {
  final expiry = item.expiryDate;
  if (expiry == null) return 'No expiry date';
  final today = DateTime.now();
  final date = DateTime(expiry.year, expiry.month, expiry.day);
  final current = DateTime(today.year, today.month, today.day);
  if (date.isBefore(current)) return 'Expired';
  if (date.difference(current).inDays <= 30) return 'Expiring soon';
  return 'Valid';
}

IconData _inventoryIcon(String category) => switch (category.toLowerCase()) {
  'groceries' => Icons.shopping_basket_outlined,
  'cleaning' => Icons.cleaning_services_outlined,
  'kitchen' => Icons.kitchen,
  'bathroom' => Icons.shower_outlined,
  'electronics' => Icons.devices_outlined,
  'maintenance' => Icons.handyman_outlined,
  _ => Icons.inventory_2_outlined,
};
