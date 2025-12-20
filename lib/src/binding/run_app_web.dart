import 'dart:async';

import 'package:nocterm/nocterm.dart'
    hide StdioBackend, SocketBackend, WebBackend;
import 'package:nocterm/src/backend/web_backend.dart';
import 'package:nocterm/src/backend/terminal.dart' as term;

import 'terminal_binding.dart';

/// Run a TUI application on web platform.
Future<void> runAppImpl(Component app, {bool enableHotReload = true}) async {
  final backend = WebBackend();
  final terminal = term.Terminal(backend);
  final binding = TerminalBinding(terminal);

  binding.initialize();
  binding.attachRootComponent(app);

  // Hot reload not supported on web
  // No log server on web

  await binding.runEventLoop();
}
