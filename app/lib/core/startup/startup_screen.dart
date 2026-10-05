import 'package:flutter/material.dart';
import '../../features/settings/settings_screen.dart';

/// Renders a first frame before awaiting native service initialization.
class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.initialize,
    required this.app,
    this.timeout = const Duration(seconds: 20),
  });
  final Future<void> Function() initialize;
  final Widget app;
  final Duration timeout;
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<void> _ready;
  Future<void>? _inFlight;
  @override
  void initState() {
    super.initState();
    _ready = _attempt();
  }

  Future<void> _attempt() {
    // A timeout does not cancel native initialization. Reuse an outstanding call.
    _inFlight ??= Future<void>.sync(widget.initialize).then(
      (_) {},
      onError: (Object e, StackTrace stack) {
        _inFlight = null;
        Error.throwWithStackTrace(e, stack);
      },
    );
    return _inFlight!.timeout(widget.timeout);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.app;
      }
      final failed = snapshot.hasError;
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('ぎゅっと'),
            actions: const [SettingsButton()],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!failed) const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    failed ? 'アプリを起動できませんでした' : '起動しています…',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (failed) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '通信状態を確認して、もう一度お試しください。\n改善しない場合は、画面の状態と端末名を運営へお知らせください。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        final attempt = _attempt();
                        setState(() { _ready = attempt; });
                      },
                      child: const Text('もう一度試す'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
