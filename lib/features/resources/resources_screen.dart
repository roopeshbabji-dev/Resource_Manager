import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../models/models.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _search = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter resources',
            onSelected: (value) => setState(() => _category = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'All', child: Text('All resources')),
              PopupMenuItem(value: 'Utility', child: Text('Utilities')),
              PopupMenuItem(value: 'Household', child: Text('Household')),
              PopupMenuItem(value: 'Other', child: Text('Other')),
            ],
            icon: const Icon(Icons.filter_list_rounded),
          ),
          IconButton(
            tooltip: 'Add resource',
            onPressed: () => _push(context, const AddResourceScreen()),
            icon: const Icon(Icons.add_rounded),
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
                hintText: 'Search resources',
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
            child: FutureBuilder<List<ResourceModel>>(
              future: state.getResources(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ResourceMessage(
                    message: 'Resources could not be loaded.',
                    action: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final resources = snapshot.data!.where((resource) {
                  final matchesCategory =
                      _category == 'All' || resource.category == _category;
                  final query = _search.text.trim().toLowerCase();
                  return matchesCategory &&
                      (query.isEmpty ||
                          resource.name.toLowerCase().contains(query));
                }).toList();
                if (resources.isEmpty) {
                  final noRecords = snapshot.data!.isEmpty;
                  return _ResourceMessage(
                    message: noRecords
                        ? 'No resources yet. Add one to start tracking usage.'
                        : 'No resources match these filters.',
                    action: noRecords
                        ? () => _push(context, const AddResourceScreen())
                        : null,
                    actionLabel: 'Add resource',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: resources.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final resource = resources[index];
                    return FutureBuilder<List<ResourceUsage>>(
                      future: state.getResourceUsage(resource.id),
                      builder: (context, usageSnapshot) {
                        final today = DateTime.now();
                        final total =
                            (usageSnapshot.data ?? const <ResourceUsage>[])
                                .where(
                                  (usage) =>
                                      usage.date.year == today.year &&
                                      usage.date.month == today.month,
                                )
                                .fold(
                                  0.0,
                                  (sum, usage) => sum + usage.quantity,
                                );
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            child: Icon(_iconFor(resource.name)),
                          ),
                          title: Text(resource.name),
                          subtitle: Text(
                            '${total.toStringAsFixed(1)} ${resource.unit} this month · ${resource.category}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _push(
                            context,
                            ResourceDetailScreen(resource: resource),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Log usage',
        onPressed: () => _push(context, const AddResourceUsageScreen()),
        child: const Icon(Icons.add_chart_rounded),
      ),
    );
  }
}

class AddResourceScreen extends StatefulWidget {
  final ResourceModel? resource;

  const AddResourceScreen({super.key, this.resource});

  @override
  State<AddResourceScreen> createState() => _AddResourceScreenState();
}

class _AddResourceScreenState extends State<AddResourceScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _unit = TextEditingController();
  String _category = 'Utility';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final resource = widget.resource;
    if (resource != null) {
      _name.text = resource.name;
      _unit.text = resource.unit;
      _category = resource.category;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      final resource = ResourceModel(
        id: widget.resource?.id ?? const Uuid().v4(),
        userId: state.currentUser!.id,
        name: _name.text.trim(),
        category: _category,
        unit: _unit.text.trim(),
        iconName: widget.resource?.iconName ?? 'analytics',
        color: widget.resource?.color ?? '#438A76',
        createdAt:
            widget.resource?.createdAt ?? DateTime.now().toIso8601String(),
      );
      if (widget.resource == null) {
        await state.addResource(resource);
      } else {
        await state.updateResource(resource);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Creating resource failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resource could not be saved. Try again.'),
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
      title: Text(widget.resource == null ? 'Add resource' : 'Edit resource'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Resource name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a resource name.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const ['Utility', 'Household', 'Other']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? 'Other'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _unit,
            decoration: const InputDecoration(
              labelText: 'Unit',
              hintText: 'kWh, L, kg, GB, pieces',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a measurement unit.'
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.resource == null ? 'Save resource' : 'Save changes',
                  ),
          ),
        ],
      ),
    ),
  );
}

class AddResourceUsageScreen extends StatefulWidget {
  final ResourceModel? initialResource;

  const AddResourceUsageScreen({super.key, this.initialResource});

  @override
  State<AddResourceUsageScreen> createState() => _AddResourceUsageScreenState();
}

class _AddResourceUsageScreenState extends State<AddResourceUsageScreen> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  List<ResourceModel> _resources = const [];
  ResourceModel? _selected;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final resources = await context.read<AppState>().getResources();
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _selected =
            widget.initialResource ??
            (resources.isEmpty ? null : resources.first);
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Loading resources failed: $error\n$stackTrace');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _notes.dispose();
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
    if (!_form.currentState!.validate() || _selected == null) return;
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      await state.addResourceUsage(
        ResourceUsage(
          id: const Uuid().v4(),
          userId: state.currentUser!.id,
          resourceId: _selected!.id,
          quantity: double.parse(_quantity.text.trim()),
          unit: _selected!.unit,
          date: _date,
          cost: double.tryParse(_cost.text.trim()) ?? 0,
          notes: _notes.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Saving usage failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usage could not be saved. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Log usage')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _resources.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create a resource before logging usage.'),
            ),
          )
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<ResourceModel>(
                  initialValue: _selected,
                  decoration: const InputDecoration(labelText: 'Resource'),
                  items: _resources
                      .map(
                        (resource) => DropdownMenuItem(
                          value: resource,
                          child: Text(resource.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selected = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    suffixText: _selected?.unit,
                  ),
                  validator: (value) {
                    final number = double.tryParse(value?.trim() ?? '');
                    return number == null || !number.isFinite || number <= 0
                        ? 'Enter a quantity greater than zero.'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('d MMMM yyyy').format(_date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickDate,
                ),
                TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Recorded cost (optional)',
                    prefixText: '${context.read<AppState>().currency} ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final number = double.tryParse(value.trim());
                    return number == null || !number.isFinite || number < 0
                        ? 'Enter a non-negative cost.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save usage'),
                ),
              ],
            ),
          ),
  );
}

