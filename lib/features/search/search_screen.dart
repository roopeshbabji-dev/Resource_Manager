import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../models/models.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reminders/reminders_screen.dart';
import '../resources/resources_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Search household data')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Expenses, resources, items, reminders',
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<_SearchData>(
              future: _load(state),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Search data could not load. Try again.',
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = _query.text.trim().toLowerCase();
                if (query.isEmpty) {
                  return const _SearchMessage(
                    icon: Icons.manage_search_rounded,
                    message: 'Search across your household records.',
                  );
                }
                final data = snapshot.data!;
                final results = <_SearchResult>[
                  ...data.expenses
                      .where(
                        (item) => _matches(query, [
                          item.title,
                          item.category,
                          item.paymentMethod,
                          item.notes,
                        ]),
                      )
                      .map(
                        (item) => _SearchResult(
                          kind: 'Expense',
                          title: item.title,
                          subtitle: item.category,
                          icon: Icons.receipt_long_outlined,
                          open: () => _push(
                            context,
                            ExpenseDetailScreen(expense: item),
                          ),
                        ),
                      ),
                  ...data.resources
                      .where(
                        (item) => _matches(query, [
                          item.name,
                          item.category,
                          item.unit,
                        ]),
                      )
                      .map(
                        (item) => _SearchResult(
                          kind: 'Resource',
                          title: item.name,
                          subtitle: '${item.category} · ${item.unit}',
                          icon: Icons.eco_outlined,
                          open: () => _push(
                            context,
                            ResourceDetailScreen(resource: item),
                          ),
                        ),
                      ),
                  ...data.inventory
                      .where(
                        (item) => _matches(query, [
                          item.name,
                          item.category,
                          item.notes,
                        ]),
                      )
                      .map(
                        (item) => _SearchResult(
                          kind: 'Inventory',
                          title: item.name,
                          subtitle:
                              '${item.quantity} ${item.unit} · ${item.category}',
                          icon: Icons.inventory_2_outlined,
                          open: () =>
                              _push(context, InventoryDetailScreen(item: item)),
                        ),
                      ),
                  ...data.reminders
                      .where(
                        (item) => _matches(query, [
                          item.title,
                          item.description,
                          item.recurring,
                        ]),
                      )
                      .map(
                        (item) => _SearchResult(
                          kind: 'Reminder',
                          title: item.title,
                          subtitle: item.description,
                          icon: Icons.notifications_none_rounded,
                          open: () => _push(
                            context,
                            ReminderEditorScreen(reminder: item),
                          ),
                        ),
                      ),
                ];
                if (results.isEmpty) {
                  return const _SearchMessage(
                    icon: Icons.search_off_rounded,
                    message: 'No matching records found.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return ListTile(
                      leading: CircleAvatar(child: Icon(item.icon)),
                      title: Text(item.title),
                      subtitle: Text('${item.kind} · ${item.subtitle}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: item.open,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<_SearchData> _load(AppState state) async {
  final values = await Future.wait<Object>([
    state.getExpenses(),
    state.getResources(),
    state.getInventory(),
    state.getReminders(),
  ]);
  return _SearchData(
    expenses: values[0] as List<Expense>,
    resources: values[1] as List<ResourceModel>,
    inventory: values[2] as List<InventoryItem>,
    reminders: values[3] as List<ReminderModel>,
  );
}

bool _matches(String query, List<String> fields) =>
    fields.any((field) => field.toLowerCase().contains(query));

class _SearchData {
  final List<Expense> expenses;
  final List<ResourceModel> resources;
  final List<InventoryItem> inventory;
  final List<ReminderModel> reminders;

  const _SearchData({
    required this.expenses,
    required this.resources,
    required this.inventory,
    required this.reminders,
  });
}

class _SearchResult {
  final String kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback open;

  const _SearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.open,
  });
}

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SearchMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(message),
      ],
    ),
  );
}

void _push(BuildContext context, Widget page) {
  Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
}
