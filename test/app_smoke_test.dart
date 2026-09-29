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

  test('app state initialization loads unauthenticated state cleanly', () async {
    SharedPreferences.setMockInitialValues({});
    final database = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final state = AppState(database: database);

    await state.initialize();
    expect(state.isLoading, isFalse);
    expect(state.currentUser, isNull);
    await database.close();
  });
}