class ResourceDetailScreen extends StatelessWidget {
  final ResourceModel resource;

  const ResourceDetailScreen({super.key, required this.resource});

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
        title: Text(resource.name),
        actions: [
          IconButton(
            tooltip: 'Edit resource',
            onPressed: () =>
                _push(context, AddResourceScreen(resource: resource)),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Log usage',
            onPressed: () => _push(
              context,
              AddResourceUsageScreen(initialResource: resource),
            ),
            icon: const Icon(Icons.add_chart_rounded),
          ),
          IconButton(
            tooltip: 'Delete resource',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ResourceUsage>>(
        future: state.getResourceUsage(resource.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Usage history could not be loaded.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          final now = DateTime.now();
          final month = entries.where(
            (entry) =>
                entry.date.year == now.year && entry.date.month == now.month,
          );
          final year = entries.where((entry) => entry.date.year == now.year);
          final monthTotal = month.fold(
            0.0,
            (sum, item) => sum + item.quantity,
          );
          final yearTotal = year.fold(0.0, (sum, item) => sum + item.quantity);
          final recordedCost = entries.fold(
            0.0,
            (sum, item) => sum + item.cost,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ResourceMetric(label: 'Latest', value: _amount(entries, -1)),
                  _ResourceMetric(
                    label: 'Previous',
                    value: _amount(entries, -2),
                  ),
                  _ResourceMetric(
                    label: 'This month',
                    value: '${monthTotal.toStringAsFixed(1)} ${resource.unit}',
                  ),
                  _ResourceMetric(
                    label: 'This year',
                    value: '${yearTotal.toStringAsFixed(1)} ${resource.unit}',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Consumption history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 230,
                child: entries.isEmpty
                    ? const Center(
                        child: Text('Log a reading to build history.'),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: const FlTitlesData(
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                entries.length,
                                (index) => FlSpot(
                                  index.toDouble(),
                                  entries[index].quantity,
                                ),
                              ),
                              isCurved: true,
                              barWidth: 3,
                              color: Theme.of(context).colorScheme.primary,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 350),
                      ),
              ),
              const SizedBox(height: 8),
              _ResourceMetric(
                label: 'Recorded cost',
                value: money.format(recordedCost),
              ),
              const SizedBox(height: 18),
              Text('Readings', style: Theme.of(context).textTheme.titleMedium),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('There are no readings yet.'),
                )
              else
                ...entries.reversed.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${entry.quantity} ${entry.unit}'),
                    subtitle: Text(
                      '${DateFormat('d MMM yyyy').format(entry.date)}${entry.notes.isEmpty ? '' : ' · ${entry.notes}'}',
                    ),
                    trailing: Text(money.format(entry.cost)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _amount(List<ResourceUsage> entries, int offset) {
    final index = entries.length + offset;
    if (index < 0 || index >= entries.length) return 'No reading';
    final entry = entries[index];
    return '${entry.quantity.toStringAsFixed(1)} ${entry.unit}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this resource?'),
        content: const Text('Its usage history will also be deleted.'),
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
    await context.read<AppState>().deleteResource(resource.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _ResourceMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ResourceMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 164,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _ResourceMessage extends StatelessWidget {
  final String message;
  final VoidCallback? action;
  final String actionLabel;

  const _ResourceMessage({
    required this.message,
    this.action,
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
          if (action != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    ),
  );
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
}

IconData _iconFor(String name) => switch (name.toLowerCase()) {
  'electricity' => Icons.bolt_outlined,
  'water' => Icons.water_drop_outlined,
  'gas' || 'lpg' => Icons.local_fire_department_outlined,
  'internet' => Icons.wifi_rounded,
  _ => Icons.eco_outlined,
};
