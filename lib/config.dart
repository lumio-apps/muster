/// App-wide constants.
const String kAppName = 'Muster';
const String kSupportEmail = 'aditym02@outlook.com';

/// GitHub repository that publishes releases (used by the in-app updater).
const String kGithubOwner = 'aditymishr098-collab';
const String kGithubRepo = 'muster';

/// Base64 public key used to verify update signatures.
/// Generate it once with: dart run tool/gen_keys.dart
const String kUpdatePublicKey = 'REPLACE_WITH_PUBLIC_KEY';
