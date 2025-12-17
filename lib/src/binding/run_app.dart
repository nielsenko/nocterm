import 'package:nocterm/nocterm.dart';

import 'run_app_stub.dart'
    if (dart.library.io) 'run_app_io.dart'
    if (dart.library.html) 'run_app_web.dart';

export 'screen_mode.dart';

/// Run a TUI application.
///
/// Automatically detects the platform:
/// - Native (Linux, macOS): Uses StdioBackend, checks for shell mode
/// - Web: Uses WebBackend with static bridge for WASM/JS apps
///
/// On native platforms, also checks for nocterm shell mode for IDE debugging.
///
/// [screenMode] controls how the TUI renders:
/// - [ScreenMode.alternateScreen] (default): Takes over the full terminal
/// - [ScreenMode.inline]: Renders inline, output stays in terminal history
///
/// [inlineExitBehavior] controls what happens when exiting inline mode:
/// - [InlineExitBehavior.preserve] (default): Leave content visible
/// - [InlineExitBehavior.clear]: Clear all rendered content
Future<void> runApp(
  Component app, {
  bool enableHotReload = true,
  ScreenMode screenMode = ScreenMode.alternateScreen,
  InlineExitBehavior inlineExitBehavior = InlineExitBehavior.preserve,
}) {
  return runAppImpl(
    app,
    enableHotReload: enableHotReload,
    screenMode: screenMode,
    inlineExitBehavior: inlineExitBehavior,
  );
}
