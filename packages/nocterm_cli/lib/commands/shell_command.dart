import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

Future<void> runShellCommand() async {
  print('Starting nocterm shell server...');

  // Create global nocterm directory for this project
  await ensureNoctermDirectoryExists();

  // Create a Unix domain socket
  final socketPath = getShellSocketPath();
  final socketFile = File(socketPath);
  if (await socketFile.exists()) {
    await socketFile.delete(); // Remove stale socket
  }

  final server = await ServerSocket.bind(
    InternetAddress(socketPath, type: InternetAddressType.unix),
    0,
  );

  // Write socket path to handle file
  final handleFile = File(getShellHandlePath());
  await handleFile.writeAsString(socketPath);

  print('Shell server ready at: $socketPath');
  print('Waiting for nocterm app to connect...');
  print('Press Ctrl+C to stop the shell.');

  try {
    await for (final client in server) {
      print('\nNocterm app connected!');
      await _handleClient(client);
      print('\nNocterm app disconnected.');
    }
  } finally {
    await server.close();
    if (await handleFile.exists()) {
      await handleFile.delete();
    }
    if (await socketFile.exists()) {
      await socketFile.delete();
    }
  }
}

Future<void> _handleClient(Socket client) async {
  StreamSubscription? stdinSubscription;
  StreamSubscription? sigwinchSubscription;

  try {
    // Put terminal in raw mode to pass through all input
    stdin.echoMode = false;
    stdin.lineMode = false;

    // Send initial terminal size to client using a custom OSC sequence
    // Format: ESC ] 9999 ; <cols> ; <rows> BEL
    _sendTerminalSize(client);

    // Forward stdin to client app (input events)
    stdinSubscription = stdin.listen((data) {
      client.add(data);
    });

    // Forward client output to stdout (terminal rendering)
    final clientSubscription = client.listen(
      (data) {
        stdout.add(data);
      },
      onDone: () {
        // Client disconnected
      },
    );

    // Send terminal size changes to client on SIGWINCH
    if (Platform.isMacOS || Platform.isLinux) {
      sigwinchSubscription = ProcessSignal.sigwinch.watch().listen((_) {
        _sendTerminalSize(client);
      });
    }

    // Wait for client to disconnect
    await clientSubscription.asFuture();
  } finally {
    await stdinSubscription?.cancel();
    await sigwinchSubscription?.cancel();

    // Restore terminal mode
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {
      // Ignore errors when restoring terminal mode
    }
  }
}

/// Send terminal size to client using custom OSC sequence
/// Format: ESC ] 9999 ; <cols> ; <rows> BEL
void _sendTerminalSize(Socket client) {
  if (stdout.hasTerminal) {
    final cols = stdout.terminalColumns;
    final rows = stdout.terminalLines;

    // Use OSC 9999 as our custom sequence for terminal size
    // This won't interfere with normal terminal output
    final sizeSequence = '\x1b]9999;$cols;$rows\x07';
    client.add(sizeSequence.codeUnits);
  }
}
