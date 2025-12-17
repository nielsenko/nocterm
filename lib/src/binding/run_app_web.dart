import 'dart:async';

import 'package:nocterm/nocterm.dart'
    hide StdioBackend, SocketBackend, WebBackend;
import 'package:nocterm/src/backend/web_backend.dart';
import 'package:nocterm/src/backend/terminal.dart' as term;

/// Run a TUI application on web platform.
///
/// Note: Inline mode is not supported on web - always uses alternate screen behavior.
Future<void> runAppImpl(
  Component app, {
  bool enableHotReload = true,
  ScreenMode screenMode = ScreenMode.alternateScreen,
  InlineExitBehavior inlineExitBehavior = InlineExitBehavior.preserve,
}) async {
  // Web always uses alternate screen behavior (inline doesn't make sense in web context)
  final backend = WebBackend();
  final terminal = term.Terminal(backend);
  final binding = TerminalBinding(terminal);

  binding.initialize();
  binding.attachRootComponent(app);

  // Hot reload not supported on web
  // No log server on web

  await binding.runEventLoop();
}
