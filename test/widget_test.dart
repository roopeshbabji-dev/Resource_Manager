import 'package:flutter_test/flutter_test.dart';
import 'package:household/app/app_state.dart';
import 'package:household/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('household app state switches to authenticated user correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final database = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final state = AppState(database: database);

    await state.initialize();
    expect(state.currentUser, isNull);

    final result = await state.register(
      name: 'Test Owner',
      email: 'owner@test.com',
      password: 'password123',
    );
    expect(result, RegistrationResult.created);
    expect(state.currentUser, isNull);

    final loggedIn = await state.login(
      email: 'owner@test.com',
      password: 'password123',
    );
    expect(loggedIn, isTrue);
    expect(state.currentUser?.name, 'Test Owner');

    await database.close();
  });
}
