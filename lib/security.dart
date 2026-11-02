import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const int kPinIterations = 50000;

String randomSalt() {
  final r = Random.secure();
  return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

Future<String> _hashNow(String secret, String saltBase64, int iterations) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final key = await pbkdf2.deriveKeyFromPassword(
    password: secret,
    nonce: base64Decode(saltBase64),
  );
  return base64Encode(await key.extractBytes());
}

/// Salted, deliberately slow hash of a PIN or recovery code.
/// It runs in the background so the window never freezes.
Future<String> hashSecret(
  String secret,
  String saltBase64, {
  int iterations = kPinIterations,
}) {
  return Isolate.run(() => _hashNow(secret, saltBase64, iterations));
}

const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Recovery code like "K7QM-2XVD-9HTR". Shown once when a PIN is set.
String generateRecoveryCode() {
  final r = Random.secure();
  final c = List<String>.generate(
    12,
    (_) => _alphabet[r.nextInt(_alphabet.length)],
  );
  return '${c.sublist(0, 4).join()}-${c.sublist(4, 8).join()}-'
      '${c.sublist(8).join()}';
}

/// Removes spaces and dashes and upper-cases, so the code can be typed freely.
String normalizeRecoveryCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
