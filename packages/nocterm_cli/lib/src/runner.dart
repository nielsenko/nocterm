import 'package:nocterm_cli/src/commands/logs_command.dart';
import 'package:nocterm_cli/src/commands/run_command.dart';
import 'package:nocterm_cli/src/commands/shell_command.dart';
import 'package:nocterm_cli/src/deps/args.dart';
import 'package:nocterm_cli/src/deps/log.dart';

const _usage = '''
nocterm CLI - Tools for nocterm TUI framework

Usage: nocterm <command> [arguments]

Available commands:
  shell    Start a nocterm shell server for debugging
  logs     Stream logs from a running nocterm app
  run      Run a Dart script with VM service enabled

Run "nocterm <command> --help" for more information about a command.
''';

class Runner {
  const Runner();

  Future<int> run() async {
    try {
      if (args.path.isEmpty) {
        log(_usage);
        return 1;
      }

      switch (args.path) {
        case ['shell']:
          return ShellCommand().run();

        case ['logs']:
          return LogsCommand().run();

        case ['run']:
          return RunCommand().run();

        default:
          log(_usage);
          return 1;
      }
    } on FormatException catch (e) {
      log('Error: ${e.message}');
      log('');
      log(_usage);
      return 1;
    }
  }
}
