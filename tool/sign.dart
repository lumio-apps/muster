// Used by the release workflow:
//   dart run tool/sign.dart <file.zip>
// Reads the private key from env UPDATE_SIGNING_KEY and writes <file.zip>.sig
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/sign.dart <file>');
    exit(64);
  }
  final key = Platform.environment['UPDATE_SIGNING_KEY'];
  if (key == null || key.trim().isEmpty) {
    stderr.writeln('UPDATE_SIGNING_KEY is not set.');
    exit(65);
  }

  final file = File(args.first);
  final data = await file.readAsBytes();
  final algo = Ed25519();
  final pair = await algo.newKeyPairFromSeed(base64Decode(key.trim()));
  final sig = await algo.sign(data, keyPair: pair);

  await File('${args.first}.sig').writeAsString(base64Encode(sig.bytes));
  stdout.writeln('Signed ${args.first}');
}
