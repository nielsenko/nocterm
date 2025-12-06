import 'dart:io';
import 'dart:isolate';

import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;

Future<void> runCompileCommand({required String rawOutputPath}) async {
  final outputPath = p.canonicalize(rawOutputPath);

  if (!await Directory(outputPath).exists()) {
    print('Error: Output path does not exist: $outputPath');
    print('');
    print('Usage: nocterm compile [-o <output path>]');
    exit(1);
  }

  final cliLocation = switch (Platform.environment['NOCTERM_CLI_LOCATION']) {
    final String path => Uri.parse(path),
    _ => await Isolate.resolvePackageUri(Uri.parse('package:nocterm_cli/')),
  };

  // should be <path>/nocterm_cli/lib
  if (cliLocation == null) {
    throw Exception('Nocterm CLI package not found');
  }

  // get root of project
  final cliPath = Directory(cliLocation.path).parent.path;

  final bin = File(p.join(cliPath, 'bin', 'nocterm_cli.dart'));

  await ensureNoctermDirectoryExists();

  final noctermExe = getExePath();

  if (File(noctermExe) case final file when await file.exists()) {
    await file.delete();
  }

  final process = await Process.start('dart', [
    'compile',
    'exe',
    bin.path,
    '-o',
    getExePath(),
  ]);

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    print('Error: Failed to compile nocterm executable');
    exit(1);
  }

  final exePath = p.join(outputPath, 'nocterm');
  final exeFile = File(exePath);

  if (await exeFile.exists()) {
    await exeFile.delete();
  }

  final content = '''
#!/bin/bash

export NOCTERM_CLI_LOCATION="$cliLocation"

# Ensure the nocterm executable exists
if [ ! -f "$noctermExe" ]; then
  echo "Error: Nocterm executable not found at: $noctermExe"
  exit 1
fi

# Run the nocterm executable
$noctermExe "\${@}"

EXIT_CODE=\$?

# Ensure that the shell is restored to the default state
if [ \$EXIT_CODE -ne 0 ]; then
  $noctermExe restore-shell
fi

exit \$EXIT_CODE
''';

  await exeFile.writeAsString(content);

  final fileType = await Process.run('chmod', ['+x', exePath]);

  if (fileType.exitCode != 0) {
    print('Error: Failed to set permissions on nocterm executable');
    exit(1);
  }

  print('Nocterm executable compiled successfully to: $exePath');
  print('');
  print('Usage: ./${p.relative(exePath)} [arguments]');

  exit(exitCode);
}
