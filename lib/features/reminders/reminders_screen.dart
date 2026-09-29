import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../models/models.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  String _filter = 'Open';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter reminders',
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Open', child: Text('Open')),
              PopupMenuItem(value: 'Completed', child: Text('Completed')),
              PopupMenuItem(value: 'All', child: Text('All reminders')),
            ],
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ReminderModel>>(
        future: state.getReminders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReminderMessage(
              message: 'Reminders could not be loaded.',
              action: () => setState(() {}),
              actionLabel: 'Try again',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reminders = snapshot.data!
              .where(
                (item) => switch (_filter) {
                  'Open' => !item.completed,
                  'Completed' => item.completed,
                  _ => true,
                },
              )
              .toList();
          if (reminders.isEmpty) {
            return _ReminderMessage(
              message: snapshot.data!.isEmpty
                  ? 'No reminders yet. Add a bill, refill, or household task.'
                  : 'No $_filter reminders.',
              action: snapshot.data!.isEmpty
                  ? () => _openEditor(context)
                  : null,
              actionLabel: 'Add reminder',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: reminders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = reminders[index];
              final overdue =
                  !item.completed &&
                  DateTime(
                    item.dueDate.year,
                    item.dueDate.month,
                    item.dueDate.day,
                  ).isBefore(DateTime.now().dateOnly);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: Checkbox(
                  value: item.completed,
                  semanticLabel: 'Mark ${item.title} completed',
                  onChanged: (value) async {
                    await context.read<AppState>().updateReminder(
                      ReminderModel(
                        id: item.id,
                        userId: item.userId,
                        title: item.title,
                        description: item.description,
                        dueDate: item.dueDate,
                        time: item.time,
                        recurring: item.recurring,
                        completed: value ?? false,
                      ),
                    );
                  },
                ),
                title: Text(item.title),
                subtitle: Text(
                  '${DateFormat('d MMM yyyy').format(item.dueDate)} · ${item.time}${item.description.isEmpty ? '' : '\n${item.description}'}',
                ),
                isThreeLine: item.description.isNotEmpty,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      overdue
                          ? 'Overdue'
                          : item.completed
                          ? 'Done'
                          : item.recurring == 'None'
                          ? 'Once'
                          : item.recurring,
                      style: TextStyle(
                        color: overdue
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Reminder actions',
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        if (action == 'edit') {
                          _openEditor(context, item);
                        } else {
                          _confirmDelete(context, item);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
                onTap: () => _openEditor(context, item),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add reminder',
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _openEditor(BuildContext context, [ReminderModel? reminder]) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReminderEditorScreen(reminder: reminder),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReminderModel reminder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this reminder?'),
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
    await context.read<AppState>().deleteReminder(reminder.id);
  }
}

class ReminderEditorScreen extends StatefulWidget {
  final ReminderModel? reminder;

  const ReminderEditorScreen({super.key, this.reminder});

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _dueDate;
  late TimeOfDay _time;
  late String _recurring;
  bool _completed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _title = TextEditingController(text: reminder?.title ?? '');
    _description = TextEditingController(text: reminder?.description ?? '');
    _dueDate = reminder?.dueDate ?? DateTime.now();
    final timeParts = (reminder?.time ?? '09:00').split(':');
    _time = TimeOfDay(
      hour: int.tryParse(timeParts.first) ?? 9,
      minute: timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0,
    );
    _recurring = reminder?.recurring ?? 'None';
    _completed = reminder?.completed ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      final reminder = ReminderModel(
        id: widget.reminder?.id ?? const Uuid().v4(),
        userId: state.currentUser!.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: DateTime(_dueDate.year, _dueDate.month, _dueDate.day),
        time:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        recurring: _recurring,
        completed: _completed,
      );
      if (widget.reminder == null) {
        await state.addReminder(reminder);
      } else {
        await state.updateReminder(reminder);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Saving reminder failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder could not be saved. Try again.'),
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
      title: Text(widget.reminder == null ? 'Add reminder' : 'Edit reminder'),
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
                ? 'Enter a reminder title.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due date'),
            subtitle: Text(DateFormat('d MMMM yyyy').format(_dueDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (date != null) setState(() => _dueDate = date);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.schedule_rounded),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (time != null) setState(() => _time = time);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _recurring,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: const ['None', 'Daily', 'Weekly', 'Monthly', 'Yearly']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _recurring = value ?? 'None'),
          ),
          if (widget.reminder != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Completed'),
              value: _completed,
              onChanged: (value) => setState(() => _completed = value),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save reminder'),
          ),
        ],
      ),
    ),
  );
}

class _ReminderMessage extends StatelessWidget {
  final String message;
  final VoidCallback? action;
  final String actionLabel;

  const _ReminderMessage({
    required this.message,
    this.action,
    required this.actionLabel,
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

extension on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
}
