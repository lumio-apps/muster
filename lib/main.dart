import 'package:flutter/material.dart';

import 'config.dart';
import 'db.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/setup_page.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDb.open();
    final state = AppState(db);
    await state.load();
    runApp(MusterApp(state: state));
  } catch (e) {
    runApp(_FatalApp(message: '$e'));
  }
}

class MusterApp extends StatelessWidget {
  const MusterApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) =>
            state.setupDone ? Shell(state: state) : SetupPage(state: state),
      ),
    );
  }
}

class _FatalApp extends StatelessWidget {
  const _FatalApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: kRed),
                const SizedBox(height: 12),
                const Text(
                  'Muster could not open its data file.',
                  style: kTitle,
                ),
                const SizedBox(height: 8),
                SelectableText(message, style: kSubtle),
                const SizedBox(height: 8),
                const Text(
                  'Please close other copies of Muster and try again. '
                  'If the problem continues, write to $kSupportEmail.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
