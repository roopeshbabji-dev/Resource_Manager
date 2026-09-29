import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/models.dart';

class DatabaseHelper {
  DatabaseHelper._({this._pathOverride});
  static final DatabaseHelper instance = DatabaseHelper._();

  final String? _pathOverride;
  Database? _database;

  static void ensurePlatformInitialized() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static DatabaseHelper forTesting(String path) =>
      DatabaseHelper._(pathOverride: path);

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _initDatabase() async {
    ensurePlatformInitialized();
    final pathOverride = _pathOverride;
    String dbPath;
    if (pathOverride != null) {
      dbPath = pathOverride;
    } else {
      String basePath;
      try {
        basePath = (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        basePath = Directory.current.path;
      }
      final dir = Directory(basePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      dbPath = join(basePath, 'household_manager.db');
    }

    return openDatabase(
      dbPath,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        passwordSalt TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE household_members (
        id TEXT PRIMARY KEY NOT NULL,
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        relationship TEXT NOT NULL,
        avatar TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE resources (
        id TEXT PRIMARY KEY NOT NULL,
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        iconName TEXT NOT NULL,
        color TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        UNIQUE(id, userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE resource_usage (
        id TEXT PRIMARY KEY NOT NULL,
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        resourceId TEXT NOT NULL,
        quantity REAL NOT NULL CHECK(quantity > 0),
        unit TEXT NOT NULL,
        date TEXT NOT NULL,
        cost REAL NOT NULL CHECK(cost >= 0),
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(resourceId, userId) REFERENCES resources(id, userId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY NOT NULL,
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        amount REAL NOT NULL CHECK(amount > 0),
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        recurring INTEGER NOT NULL DEFAULT 0 CHECK(recurring IN (0, 1))
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_items (
        id TEXT PRIMARY KEY NOT NULL,
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL CHECK(quantity >= 0),
        unit TEXT NOT NULL,
        minimumStock REAL NOT NULL CHECK(minimumStock >= 0),
        price REAL NOT NULL CHECK(price >= 0),
        purchaseDate TEXT NOT NULL,
        expiryDate TEXT,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY NOT NULL,
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        dueDate TEXT NOT NULL,
        time TEXT NOT NULL,
        recurring TEXT NOT NULL DEFAULT 'None',
        completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1))
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY(userId, key)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_usage_user_date ON resource_usage(userId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_user_date ON expenses(userId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_inventory_user_name ON inventory_items(userId, name)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_user_due ON reminders(userId, dueDate)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateVersionOne(db);
    }
  }

  Future<void> _migrateVersionOne(DatabaseExecutor db) async {
    const tables = [
      'household_members',
      'resource_usage',
      'expenses',
      'inventory_items',
      'reminders',
      'settings',
      'resources',
      'users',
    ];
    for (final table in tables) {
      await db.execute('ALTER TABLE $table RENAME TO ${table}_v1');
    }

    await _createSchema(db);
    await db.execute('''
      INSERT INTO users (id, name, email, passwordHash, passwordSalt, createdAt)
      SELECT id, COALESCE(name, ''), COALESCE(email, ''),
             COALESCE(passwordHash, ''), COALESCE(passwordSalt, ''),
             COALESCE(createdAt, '')
      FROM users_v1
    ''');
    await db.execute('''
      INSERT INTO household_members (id, userId, name, relationship, avatar)
      SELECT id, userId, COALESCE(name, ''), COALESCE(relationship, 'Member'), avatar
      FROM household_members_v1
    ''');
    await db.execute('''
      INSERT INTO resources (id, userId, name, category, unit, iconName, color, createdAt)
      SELECT id, userId, COALESCE(name, ''), COALESCE(category, 'Other'),
             COALESCE(unit, 'unit'), COALESCE(iconName, 'analytics'),
             COALESCE(color, '#438A76'), COALESCE(createdAt, '')
      FROM resources_v1
    ''');
    await db.execute('''
      INSERT INTO resource_usage (id, userId, resourceId, quantity, unit, date, cost, notes)
      SELECT id, userId, resourceId, COALESCE(quantity, 0.000001),
             COALESCE(unit, 'unit'), COALESCE(date, ''), COALESCE(cost, 0),
             COALESCE(notes, '')
      FROM resource_usage_v1
    ''');
    await db.execute('''
      INSERT INTO expenses (id, userId, title, amount, category, date, paymentMethod, notes, recurring)
      SELECT id, userId, COALESCE(title, ''), CASE WHEN amount > 0 THEN amount ELSE 0.000001 END,
             COALESCE(category, 'Other'), COALESCE(date, ''),
             COALESCE(paymentMethod, 'Not specified'), COALESCE(notes, ''),
             CASE WHEN recurring = 1 THEN 1 ELSE 0 END
      FROM expenses_v1
    ''');
    await db.execute('''
      INSERT INTO inventory_items (id, userId, name, category, quantity, unit, minimumStock, price, purchaseDate, expiryDate, notes)
      SELECT id, userId, COALESCE(name, ''), COALESCE(category, 'Other'),
             MAX(COALESCE(quantity, 0), 0), COALESCE(unit, 'unit'),
             MAX(COALESCE(minimumStock, 0), 0), MAX(COALESCE(price, 0), 0),
             COALESCE(purchaseDate, ''), expiryDate, COALESCE(notes, '')
      FROM inventory_items_v1
    ''');
    await db.execute('''
      INSERT INTO reminders (id, userId, title, description, dueDate, time, recurring, completed)
      SELECT id, userId, COALESCE(title, ''), COALESCE(description, ''),
             COALESCE(dueDate, ''), COALESCE(time, '09:00'),
             COALESCE(recurring, 'None'), CASE WHEN completed = 1 THEN 1 ELSE 0 END
      FROM reminders_v1
    ''');
    await db.execute('''
      INSERT INTO settings (userId, key, value)
      SELECT userId, key, COALESCE(value, '') FROM settings_v1
    ''');

    for (final table in tables) {
      await db.execute('DROP TABLE ${table}_v1');
    }
  }

  Future<String?> registerAccount({
    required String name,
    required String email,
    required String passwordHash,
    required String passwordSalt,
  }) async {
    final db = await database;
    return db.transaction((transaction) async {
      final existing = await transaction.query(
        'users',
        columns: ['id'],
        where: 'email = ? COLLATE NOCASE',
        whereArgs: [email],
        limit: 1,
      );
      if (existing.isNotEmpty) return null;

      final id = _generateId();
      await transaction.insert('users', {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _insertDefaultResources(transaction, id);
      return id;
    });
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email],
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<String> insertUser({
    required String name,
    required String email,
    required String passwordHash,
    required String passwordSalt,
  }) async {
    final db = await database;
    final id = _generateId();
    await db.insert('users', {
      'id': id,
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'passwordSalt': passwordSalt,
      'createdAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateUser(String userId, {String? name, String? email}) async {
    final db = await database;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (data.isNotEmpty) {
      await db.update('users', data, where: 'id = ?', whereArgs: [userId]);
    }
  }

  Future<void> updatePasswordCredentials(
    String userId,
    String passwordHash,
    String passwordSalt,
  ) async {
    final db = await database;
    await db.update(
      'users',
      {'passwordHash': passwordHash, 'passwordSalt': passwordSalt},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<HouseholdMember>> getMembers(String userId) async {
    final db = await database;
    final maps = await db.query(
      'household_members',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map(HouseholdMember.fromMap).toList();
  }

  Future<void> addMember(HouseholdMember member) async {
    final db = await database;
    await db.insert(
      'household_members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMember(String memberId) async {
    final db = await database;
    await db.delete(
      'household_members',
      where: 'id = ?',
      whereArgs: [memberId],
    );
  }

  Future<List<ResourceModel>> getResources(String userId) async {
    final db = await database;
    final maps = await db.query(
      'resources',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map(ResourceModel.fromMap).toList();
  }

  Future<void> addResource(ResourceModel resource) async {
    final db = await database;
    await db.insert(
      'resources',
      resource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateResource(ResourceModel resource) async {
    final db = await database;
    await db.update(
      'resources',
      resource.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [resource.id, resource.userId],
    );
  }

  Future<void> deleteResource(String resourceId, String userId) async {
    final db = await database;
    await db.delete(
      'resource_usage',
      where: 'resourceId = ? AND userId = ?',
      whereArgs: [resourceId, userId],
    );
    await db.delete(
      'resources',
      where: 'id = ? AND userId = ?',
      whereArgs: [resourceId, userId],
    );
  }

  Future<String> addUsage(ResourceUsage usage) async {
    final db = await database;
    await db.insert(
      'resource_usage',
      usage.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return usage.id;
  }

  Future<List<ResourceUsage>> getUsageForResource(
    String resourceId,
    String userId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'resource_usage',
      where: 'resourceId = ? AND userId = ?',
      whereArgs: [resourceId, userId],
      orderBy: 'date ASC',
    );
    return maps.map(ResourceUsage.fromMap).toList();
  }

  Future<List<ResourceUsage>> getAllUsage(String userId) async {
    final db = await database;
    final maps = await db.query(
      'resource_usage',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map(ResourceUsage.fromMap).toList();
  }

  Future<List<Expense>> getExpenses(String userId) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<String> addExpense(Expense expense) async {
    final db = await database;
    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return expense.id;
  }

  Future<void> updateExpense(Expense expense) async {
    final db = await database;
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [expense.id, expense.userId],
    );
  }

  Future<void> deleteExpense(String id, String userId) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<List<InventoryItem>> getInventory(String userId) async {
    final db = await database;
    final maps = await db.query(
      'inventory_items',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map(InventoryItem.fromMap).toList();
  }

  Future<String> addInventoryItem(InventoryItem item) async {
    final db = await database;
    await db.insert(
      'inventory_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item.id;
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final db = await database;
    await db.update(
      'inventory_items',
      item.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [item.id, item.userId],
    );
  }

  Future<void> deleteInventoryItem(String id, String userId) async {
    final db = await database;
    await db.delete(
      'inventory_items',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<List<ReminderModel>> getReminders(String userId) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'dueDate ASC',
    );
    return maps.map(ReminderModel.fromMap).toList();
  }

  Future<String> addReminder(ReminderModel reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return reminder.id;
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    final db = await database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [reminder.id, reminder.userId],
    );
  }

  Future<void> deleteReminder(String id, String userId) async {
    final db = await database;
    await db.delete(
      'reminders',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> setSetting(String userId, String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'userId': userId,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String userId, String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'userId = ? AND key = ?',
      whereArgs: [userId, key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.delete('resource_usage', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('expenses', where: 'userId = ?', whereArgs: [userId]);
    await db.delete(
      'inventory_items',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    await db.delete('reminders', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('resources', where: 'userId = ?', whereArgs: [userId]);
    await db.delete(
      'household_members',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    await db.delete('settings', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<void> createDefaultResources(String userId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM resources WHERE userId = ?', [
        userId,
      ]),
    );
    if (count != null && count > 0) return;
    await _insertDefaultResources(db, userId);
  }

  Future<void> _insertDefaultResources(
    DatabaseExecutor db,
    String userId,
  ) async {
    final defaults = [
      ResourceModel(
        id: _generateId(),
        userId: userId,
        name: 'Electricity',
        category: 'Utility',
        unit: 'kWh',
        iconName: 'electric_bolt',
        color: '#F59E0B',
        createdAt: DateTime.now().toIso8601String(),
      ),
      ResourceModel(
        id: _generateId(),
        userId: userId,
        name: 'Water',
        category: 'Utility',
        unit: 'L',
        iconName: 'water_drop',
        color: '#3B82F6',
        createdAt: DateTime.now().toIso8601String(),
      ),
      ResourceModel(
        id: _generateId(),
        userId: userId,
        name: 'Gas',
        category: 'Utility',
        unit: 'kg',
        iconName: 'local_fire_department',
        color: '#EF4444',
        createdAt: DateTime.now().toIso8601String(),
      ),
      ResourceModel(
        id: _generateId(),
        userId: userId,
        name: 'Internet',
        category: 'Utility',
        unit: 'GB',
        iconName: 'wifi',
        color: '#8B5CF6',
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    for (final resource in defaults) {
      await db.insert(
        'resources',
        resource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  String _generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }
}
