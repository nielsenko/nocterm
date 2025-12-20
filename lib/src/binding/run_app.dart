import 'package:nocterm/nocterm.dart';

import 'run_app_stub.dart'
    if (dart.library.io) 'run_app_io.dart'
    if (dart.library.html) 'run_app_web.dart';

/// Run a TUI application.
///
/// Automatically detects the platform:
/// - Native (Linux, macOS): Uses StdioBackend, checks for shell mode
/// - Web: Uses WebBackend with static bridge for WASM/JS apps
///
/// On native platforms, also checks for nocterm shell mode for IDE debugging.
Future<void> runApp(Component app, {bool enableHotReload = true}) {
  return runAppImpl(app, enableHotReload: enableHotReload);
}
