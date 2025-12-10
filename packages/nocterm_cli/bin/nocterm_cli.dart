import 'dart:io';

import 'package:nocterm_cli/src/deps/args.dart';
import 'package:nocterm_cli/src/deps/fs.dart';
import 'package:nocterm_cli/src/deps/log.dart';
import 'package:nocterm_cli/src/runner.dart';
import 'package:nocterm_cli/utils/args.dart';
import 'package:nocterm_cli/utils/restore_terminal.dart';
import 'package:scoped_deps/scoped_deps.dart';

void main(List<String> arguments) async {
  runScoped(
    _run,
    values: {
      argsProvider.overrideWith(() => Args.parse(arguments)),
      logProvider,
      fsProvider,
    },
  );
}

Future<void> _run() async {
  try {
    exitCode = await Runner().run();
  } finally {
    restoreTerminal();
  }

  exit(exitCode);
}
