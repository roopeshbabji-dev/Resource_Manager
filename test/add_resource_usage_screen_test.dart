import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household/app/app_state.dart';
import 'package:household/core/utils/password_hasher.dart';
import 'package:household/database/database_helper.dart';
import 'package:household/features/resources/resources_screen.dart';
import 'package:household/models/models.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('ResourceModel equality compares by id', () {
    final r1 = ResourceModel(
      id: 'res-1',
      userId: 'user-1',
      name: 'Electricity',
      category: 'Utility',
      unit: 'kWh',
      iconName: 'bolt',
      color: '#FFA000',
      createdAt: '2026-01-01',
    );
    final r2 = ResourceModel(
      id: 'res-1',
      userId: 'user-1',
      name: 'Electricity',
      category: 'Utility',
      unit: 'kWh',
      iconName: 'bolt',
      color: '#FFA000',
      createdAt: '2026-01-01',
    );
    expect(identical(r1, r2), isFalse);
    expect(r1 == r2, isTrue);
    expect(r1.hashCode, equals(r2.hashCode));
  });

  testWidgets(
    'AddResourceUsageScreen renders and selects initialResource without assertion error',
    (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        final database = DatabaseHelper.forTesting(inMemoryDatabasePath);
        final testHasher = const PasswordHasher(iterations: 1000);
        final state = AppState(database: database, passwordHasher: testHasher);

        await state.initialize();
        await state.register(
          name: 'User',
          email: 'user@test.com',
          password: 'password123',
        );
        await state.login(email: 'user@test.com', password: 'password123');

        final resources = await state.getResources();
        expect(resources, isNotEmpty);
        final firstResource = resources.first;

        // Create a separate instance with the same ID, simulating passing from previous screen
        final passedResource = ResourceModel(
          id: firstResource.id,
          userId: firstResource.userId,
          name: firstResource.name,
          category: firstResource.category,
          unit: firstResource.unit,
          iconName: firstResource.iconName,
          color: firstResource.color,
          createdAt: firstResource.createdAt,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              home: AddResourceUsageScreen(initialResource: passedResource),
            ),
          ),
        );

        // Allow async _loadResources to finish loading from sqflite
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // No assertion failure should occur, and dropdown should be displayed with resource name
        expect(find.text('Log usage'), findsOneWidget);
        expect(find.text(firstResource.name), findsOneWidget);
        expect(
          find.byType(DropdownButtonFormField<ResourceModel>),
          findsOneWidget,
        );

        await database.close();
      });
    },
  );
}

