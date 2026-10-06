import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _InventoryFilterChip(
                  label: 'All items',
                  isSelected: _filter == 'All',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => setState(() => _filter = 'All'),
                ),
                _InventoryFilterChip(
                  label: 'Low stock',
                  isSelected: _filter == 'Low stock',
                  color: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _filter = 'Low stock'),
                ),
                _InventoryFilterChip(
                  label: 'Out of stock',
                  isSelected: _filter == 'Out of stock',
                  color: const Color(0xFFEF4444),
                  onTap: () => setState(() => _filter = 'Out of stock'),
                ),
                _InventoryFilterChip(
                  label: 'Expiring',
                  isSelected: _filter == 'Expiring',
                  color: const Color(0xFFF97316),
                  onTap: () => setState(() => _filter = 'Expiring'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<InventoryItem>>(
              future: state.getInventory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _InventoryMessage(
                    message: 'Inventory could not be loaded.',
                    onRetry: () => setState(() {}));
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
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final status = _stockStatus(item);
                    final expiry = _expiryStatus(item);
                    final catColor = AppTheme.categoryColor(item.category);
                    final statusColor = item.quantity <= 0
                        ? const Color(0xFFEF4444)
                        : item.quantity <= item.minimumStock
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppTheme.categoryBackground(item.category, isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_inventoryIcon(item.category), color: catColor, size: 22),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} · ${item.category}${item.expiryDate == null ? '' : '\nExpiry: $expiry'}',
                      ),
                      isThreeLine: item.expiryDate != null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
    final status = _stockStatus(item);
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: state.currency,
      decimalDigits: 2,
    );
    final catColor = AppTheme.categoryColor(item.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = item.quantity <= 0
        ? const Color(0xFFEF4444)
        : item.quantity <= item.minimumStock
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.categoryBackground(item.category, isDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: catColor.withValues(alpha: isDark ? 0.3 : 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_inventoryIcon(item.category), color: catColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            item.category.toUpperCase(),
                            style: TextStyle(
                              color: catColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${item.quantity} ${item.unit}',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
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

class _InventoryFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _InventoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : (isDark ? const Color(0xFF162930) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color
                    : (isDark ? const Color(0xFF1E353E) : const Color(0xFFE2EBE6)),
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
