import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../models/models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'Monthly';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: FutureBuilder<_ReportData>(
        future: _loadData(state),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reports could not load. Try again.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final trend = _trend(data.expenses, _period);
          final categories = _categoryTotals(data.expenses);
          final resources = _resourceTotals(data.resources, data.usages);
          final lowStock = data.inventory
              .where((item) => item.quantity <= item.minimumStock)
              .length;
          final expired = data.inventory.where((item) {
            final expiry = item.expiryDate;
            return expiry != null &&
                expiry.dateOnly.isBefore(DateTime.now().dateOnly);
          }).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Spending trend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Daily', label: Text('Day')),
                  ButtonSegment(value: 'Weekly', label: Text('Week')),
                  ButtonSegment(value: 'Monthly', label: Text('Month')),
                  ButtonSegment(value: 'Yearly', label: Text('Year')),
                ],
                selected: {_period},
                onSelectionChanged: (selection) =>
                    setState(() => _period = selection.first),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: trend.values.every((value) => value == 0)
                    ? const _ChartEmpty(
                        'Add expenses to see your spending trend.',
                      )
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 44,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: trend.labels.length > 7 ? 2 : 1,
                                getTitlesWidget: (value, _) {
                                  final index = value.toInt();
                                  if (index < 0 ||
                                      index >= trend.labels.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      trend.labels[index],
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                trend.values.length,
                                (index) => FlSpot(
                                  index.toDouble(),
                                  trend.values[index],
                                ),
                              ),
                              isCurved: true,
                              barWidth: 3,
                              color: Theme.of(context).colorScheme.primary,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 300),
                      ),
              ),
              const SizedBox(height: 22),
              Text(
                'Spending by category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(
                height: 230,
                child: categories.isEmpty
                    ? const _ChartEmpty('No expense categories to compare yet.')
                    : Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                centerSpaceRadius: 42,
                                sectionsSpace: 3,
                                sections: List.generate(categories.length, (
                                  index,
                                ) {
                                  final item = categories[index];
                                  return PieChartSectionData(
                                    value: item.value,
                                    color:
                                        _chartColors[index %
                                            _chartColors.length],
                                    title: '',
                                    radius: 58,
                                  );
                                }),
                              ),
                              duration: const Duration(milliseconds: 300),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListView(
                              children: List.generate(categories.length, (
                                index,
                              ) {
                                final item = categories[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color:
                                              _chartColors[index %
                                                  _chartColors.length],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 22),
              Text(
                'Resource consumption',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 230,
                child: resources.isEmpty
                    ? const _ChartEmpty(
                        'Log resource usage to see consumption.',
                      )
                    : BarChart(
                        BarChartData(
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= resources.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      resources[index].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(resources.length, (index) {
                            final item = resources[index];
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: item.value,
                                  width: 18,
                                  color:
                                      _chartColors[index % _chartColors.length],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }),
                        ),
                        duration: const Duration(milliseconds: 300),
                      ),
              ),
              const SizedBox(height: 22),
              Text(
                'Inventory health',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _InventoryReportLine(
                label: 'Tracked items',
                value: '${data.inventory.length}',
              ),
              _InventoryReportLine(label: 'Low stock', value: '$lowStock'),
              _InventoryReportLine(label: 'Expired', value: '$expired'),
            ],
          );
        },
      ),
    );
  }
}

Future<_ReportData> _loadData(AppState state) async {
  final results = await Future.wait<Object>([
    state.getExpenses(),
    state.getAllResourceUsage(),
    state.getResources(),
    state.getInventory(),
  ]);
  return _ReportData(
    expenses: results[0] as List<Expense>,
    usages: results[1] as List<ResourceUsage>,
    resources: results[2] as List<ResourceModel>,
    inventory: results[3] as List<InventoryItem>,
  );
}

class _ReportData {
  final List<Expense> expenses;
  final List<ResourceUsage> usages;
  final List<ResourceModel> resources;
  final List<InventoryItem> inventory;

  const _ReportData({
    required this.expenses,
    required this.usages,
    required this.resources,
    required this.inventory,
  });
}

class _ChartSeries {
  final List<String> labels;
  final List<double> values;

  const _ChartSeries(this.labels, this.values);
}

class _ChartValue {
  final String name;
  final double value;

  const _ChartValue(this.name, this.value);
}

_ChartSeries _trend(List<Expense> expenses, String period) {
  final now = DateTime.now();
  late final List<DateTime> starts;
  late final List<String> labels;
  DateTime bucket(DateTime date) {
    switch (period) {
      case 'Daily':
        return DateTime(date.year, date.month, date.day);
      case 'Weekly':
        final day = DateTime(date.year, date.month, date.day);
        return day.subtract(Duration(days: day.weekday - 1));
      case 'Yearly':
        return DateTime(date.year);
      default:
        return DateTime(date.year, date.month);
    }
  }

  if (period == 'Daily') {
    starts = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    labels = starts.map((date) => '${date.day}').toList();
  } else if (period == 'Weekly') {
    final thisMonday = bucket(now);
    starts = List.generate(
      6,
      (i) => thisMonday.subtract(Duration(days: (5 - i) * 7)),
    );
    labels = starts.map((date) => '${date.day}/${date.month}').toList();
  } else if (period == 'Yearly') {
    starts = List.generate(5, (i) => DateTime(now.year - 4 + i));
    labels = starts.map((date) => '${date.year}').toList();
  } else {
    starts = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
    labels = starts.map((date) => DateFormat('MMM').format(date)).toList();
  }

  final totals = List<double>.filled(starts.length, 0);
  for (final expense in expenses) {
    final expenseBucket = bucket(expense.date);
    final index = starts.indexWhere(
      (start) =>
          start.year == expenseBucket.year &&
          start.month == expenseBucket.month &&
          (period != 'Daily' || start.day == expenseBucket.day),
    );
    if (index >= 0) totals[index] += expense.amount;
  }
  return _ChartSeries(labels, totals);
}

List<_ChartValue> _categoryTotals(List<Expense> expenses) {
  final totals = <String, double>{};
  for (final expense in expenses) {
    totals.update(
      expense.category,
      (total) => total + expense.amount,
      ifAbsent: () => expense.amount,
    );
  }
  final values =
      totals.entries
          .map((entry) => _ChartValue(entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  return values.take(6).toList();
}

List<_ChartValue> _resourceTotals(
  List<ResourceModel> resources,
  List<ResourceUsage> usages,
) {
  final totals = <String, double>{};
  for (final usage in usages) {
    totals.update(
      usage.resourceId,
      (total) => total + usage.quantity,
      ifAbsent: () => usage.quantity,
    );
  }
  return resources
      .where((resource) => totals.containsKey(resource.id))
      .map(
        (resource) => _ChartValue(
          '${resource.name} (${resource.unit})',
          totals[resource.id]!,
        ),
      )
      .toList();
}

class _ChartEmpty extends StatelessWidget {
  final String message;

  const _ChartEmpty(this.message);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _InventoryReportLine extends StatelessWidget {
  final String label;
  final String value;

  const _InventoryReportLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(
      value,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

const _chartColors = [
  Color(0xFF287271),
  Color(0xFFE07A5F),
  Color(0xFF4169A1),
  Color(0xFFD3A548),
  Color(0xFF785B84),
  Color(0xFF5C8D62),
];

extension on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
}
