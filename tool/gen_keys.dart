// Run ONCE: dart run tool/gen_keys.dart
//
// Prints a new Ed25519 key pair for signing updates.
//  * PRIVATE key  -> GitHub repo secret named UPDATE_SIGNING_KEY (never share)
//  * PUBLIC key   -> lib/config.dart  (kUpdatePublicKey)
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final algo = Ed25519();
  final pair = await algo.newKeyPair();
  final seed = await pair.extractPrivateKeyBytes();
  final pub = await pair.extractPublicKey();

  stdout.writeln('');
  stdout.writeln('PRIVATE KEY (GitHub secret UPDATE_SIGNING_KEY, keep secret):');
  stdout.writeln(base64Encode(seed));
  stdout.writeln('');
  stdout.writeln('PUBLIC KEY (paste into lib/config.dart as kUpdatePublicKey):');
  stdout.writeln(base64Encode(pub.bytes));
  stdout.writeln('');
  stdout.writeln('Keep a safe copy of the private key. If you lose it, old');
  stdout.writeln('installs cannot verify new updates and users must reinstall.');
}
