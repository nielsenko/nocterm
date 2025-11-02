import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Run the logs command to stream logs from a running nocterm app
Future<void> runLogsCommand() async {
  try {
    // Read port from global log_port file
    final portFile = File(getLogPortPath());

    if (!await portFile.exists()) {
      stderr.writeln('Error: No nocterm app is running (log_port file not found)');
      stderr.writeln('Make sure a nocterm app is running in this directory.');
      exit(1);
    }

    final portString = await portFile.readAsString();
    final port = int.tryParse(portString.trim());

    if (port == null) {
      stderr.writeln('Error: Invalid port in log_port file: $portString');
      exit(1);
    }

    // Connect to WebSocket
    final url = 'ws://127.0.0.1:$port/logs';
    WebSocket? socket;

    try {
      socket = await WebSocket.connect(url);
    } catch (e) {
      stderr.writeln('Error: Failed to connect to log server at $url');
      stderr.writeln('The nocterm app may have exited. Details: $e');
      exit(1);
    }

    // Stream log messages to stdout
    try {
      await for (final message in socket) {
        try {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          final logMessage = json['message'] as String;

          // Note: message already includes timestamp from logger, so we just print it as-is
          stdout.writeln(logMessage);
        } catch (e) {
          // If JSON parsing fails, print raw message
          stderr.writeln('Warning: Failed to parse log message: $e');
          stdout.writeln(message);
        }
      }
    } catch (e) {
      // Connection closed or error reading
      if (e is! WebSocketException) {
        stderr.writeln('Connection closed: $e');
      }
    } finally {
      await socket.close();
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
