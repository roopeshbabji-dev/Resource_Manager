import 'package:flutter_test/flutter_test.dart';
import 'package:household/core/utils/password_hasher.dart';

void main() {
  test('PBKDF2-SHA256 matches a known test vector', () {
    final actual = pbkdf2Sha256('password', 'salt', 1);
    expect(
      actual.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
  });

  test(
    'PBKDF2 password hash verifies and rejects a different password',
    () async {
      const salt = 'a-random-per-account-salt';
      final hasher = const PasswordHasher(iterations: 1000);
      final hash = await hasher.hash('correct horse battery staple', salt);
      expect(
        await hasher.verify(
          password: 'correct horse battery staple',
          salt: salt,
          storedHash: hash,
        ),
        isTrue,
      );
      expect(
        await hasher.verify(
          password: 'incorrect password',
          salt: salt,
          storedHash: hash,
        ),
        isFalse,
      );
    },
  );
}
