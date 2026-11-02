import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Password stretching rounds. Stored in the file, so it can be raised later.
const int kBackupIterations = 150000;

final List<int> _magic = utf8.encode('MUSTERBK1');
const int _saltLen = 16;
const int _nonceLen = 12;
const int _macLen = 16;

int get _headerLen => _magic.length + 4 + _saltLen + _nonceLen;

Future<SecretKey> _key(String password, List<int> salt, int iterations) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
}

/// File layout:
///   "MUSTERBK1" | iterations (4 bytes) | salt (16) | nonce (12)
///   | encrypted data | authentication tag (16)
/// Encryption is AES-256-GCM. The key comes from the password via
/// PBKDF2-HMAC-SHA256. Any change to the file makes decryption fail.
Future<Uint8List> encryptBytes(
  Uint8List data,
  String password, {
  int iterations = kBackupIterations,
}) async {
  final rnd = Random.secure();
  final salt = List<int>.generate(_saltLen, (_) => rnd.nextInt(256));
  final key = await _key(password, salt, iterations);
  final box = await AesGcm.with256bits().encrypt(data, secretKey: key);

  final out = BytesBuilder(copy: false);
  out.add(_magic);
  out.add([
    (iterations >> 24) & 0xFF,
    (iterations >> 16) & 0xFF,
    (iterations >> 8) & 0xFF,
    iterations & 0xFF,
  ]);
  out.add(salt);
  out.add(box.nonce);
  out.add(box.cipherText);
  out.add(box.mac.bytes);
  return out.takeBytes();
}

bool looksLikeBackup(Uint8List file) {
  if (file.length < _headerLen + _macLen) return false;
  for (var i = 0; i < _magic.length; i++) {
    if (file[i] != _magic[i]) return false;
  }
  return true;
}

/// Returns the decrypted bytes, or null if the password is wrong or the
/// file was changed. Throws [BackupException] if it is not a backup file.
Future<Uint8List?> decryptBytes(Uint8List file, String password) async {
  if (!looksLikeBackup(file)) {
    throw BackupException('This is not a Muster backup file.');
  }
  var o = _magic.length;
  final iterations =
      (file[o] << 24) | (file[o + 1] << 16) | (file[o + 2] << 8) | file[o + 3];
  o += 4;
  if (iterations < 1 || iterations > 5000000) {
    throw BackupException('This backup file is damaged.');
  }
  final salt = file.sublist(o, o + _saltLen);
  o += _saltLen;
  final nonce = file.sublist(o, o + _nonceLen);
  o += _nonceLen;
  final cipher = file.sublist(o, file.length - _macLen);
  final mac = file.sublist(file.length - _macLen);

  final key = await _key(password, salt, iterations);
  try {
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return Uint8List.fromList(plain);
  } on SecretBoxAuthenticationError {
    return null;
  }
}
