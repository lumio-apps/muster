import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:muster/backup_crypto.dart';
import 'package:muster/security.dart';

void main() {
  final data = Uint8List.fromList(utf8.encode('workers, attendance, salary'));

  group('backup encryption', () {
    test('round trip with the right password', () async {
      final file = await encryptBytes(data, 'correct horse', iterations: 1000);
      expect(looksLikeBackup(file), isTrue);
      final plain = await decryptBytes(file, 'correct horse');
      expect(plain, data);
    });

    test('wrong password gives null', () async {
      final file = await encryptBytes(data, 'correct horse', iterations: 1000);
      expect(await decryptBytes(file, 'wrong password'), isNull);
    });

    test('a changed file is rejected', () async {
      final file = await encryptBytes(data, 'correct horse', iterations: 1000);
      file[file.length - 20] ^= 0xFF;
      expect(await decryptBytes(file, 'correct horse'), isNull);
    });

    test('data is not stored as plain text', () async {
      final file = await encryptBytes(data, 'correct horse', iterations: 1000);
      expect(utf8.decode(file, allowMalformed: true), isNot(contains('salary')));
    });

    test('other files are not accepted as backups', () async {
      final junk = Uint8List.fromList(List<int>.filled(200, 7));
      expect(looksLikeBackup(junk), isFalse);
      expect(
        () => decryptBytes(junk, 'x'),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('PIN and recovery code', () {
    test('same secret and salt gives the same hash', () async {
      final salt = randomSalt();
      final a = await hashSecret('1234', salt, iterations: 1000);
      final b = await hashSecret('1234', salt, iterations: 1000);
      final c = await hashSecret('1235', salt, iterations: 1000);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('different salts give different hashes', () async {
      final a = await hashSecret('1234', randomSalt(), iterations: 1000);
      final b = await hashSecret('1234', randomSalt(), iterations: 1000);
      expect(a, isNot(b));
    });

    test('recovery code format and normalising', () {
      final code = generateRecoveryCode();
      expect(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$').hasMatch(code),
          isTrue);
      expect(normalizeRecoveryCode(code.toLowerCase()), code.replaceAll('-', ''));
      expect(normalizeRecoveryCode(' k7qm 2xvd-9htr '), 'K7QM2XVD9HTR');
    });
  });
}
