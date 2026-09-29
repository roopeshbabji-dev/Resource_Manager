import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../core/utils/password_hasher.dart';
import '../models/models.dart';

enum RegistrationResult { created, duplicateEmail, invalidInput }

class AppState extends ChangeNotifier {
  AppState({DatabaseHelper? database, PasswordHasher? passwordHasher})
    : _database = database ?? DatabaseHelper.instance,
      _passwordHasher = passwordHasher ?? const PasswordHasher();

  final DatabaseHelper _database;
  final PasswordHasher _passwordHasher;
  final Uuid _uuid = const Uuid();

  UserModel? currentUser;
  bool isLoading = true;
  Object? initializationError;
  ThemeMode themeMode = ThemeMode.system;
  String currency = '₹';
  bool notificationsEnabled = true;

  Future<void> initialize() async {
    try {
      await _database.initialize();
      final preferences = await SharedPreferences.getInstance();
      final userId = preferences.getString('currentUserId');
      if (userId != null) {
        currentUser = await _database.getUserById(userId);
        if (currentUser == null) {
          await preferences.remove('currentUserId');
        }
      }
      themeMode = _themeModeFromString(preferences.getString('themeMode'));
      currency = preferences.getString('currency') ?? '₹';
      notificationsEnabled = preferences.getBool('notifications') ?? true;
    } catch (error, stackTrace) {
      initializationError = error;
      debugPrint('App initialization failed: $error\n$stackTrace');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> setCurrency(String value) async {
    if (!const {'₹', r'$', '€', '£', '¥'}.contains(value)) return;
    currency = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('currency', value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('notifications', enabled);
    notifyListeners();
  }

  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (trimmedName.length < 2 ||
        !_isValidEmail(normalizedEmail) ||
        password.length < 8) {
      return RegistrationResult.invalidInput;
    }

    if (await _database.getUserByEmail(normalizedEmail) != null) {
      return RegistrationResult.duplicateEmail;
    }

    final salt = _generateSalt();
    final passwordHash = await _passwordHasher.hash(password, salt);
    final userId = await _database.registerAccount(
      name: trimmedName,
      email: normalizedEmail,
      passwordHash: passwordHash,
      passwordSalt: salt,
    );
    if (userId == null) return RegistrationResult.duplicateEmail;
    return RegistrationResult.created;
  }

  Future<bool> login({required String email, required String password}) async {
    final user = await _database.getUserByEmail(email.trim().toLowerCase());
    if (user == null ||
        !await _passwordHasher.verify(
          password: password,
          salt: user.passwordSalt,
          storedHash: user.passwordHash,
        )) {
      return false;
    }

    if (!user.passwordHash.startsWith('pbkdf2-sha256:')) {
      final upgradedHash = await _passwordHasher.hash(
        password,
        user.passwordSalt,
      );
      await _database.updatePasswordCredentials(
        user.id,
        upgradedHash,
        user.passwordSalt,
      );
    }

    currentUser = await _database.getUserById(user.id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('currentUserId', user.id);
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    currentUser = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('currentUserId');
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final user = _requireUser();
    final normalizedEmail = email.trim().toLowerCase();
    if (name.trim().isEmpty || !_isValidEmail(normalizedEmail)) {
      throw ArgumentError('Enter a name and a valid email address.');
    }
    final existing = await _database.getUserByEmail(normalizedEmail);
    if (existing != null && existing.id != user.id) {
      throw StateError('That email address is already in use.');
    }
    await _database.updateUser(
      user.id,
      name: name.trim(),
      email: normalizedEmail,
    );
    currentUser = await _database.getUserById(user.id);
    notifyListeners();
  }

  Future<DashboardData> loadDashboard() async {
    final user = _requireUser();
    final results = await Future.wait<Object>([
      _database.getExpenses(user.id),
      _database.getAllUsage(user.id),
      _database.getInventory(user.id),
      _database.getMembers(user.id),
      _database.getResources(user.id),
      _database.getReminders(user.id),
    ]);
    final expenses = results[0] as List<Expense>;
    final usage = results[1] as List<ResourceUsage>;
    final inventory = results[2] as List<InventoryItem>;
    final members = results[3] as List<HouseholdMember>;
    final resources = results[4] as List<ResourceModel>;
    final reminders = results[5] as List<ReminderModel>;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    double monthlyExpenses(DateTime month) => expenses
        .where(
          (expense) =>
              expense.date.year == month.year &&
              expense.date.month == month.month,
        )
        .fold(0, (sum, expense) => sum + expense.amount);

    final waterResources = resources.where(
      (resource) => resource.name.toLowerCase() == 'water',
    );
    final water = waterResources.isEmpty ? null : waterResources.first;
    final waterUsage = usage
        .where(
          (entry) =>
              entry.resourceId == water?.id &&
              entry.date.year == thisMonth.year &&
              entry.date.month == thisMonth.month,
        )
        .fold(0.0, (sum, entry) => sum + entry.quantity);
    final utilityCost = expenses
        .where(
          (expense) =>
              expense.date.year == thisMonth.year &&
              expense.date.month == thisMonth.month &&
              const {
                'electricity',
                'water',
                'gas',
                'internet',
              }.contains(expense.category.toLowerCase()),
        )
        .fold(0.0, (sum, expense) => sum + expense.amount);
    final currentTotal = monthlyExpenses(thisMonth);
    final previousTotal = monthlyExpenses(previousMonth);
    final changePercent = previousTotal == 0
        ? (currentTotal == 0 ? 0.0 : 100.0)
        : ((currentTotal - previousTotal) / previousTotal) * 100;
    final lowStock = inventory
        .where((item) => item.quantity <= item.minimumStock)
        .toList();
    final resourceSummaries = resources.map((resource) {
      final quantity = usage
          .where(
            (entry) =>
                entry.resourceId == resource.id &&
                entry.date.year == thisMonth.year &&
                entry.date.month == thisMonth.month,
          )
          .fold(0.0, (sum, entry) => sum + entry.quantity);
      return ResourceSummary(resource: resource, quantity: quantity);
    }).toList();

    return DashboardData(
      monthlyExpenses: currentTotal,
      previousMonthExpenses: previousTotal,
      expenseChangePercent: changePercent,
      waterUsage: waterUsage,
      waterUnit: water?.unit ?? 'L',
      utilityCost: utilityCost,
      lowStockCount: lowStock.length,
      householdMemberCount: members.length + 1,
      recentExpenses: expenses.take(4).toList(),
      lowStockItems: lowStock.take(4).toList(),
      resourceSummaries: resourceSummaries,
      upcomingReminders: reminders
          .where((reminder) => !reminder.completed)
          .take(3)
          .toList(),
    );
  }

  Future<List<ResourceModel>> getResources() async =>
      _database.getResources(_requireUser().id);

  Future<void> addResource(ResourceModel resource) async {
    _ensureOwner(resource.userId);
    await _database.addResource(resource);
    notifyListeners();
  }

  Future<void> updateResource(ResourceModel resource) async {
    _ensureOwner(resource.userId);
    await _database.updateResource(resource);
    notifyListeners();
  }

  Future<void> deleteResource(String id) async {
    await _database.deleteResource(id, _requireUser().id);
    notifyListeners();
  }

  Future<List<ResourceUsage>> getResourceUsage(String resourceId) async =>
      _database.getUsageForResource(resourceId, _requireUser().id);

  Future<List<ResourceUsage>> getAllResourceUsage() async =>
      _database.getAllUsage(_requireUser().id);

  Future<void> addResourceUsage(ResourceUsage usage) async {
    _ensureOwner(usage.userId);
    await _database.addUsage(usage);
    notifyListeners();
  }

  Future<List<Expense>> getExpenses() async =>
      _database.getExpenses(_requireUser().id);

  Future<void> addExpense(Expense expense) async {
    _ensureOwner(expense.userId);
    await _database.addExpense(expense);
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    _ensureOwner(expense.userId);
    await _database.updateExpense(expense);
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    await _database.deleteExpense(id, _requireUser().id);
    notifyListeners();
  }

  Future<List<InventoryItem>> getInventory() async =>
      _database.getInventory(_requireUser().id);

  Future<void> addInventoryItem(InventoryItem item) async {
    _ensureOwner(item.userId);
    await _database.addInventoryItem(item);
    notifyListeners();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    _ensureOwner(item.userId);
    await _database.updateInventoryItem(item);
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    await _database.deleteInventoryItem(id, _requireUser().id);
    notifyListeners();
  }

  Future<List<ReminderModel>> getReminders() async =>
      _database.getReminders(_requireUser().id);

  Future<void> addReminder(ReminderModel reminder) async {
    _ensureOwner(reminder.userId);
    await _database.addReminder(reminder);
    notifyListeners();
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    _ensureOwner(reminder.userId);
    await _database.updateReminder(reminder);
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    await _database.deleteReminder(id, _requireUser().id);
    notifyListeners();
  }

  Future<List<HouseholdMember>> getMembers() async =>
      _database.getMembers(_requireUser().id);

  Future<void> addMember({
    required String name,
    required String relationship,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Member name is required.');
    await _database.addMember(
      HouseholdMember(
        id: _uuid.v4(),
        userId: _requireUser().id,
        name: trimmedName,
        relationship: relationship.trim().isEmpty
            ? 'Member'
            : relationship.trim(),
      ),
    );
    notifyListeners();
  }

  Future<void> clearHouseholdData() async {
    final user = _requireUser();
    await _database.clearUserData(user.id);
    await _database.createDefaultResources(user.id);
    notifyListeners();
  }

  Future<String> exportCsv() async {
    final user = _requireUser();
    final results = await Future.wait<Object>([
      _database.getExpenses(user.id),
      _database.getAllUsage(user.id),
      _database.getInventory(user.id),
    ]);
    final expenses = results[0] as List<Expense>;
    final usages = results[1] as List<ResourceUsage>;
    final inventory = results[2] as List<InventoryItem>;
    final csv = StringBuffer(
      'Type,Title,Category,Quantity,Unit,Amount,Date,Notes\n',
    );
    String quote(String value) => '"${value.replaceAll('"', '""')}"';

    for (final expense in expenses) {
      csv.writeln(
        [
          'Expense',
          quote(expense.title),
          quote(expense.category),
          '',
          '',
          expense.amount,
          DateFormat('yyyy-MM-dd').format(expense.date),
          quote(expense.notes),
        ].join(','),
      );
    }
    for (final usage in usages) {
      csv.writeln(
        [
          'Resource usage',
          quote(usage.resourceId),
          '',
          usage.quantity,
          quote(usage.unit),
          usage.cost,
          DateFormat('yyyy-MM-dd').format(usage.date),
          quote(usage.notes),
        ].join(','),
      );
    }
    for (final item in inventory) {
      csv.writeln(
        [
          'Inventory',
          quote(item.name),
          quote(item.category),
          item.quantity,
          quote(item.unit),
          item.price,
          DateFormat('yyyy-MM-dd').format(item.purchaseDate),
          quote(item.notes),
        ].join(','),
      );
    }

    Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (_) {
      directory = Directory.systemTemp;
    }
    final file = File(
      '${directory.path}${Platform.pathSeparator}household_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv.toString(), flush: true);
    return file.path;
  }

  UserModel _requireUser() {
    final user = currentUser;
    if (user == null) throw StateError('Sign in to access household data.');
    return user;
  }

  void _ensureOwner(String userId) {
    if (_requireUser().id != userId) {
      throw StateError('This record does not belong to the signed-in account.');
    }
  }

  ThemeMode _themeModeFromString(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

class DashboardData {
  final double monthlyExpenses;
  final double previousMonthExpenses;
  final double expenseChangePercent;
  final double waterUsage;
  final String waterUnit;
  final double utilityCost;
  final int lowStockCount;
  final int householdMemberCount;
  final List<Expense> recentExpenses;
  final List<InventoryItem> lowStockItems;
  final List<ResourceSummary> resourceSummaries;
  final List<ReminderModel> upcomingReminders;

  const DashboardData({
    required this.monthlyExpenses,
    required this.previousMonthExpenses,
    required this.expenseChangePercent,
    required this.waterUsage,
    required this.waterUnit,
    required this.utilityCost,
    required this.lowStockCount,
    required this.householdMemberCount,
    required this.recentExpenses,
    required this.lowStockItems,
    required this.resourceSummaries,
    required this.upcomingReminders,
  });
}

class ResourceSummary {
  final ResourceModel resource;
  final double quantity;

  const ResourceSummary({required this.resource, required this.quantity});
}
