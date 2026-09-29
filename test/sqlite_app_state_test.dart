import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:household/app/app_state.dart';
import 'package:household/core/utils/password_hasher.dart';
import 'package:household/database/database_helper.dart';
import 'package:household/models/models.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'registration, CRUD, session, and records survive database reopen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'household_test_',
      );
      final databasePath = path.join(directory.path, 'household.db');
      final database = DatabaseHelper.forTesting(databasePath);
      final testHasher = const PasswordHasher(iterations: 1000);
      final state = AppState(database: database, passwordHasher: testHasher);

      await state.initialize();
      expect(state.currentUser, isNull);
      expect(
        await state.register(
          name: '  Alex Household  ',
          email: '  ALEX@example.com ',
          password: 'correct horse battery staple',
        ),
        RegistrationResult.created,
      );
      expect(state.currentUser, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('currentUserId'),
        isNull,
      );

      expect(
        await state.register(
          name: 'Another User',
          email: 'alex@example.com',
          password: 'another secure password',
        ),
        RegistrationResult.duplicateEmail,
      );
      expect(
        await state.login(
          email: 'alex@example.com',
          password: 'wrong password',
        ),
        isFalse,
      );
      expect(
        await state.login(
          email: ' ALEX@example.com ',
          password: 'correct horse battery staple',
        ),
        isTrue,
      );

      final userId = state.currentUser!.id;
      final resources = await state.getResources();
      final water = resources.firstWhere(
        (resource) => resource.name == 'Water',
      );
      final now = DateTime.now();
      await state.addExpense(
        Expense(
          id: 'expense-a',
          userId: userId,
          title: 'Electricity bill',
          amount: 1250,
          category: 'Electricity',
          date: now,
          paymentMethod: 'UPI',
          notes: 'September bill',
          recurring: true,
        ),
      );
      await state.addResourceUsage(
        ResourceUsage(
          id: 'usage-a',
          userId: userId,
          resourceId: water.id,
          quantity: 1240,
          unit: 'L',
          date: now,
          cost: 120,
          notes: 'Meter reading',
        ),
      );
      await state.addInventoryItem(
        InventoryItem(
          id: 'inventory-a',
          userId: userId,
          name: 'Rice',
          category: 'Groceries',
          quantity: 1,
          unit: 'kg',
          minimumStock: 2,
          price: 80,
          purchaseDate: now,
          expiryDate: now.add(const Duration(days: 60)),
          notes: '',
        ),
      );
      await state.addReminder(
        ReminderModel(
          id: 'reminder-a',
          userId: userId,
          title: 'Pay electricity bill',
          description: 'Monthly bill',
          dueDate: now,
          time: '09:00',
          recurring: 'Monthly',
          completed: false,
        ),
      );

      final otherUserId = await database.registerAccount(
        name: 'Other User',
        email: 'other@example.com',
        passwordHash: 'not-used-in-this-test',
        passwordSalt: 'other-salt',
      );
      expect(otherUserId, isNotNull);
      await database.addExpense(
        Expense(
          id: 'expense-b',
          userId: otherUserId!,
          title: 'Private expense',
          amount: 999,
          category: 'Other',
          date: now,
          paymentMethod: 'Cash',
          notes: '',
          recurring: false,
        ),
      );
      expect((await state.getExpenses()).map((item) => item.id), ['expense-a']);
      await database.close();

      final reopenedDatabase = DatabaseHelper.forTesting(databasePath);
      final reopenedState = AppState(
        database: reopenedDatabase,
        passwordHasher: testHasher,
      );
      await reopenedState.initialize();
      expect(reopenedState.currentUser?.id, userId);
      expect(
        (await reopenedState.getExpenses()).single.title,
        'Electricity bill',
      );
      expect((await reopenedState.getInventory()).single.quantity, 1);
      expect((await reopenedState.getReminders()).single.completed, isFalse);
      final dashboard = await reopenedState.loadDashboard();
      expect(dashboard.monthlyExpenses, 1250);
      expect(dashboard.waterUsage, 1240);
      expect(dashboard.lowStockCount, 1);

      await reopenedState.logout();
      expect(reopenedState.currentUser, isNull);
      await reopenedState.initialize();
      expect(reopenedState.currentUser, isNull);
      expect(
        await reopenedState.login(
          email: 'alex@example.com',
          password: 'correct horse battery staple',
        ),
        isTrue,
      );
      expect((await reopenedState.getExpenses()).single.id, 'expense-a');

      await reopenedDatabase.close();
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
    },
  );

  test('version one migration preserves existing records', () async {
    final directory = await Directory.systemTemp.createTemp('household_v1_');
    final databasePath = path.join(directory.path, 'household.db');
    final legacy = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE users (id TEXT PRIMARY KEY, name TEXT, email TEXT, passwordHash TEXT, passwordSalt TEXT, createdAt TEXT)',
          );
          await db.execute(
            'CREATE TABLE household_members (id TEXT PRIMARY KEY, userId TEXT, name TEXT, relationship TEXT, avatar TEXT)',
          );
          await db.execute(
            'CREATE TABLE resources (id TEXT PRIMARY KEY, userId TEXT, name TEXT, category TEXT, unit TEXT, iconName TEXT, color TEXT, createdAt TEXT)',
          );
          await db.execute(
            'CREATE TABLE resource_usage (id TEXT PRIMARY KEY, userId TEXT, resourceId TEXT, quantity REAL, unit TEXT, date TEXT, cost REAL, notes TEXT)',
          );
          await db.execute(
            'CREATE TABLE expenses (id TEXT PRIMARY KEY, userId TEXT, title TEXT, amount REAL, category TEXT, date TEXT, paymentMethod TEXT, notes TEXT, recurring INTEGER)',
          );
          await db.execute(
            'CREATE TABLE inventory_items (id TEXT PRIMARY KEY, userId TEXT, name TEXT, category TEXT, quantity REAL, unit TEXT, minimumStock REAL, price REAL, purchaseDate TEXT, expiryDate TEXT, notes TEXT)',
          );
          await db.execute(
            'CREATE TABLE reminders (id TEXT PRIMARY KEY, userId TEXT, title TEXT, description TEXT, dueDate TEXT, time TEXT, recurring TEXT, completed INTEGER)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, userId TEXT, value TEXT)',
          );
          await db.insert('users', {
            'id': 'legacy-user',
            'name': 'Legacy User',
            'email': 'legacy@example.com',
            'passwordHash': 'legacy-hash',
            'passwordSalt': 'legacy-salt',
            'createdAt': '2026-01-01T00:00:00.000',
          });
          await db.insert('resources', {
            'id': 'legacy-water',
            'userId': 'legacy-user',
            'name': 'Water',
            'category': 'Utility',
            'unit': 'L',
            'iconName': 'water_drop',
            'color': '#3B82F6',
            'createdAt': '2026-01-01T00:00:00.000',
          });
          await db.insert('expenses', {
            'id': 'legacy-expense',
            'userId': 'legacy-user',
            'title': 'Legacy bill',
            'amount': 75.0,
            'category': 'Water',
            'date': '2026-09-01T00:00:00.000',
            'paymentMethod': 'Cash',
            'notes': '',
            'recurring': 0,
          });
          await db.insert('resource_usage', {
            'id': 'legacy-usage',
            'userId': 'legacy-user',
            'resourceId': 'legacy-water',
            'quantity': 12.0,
            'unit': 'L',
            'date': '2026-09-01T00:00:00.000',
            'cost': 2.0,
            'notes': 'legacy reading',
          });
          await db.insert('settings', {
            'key': 'currency',
            'userId': 'legacy-user',
            'value': '₹',
          });
        },
      ),
    );
    await legacy.close();

    final migrated = DatabaseHelper.forTesting(databasePath);
    expect((await migrated.getUserById('legacy-user'))?.name, 'Legacy User');
    expect((await migrated.getExpenses('legacy-user')).single.amount, 75);
    expect((await migrated.getAllUsage('legacy-user')).single.quantity, 12);
    expect(await migrated.getSetting('legacy-user', 'currency'), '₹');
    final db = await migrated.database;
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    await migrated.close();
    try {
      await directory.delete(recursive: true);
    } catch (_) {}
  });

  test('full CRUD, members, profile, settings, and CSV export work properly', () async {
    SharedPreferences.setMockInitialValues({});
    final database = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final testHasher = const PasswordHasher(iterations: 1000);
    final state = AppState(database: database, passwordHasher: testHasher);

    await state.initialize();

    // 1. Validation tests
    expect(
      await state.register(name: 'A', email: 'valid@test.com', password: 'password123'),
      RegistrationResult.invalidInput,
    );
    expect(
      await state.register(name: 'Valid Name', email: 'invalid-email', password: 'password123'),
      RegistrationResult.invalidInput,
    );
    expect(
      await state.register(name: 'Valid Name', email: 'valid@test.com', password: 'short'),
      RegistrationResult.invalidInput,
    );

    // 2. Successful registration
    expect(
      await state.register(name: 'Jane Doe', email: 'jane@example.com', password: 'secure_password_123'),
      RegistrationResult.created,
    );

    // 3. Login
    expect(await state.login(email: 'jane@example.com', password: 'secure_password_123'), isTrue);
    expect(state.currentUser?.name, 'Jane Doe');
    final userId = state.currentUser!.id;

    // 4. Profile update
    await state.updateProfile(name: 'Jane Smith', email: 'janesmith@example.com');
    expect(state.currentUser?.name, 'Jane Smith');
    expect(state.currentUser?.email, 'janesmith@example.com');

    // 5. Household members
    await state.addMember(name: 'John Smith', relationship: 'Partner');
    final members = await state.getMembers();
    expect(members.length, 1);
    expect(members.first.name, 'John Smith');
    expect(members.first.relationship, 'Partner');

    // 6. Resources & Usage
    final resources = await state.getResources();
    expect(resources.isNotEmpty, isTrue); // Default resources created
    final electricity = resources.firstWhere((r) => r.name == 'Electricity');
    
    // Add custom resource
    final customResource = ResourceModel(
      id: 'custom-solar',
      userId: userId,
      name: 'Solar Power',
      category: 'Utility',
      unit: 'kWh',
      iconName: 'solar_power',
      color: '#F59E0B',
      createdAt: DateTime.now().toIso8601String(),
    );
    await state.addResource(customResource);
    final allResources = await state.getResources();
    expect(allResources.any((r) => r.name == 'Solar Power'), isTrue);

    // Update resource
    final updatedSolar = ResourceModel(
      id: 'custom-solar',
      userId: userId,
      name: 'Solar Generation',
      category: 'Utility',
      unit: 'kWh',
      iconName: 'solar_power',
      color: '#F59E0B',
      createdAt: customResource.createdAt,
    );
    await state.updateResource(updatedSolar);
    expect((await state.getResources()).firstWhere((r) => r.id == 'custom-solar').name, 'Solar Generation');

    // Record Usage
    final now = DateTime.now();
    await state.addResourceUsage(
      ResourceUsage(
        id: 'usage-1',
        userId: userId,
        resourceId: electricity.id,
        quantity: 320.5,
        unit: 'kWh',
        date: now,
        cost: 450.0,
        notes: 'Monthly electricity bill reading',
      ),
    );
    final usageList = await state.getResourceUsage(electricity.id);
    expect(usageList.length, 1);
    expect(usageList.first.quantity, 320.5);

    // Delete custom resource
    await state.deleteResource('custom-solar');
    expect((await state.getResources()).any((r) => r.id == 'custom-solar'), isFalse);

    // 7. Expenses CRUD
    final expense = Expense(
      id: 'exp-1',
      userId: userId,
      title: 'Weekly Groceries',
      amount: 2500.0,
      category: 'Groceries',
      date: now,
      paymentMethod: 'Credit Card',
      notes: 'Supermarket shopping',
      recurring: false,
    );
    await state.addExpense(expense);
    var expenses = await state.getExpenses();
    expect(expenses.length, 1);
    expect(expenses.first.title, 'Weekly Groceries');

    // Update Expense
    final updatedExpense = Expense(
      id: 'exp-1',
      userId: userId,
      title: 'Weekly Groceries & Supplies',
      amount: 2800.0,
      category: 'Groceries',
      date: now,
      paymentMethod: 'Credit Card',
      notes: 'Supermarket shopping updated',
      recurring: false,
    );
    await state.updateExpense(updatedExpense);
    expenses = await state.getExpenses();
    expect(expenses.first.amount, 2800.0);

    // 8. Inventory CRUD
    final item = InventoryItem(
      id: 'inv-1',
      userId: userId,
      name: 'Milk 1L',
      category: 'Groceries',
      quantity: 1,
      unit: 'bottles',
      minimumStock: 3,
      price: 60.0,
      purchaseDate: now,
      expiryDate: now.add(const Duration(days: 4)),
      notes: 'Full cream milk',
    );
    await state.addInventoryItem(item);
    var inventory = await state.getInventory();
    expect(inventory.length, 1);
    expect(inventory.first.name, 'Milk 1L');

    // Update Inventory
    final updatedItem = InventoryItem(
      id: 'inv-1',
      userId: userId,
      name: 'Milk 1L',
      category: 'Groceries',
      quantity: 4,
      unit: 'bottles',
      minimumStock: 3,
      price: 60.0,
      purchaseDate: now,
      expiryDate: now.add(const Duration(days: 4)),
      notes: 'Restocked',
    );
    await state.updateInventoryItem(updatedItem);
    inventory = await state.getInventory();
    expect(inventory.first.quantity, 4);

    // 9. Reminders CRUD
    final reminder = ReminderModel(
      id: 'rem-1',
      userId: userId,
      title: 'Water filter service',
      description: 'Call technician for cartridge replacement',
      dueDate: now.add(const Duration(days: 2)),
      time: '10:00',
      recurring: 'Monthly',
      completed: false,
    );
    await state.addReminder(reminder);
    var reminders = await state.getReminders();
    expect(reminders.length, 1);
    expect(reminders.first.title, 'Water filter service');

    // Complete Reminder
    final updatedReminder = ReminderModel(
      id: 'rem-1',
      userId: userId,
      title: reminder.title,
      description: reminder.description,
      dueDate: reminder.dueDate,
      time: reminder.time,
      recurring: reminder.recurring,
      completed: true,
    );
    await state.updateReminder(updatedReminder);
    reminders = await state.getReminders();
    expect(reminders.first.completed, isTrue);

    // 10. Dashboard Data
    final dashboard = await state.loadDashboard();
    expect(dashboard.monthlyExpenses, 2800.0);
    expect(dashboard.householdMemberCount, 2); // 1 registered + 1 member

    // 11. Preferences
    await state.setThemeMode(ThemeMode.dark);
    expect(state.themeMode, ThemeMode.dark);
    await state.setCurrency(r'$');
    expect(state.currency, r'$');

    // 12. CSV Export
    final csvPath = await state.exportCsv();
    expect(csvPath.endsWith('.csv'), isTrue);
    final csvFile = File(csvPath);
    expect(await csvFile.exists(), isTrue);
    final content = await csvFile.readAsString();
    expect(content.contains('Weekly Groceries & Supplies'), isTrue);
    expect(content.contains('Milk 1L'), isTrue);
    await csvFile.delete();

    // 13. Delete Expense, Inventory, Reminder
    await state.deleteExpense('exp-1');
    expect(await state.getExpenses(), isEmpty);
    await state.deleteInventoryItem('inv-1');
    expect(await state.getInventory(), isEmpty);
    await state.deleteReminder('rem-1');
    expect(await state.getReminders(), isEmpty);

    await database.close();
  });
}
