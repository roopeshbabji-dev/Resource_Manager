import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const _defaultIterations = 25000;

  const PasswordHasher({this.iterations = _defaultIterations})
    : assert(iterations >= 1);

  final int iterations;

  Future<String> hash(String password, String salt) {
    final workFactor = iterations;
    return Isolate.run(() {
      final derived = pbkdf2Sha256(password, salt, workFactor);
      return 'pbkdf2-sha256:$workFactor:${base64Url.encode(derived).replaceAll('=', '')}';
    });
  }

  Future<bool> verify({
    required String password,
    required String salt,
    required String storedHash,
  }) async {
    if (storedHash.startsWith('pbkdf2-sha256:')) {
      final parts = storedHash.split(':');
      if (parts.length != 3) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1 || iterations > 1000000) {
        return false;
      }
      final derived = await Isolate.run(
        () => pbkdf2Sha256(password, salt, iterations),
      );
      final expected = parts[2].replaceAll('=', '');
      final actual = base64Url.encode(derived).replaceAll('=', '');
      return _constantTimeEquals(actual, expected);
    }

    final legacyHash = sha256
        .convert(utf8.encode('$password:$salt'))
        .toString();
    return _constantTimeEquals(legacyHash, storedHash);
  }
}

List<int> pbkdf2Sha256(String password, String salt, int iterations) {
  if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
  final hmac = Hmac(sha256, utf8.encode(password));
  final saltBytes = utf8.encode(salt);
  var current = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
  final derived = List<int>.of(current);

  for (var round = 1; round < iterations; round++) {
    current = hmac.convert(current).bytes;
    for (var index = 0; index < derived.length; index++) {
      derived[index] ^= current[index];
    }
  }
  return derived;
}

bool _constantTimeEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}
