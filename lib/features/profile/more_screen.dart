import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../models/models.dart';
import '../reminders/reminders_screen.dart';
import '../reports/reports_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (user?.name.isNotEmpty ?? false)
                    ? user!.name[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(user?.name ?? 'Household account'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const ProfileSettingsScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Reminders'),
            subtitle: const Text('Bills, refills, and household tasks'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const RemindersScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.query_stats_rounded),
            title: const Text('Reports and analytics'),
            subtitle: const Text('Spending, resource use, and stock'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const ReportsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Profile and settings'),
            subtitle: const Text('Account, household, and preferences'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const ProfileSettingsScreen()),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile and settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(user?.name ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: IconButton(
              tooltip: 'Edit account',
              onPressed: () => _editProfile(context),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          const Divider(height: 28),
          Text(
            'Household members',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FutureBuilder<List<HouseholdMember>>(
            future: state.getMembers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Members could not be loaded.'),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Only you are listed in this household.'),
                );
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (member) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            member.name.isEmpty
                                ? '?'
                                : member.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(member.name),
                        subtitle: Text(member.relationship),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addMember(context),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add member'),
            ),
          ),
          const Divider(height: 28),
          Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Appearance'),
            trailing: DropdownButton<ThemeMode>(
              value: state.themeMode,
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (value) {
                if (value != null) state.setThemeMode(value);
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Currency'),
            trailing: DropdownButton<String>(
              value: state.currency,
              items: const [
                DropdownMenuItem(value: '₹', child: Text('INR ₹')),
                DropdownMenuItem(value: r'$', child: Text(r'USD $')),
                DropdownMenuItem(value: '€', child: Text('EUR €')),
                DropdownMenuItem(value: '£', child: Text('GBP £')),
                DropdownMenuItem(value: '¥', child: Text('JPY ¥')),
              ],
              onChanged: (value) {
                if (value != null) state.setCurrency(value);
              },
            ),
          ),
          const Divider(height: 28),
          Text('Your data', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export household data'),
            subtitle: const Text('Save expenses, usage, and inventory as CSV'),
            onTap: () => _export(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Clear household records'),
            onTap: () => _clearData(context),
          ),
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () => context.read<AppState>().logout(),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: state.currentUser?.name ?? '');
    final email = TextEditingController(text: state.currentUser?.email ?? '');
    String? error;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                  setDialogState(() => error = 'Name and email are required.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) {
      try {
        await state.updateProfile(name: name.text, email: email.text);
      } catch (error, stackTrace) {
        debugPrint('Updating profile failed: $error\n$stackTrace');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Bad state: ', '')),
            ),
          );
        }
      }
    }
    name.dispose();
    email.dispose();
  }

  Future<void> _addMember(BuildContext context) async {
    final name = TextEditingController();
    final relationship = TextEditingController();
    String? error;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add household member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationship,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship or role',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setDialogState(() => error = 'Enter a member name.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) {
      await context.read<AppState>().addMember(
        name: name.text,
        relationship: relationship.text,
      );
    }
    name.dispose();
    relationship.dispose();
  }

  Future<void> _export(BuildContext context) async {
    try {
      final path = await context.read<AppState>().exportCsv();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV saved to $path')));
      }
    } catch (error, stackTrace) {
      debugPrint('Export failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    }
  }

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear household records?'),
        content: const Text(
          'Expenses, readings, items, reminders, and members will be deleted. Your account will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear records'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().clearHouseholdData();
    }
  }
}

void _push(BuildContext context, Widget page) {
  Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
}
