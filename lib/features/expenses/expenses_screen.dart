import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _expenseCategories = [
  'Electricity',
  'Water',
  'Gas',
  'Groceries',
  'Internet',
  'Fuel',
  'Maintenance',
  'Rent',
  'Other',
];

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  String _period = 'All dates';
  String? _category;
  String _sort = 'Newest';
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_ExpenseFilter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseFilterSheet(
        period: _period,
        category: _category,
        sort: _sort,
        range: _customRange,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _period = result.period;
        _category = result.category;
        _sort = result.sort;
        _customRange = result.range;
      });
    }
  }

  Future<void> _openEditor([Expense? expense]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseEditorScreen(expense: expense),
      ),
    );
  }

  List<Expense> _filtered(List<Expense> source) {
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final result = source.where((expense) {
      final matchesText =
          query.isEmpty ||
          expense.title.toLowerCase().contains(query) ||
          expense.category.toLowerCase().contains(query) ||
          expense.notes.toLowerCase().contains(query);
      final matchesCategory =
          _category == null || expense.category == _category;
      final date = expense.date;
      final matchesPeriod = switch (_period) {
        'This week' => !date.isBefore(monday),
        'This month' => date.year == now.year && date.month == now.month,
        'Custom dates' =>
          _customRange == null ||
              (!date.isBefore(_customRange!.start) &&
                  !date.isAfter(
                    DateTime(
                      _customRange!.end.year,
                      _customRange!.end.month,
                      _customRange!.end.day,
                      23,
                      59,
                      59,
                    ),
                  )),
        _ => true,
      };
      return matchesText && matchesCategory && matchesPeriod;
    }).toList();

    result.sort(
      (a, b) => switch (_sort) {
        'Oldest' => a.date.compareTo(b.date),
        'Amount: high to low' => b.amount.compareTo(a.amount),
        'Amount: low to high' => a.amount.compareTo(b.amount),
        _ => b.date.compareTo(a.date),
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: state.currency,
      decimalDigits: 2,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Filter and sort',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Add expense',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
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
                hintText: 'Search expenses',
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
                _CategoryChip(
                  label: 'All',
                  isSelected: _category == null,
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => setState(() => _category = null),
                ),
                ..._expenseCategories.map((cat) => _CategoryChip(
                  label: cat,
                  isSelected: _category == cat,
                  color: AppTheme.categoryColor(cat),
                  onTap: () => setState(() => _category = _category == cat ? null : cat),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Expense>>(
              future: state.getExpenses(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _FeatureError(onRetry: () => setState(() {}));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final expenses = _filtered(snapshot.data!);
                if (expenses.isEmpty) {
                  return _EmptyExpenses(
                    hasRecords: snapshot.data!.isNotEmpty,
                    onAdd: () => _openEditor(),
                  );
                }
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final catColor = AppTheme.categoryColor(expense.category);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppTheme.categoryBackground(expense.category, isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_categoryIcon(expense.category), color: catColor, size: 22),
                      ),
                      title: Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${expense.category} · ${DateFormat('d MMM yyyy').format(expense.date)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money.format(expense.amount),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (expense.recurring)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Recurring',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ExpenseDetailScreen(expense: expense),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Add expense',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class ExpenseEditorScreen extends StatefulWidget {
  final Expense? expense;

  const ExpenseEditorScreen({super.key, this.expense});

  @override
  State<ExpenseEditorScreen> createState() => _ExpenseEditorScreenState();
}

class _ExpenseEditorScreenState extends State<ExpenseEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late final TextEditingController _customCategory;
  late final TextEditingController _paymentMethod;
  late DateTime _date;
  late String _category;
  late bool _recurring;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _title = TextEditingController(text: expense?.title ?? '');
    _amount = TextEditingController(text: expense?.amount.toString() ?? '');
    _notes = TextEditingController(text: expense?.notes ?? '');
    _paymentMethod = TextEditingController(text: expense?.paymentMethod ?? '');
    _customCategory = TextEditingController();
    _category = expense == null
        ? 'Groceries'
        : _expenseCategories.contains(expense.category)
        ? expense.category
        : 'Other';
    if (expense != null && !_expenseCategories.contains(expense.category)) {
      _customCategory.text = expense.category;
    }
    _date = expense?.date ?? DateTime.now();
    _recurring = expense?.recurring ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    _customCategory.dispose();
    _paymentMethod.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      final expense = Expense(
        id: widget.expense?.id ?? const Uuid().v4(),
        userId: state.currentUser!.id,
        title: _title.text.trim(),
        amount: double.parse(_amount.text.trim()),
        category: _category == 'Other'
            ? _customCategory.text.trim()
            : _category,
        date: _date,
        paymentMethod: _paymentMethod.text.trim().isEmpty
            ? 'Not specified'
            : _paymentMethod.text.trim(),
        notes: _notes.text.trim(),
        recurring: _recurring,
      );
      if (widget.expense == null) {
        await state.addExpense(expense);
      } else {
        await state.updateExpense(expense);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Saving expense failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense could not be saved. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.expense == null ? 'Add expense' : 'Edit expense'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an expense title.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${context.read<AppState>().currency} ',
            ),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              if (amount == null || !amount.isFinite || amount <= 0) {
                return 'Enter an amount greater than zero.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _expenseCategories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? 'Other'),
          ),
          if (_category == 'Other') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customCategory,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Custom category'),
              validator: (_) =>
                  _category == 'Other' && _customCategory.text.trim().isEmpty
                  ? 'Enter a category.'
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(DateFormat('d MMMM yyyy').format(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDate,
          ),
          TextFormField(
            controller: _paymentMethod,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Payment method'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring expense'),
            value: _recurring,
            onChanged: (value) => setState(() => _recurring = value),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save expense'),
          ),
        ],
      ),
    ),
  );
}

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
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
    await context.read<AppState>().deleteExpense(expense.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: state.currency,
      decimalDigits: 2,
    );
    final catColor = AppTheme.categoryColor(expense.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.categoryBackground(expense.category, isDark),
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
                          Icon(_categoryIcon(expense.category), color: catColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            expense.category.toUpperCase(),
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
                    if (expense.recurring)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Recurring',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  money.format(expense.amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _DetailLine(label: 'Title', value: expense.title),
          _DetailLine(label: 'Category', value: expense.category),
          _DetailLine(
            label: 'Date',
            value: DateFormat('d MMMM yyyy').format(expense.date),
          ),
          _DetailLine(label: 'Payment method', value: expense.paymentMethod),
          _DetailLine(
            label: 'Notes',
            value: expense.notes.isEmpty ? 'None' : expense.notes,
          ),
          _DetailLine(
            label: 'Recurring',
            value: expense.recurring ? 'Yes' : 'No',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ExpenseEditorScreen(expense: expense),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit expense'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete expense'),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _ExpenseFilter {
  final String period;
  final String? category;
  final String sort;
  final DateTimeRange? range;

  const _ExpenseFilter(this.period, this.category, this.sort, this.range);
}

class _ExpenseFilterSheet extends StatefulWidget {
  final String period;
  final String? category;
  final String sort;
  final DateTimeRange? range;

  const _ExpenseFilterSheet({
    required this.period,
    required this.category,
    required this.sort,
    required this.range,
  });

  @override
  State<_ExpenseFilterSheet> createState() => _ExpenseFilterSheetState();
}

class _ExpenseFilterSheetState extends State<_ExpenseFilterSheet> {
  late String _period = widget.period;
  late String? _category = widget.category;
  late String _sort = widget.sort;
  late DateTimeRange? _range = widget.range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _period = 'Custom dates';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter and sort',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Date range'),
            items:
                const ['All dates', 'This week', 'This month', 'Custom dates']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) async {
              if (value == 'Custom dates') {
                await _pickRange();
              } else if (value != null) {
                setState(() => _period = value);
              }
            },
          ),
          if (_period == 'Custom dates')
            TextButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                _range == null
                    ? 'Choose dates'
                    : '${DateFormat('d MMM').format(_range!.start)} - ${DateFormat('d MMM').format(_range!.end)}',
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All categories'),
              ),
              ..._expenseCategories.map(
                (value) =>
                    DropdownMenuItem<String?>(value: value, child: Text(value)),
              ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'Sort by'),
            items:
                const [
                      'Newest',
                      'Oldest',
                      'Amount: high to low',
                      'Amount: low to high',
                    ]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _sort = value ?? 'Newest'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _period = 'All dates';
                  _category = null;
                  _sort = 'Newest';
                  _range = null;
                }),
                child: const Text('Reset'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _ExpenseFilter(_period, _category, _sort, _range),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _EmptyExpenses extends StatelessWidget {
  final bool hasRecords;
  final VoidCallback onAdd;

  const _EmptyExpenses({required this.hasRecords, required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasRecords ? Icons.search_off_rounded : Icons.receipt_long_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            hasRecords ? 'No matching expenses' : 'No expenses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasRecords
                ? 'Try a different search or filter.'
                : 'Add an expense to start tracking household spending.',
          ),
          if (!hasRecords) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add expense'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _FeatureError extends StatelessWidget {
  final VoidCallback onRetry;

  const _FeatureError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Expenses could not be loaded.'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
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

IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
  'electricity' => Icons.bolt_outlined,
  'water' => Icons.water_drop_outlined,
  'gas' => Icons.local_fire_department_outlined,
  'groceries' => Icons.shopping_basket_outlined,
  'fuel' => Icons.local_gas_station_outlined,
  'internet' => Icons.wifi_rounded,
  _ => Icons.receipt_long_outlined,
};
