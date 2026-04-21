import 'dart:io';

import 'package:test/test.dart';

/// Regression lint for the RepaintBoundary plumbing.
///
/// `RenderObject.paintWithContext` is the dispatch hook that lets a
/// RepaintBoundary cache its subtree into a sub-buffer. Any call site
/// that invokes `.paint(...)` on another RenderObject directly bypasses
/// that hook and silently defeats caching for everything below it. See
/// `doc/repaint-boundary-design.md`, "Verified against source" §1.
///
/// This test walks `lib/src/` and fails on any `.paint(` call that is
/// not `super.paint(...)`. Variants like `child.paint(...)`,
/// `child!.paint(...)`, `firstChild.paint(...)`, and
/// `child.renderObject.paint(...)` (the ListView/Viewport variant that
/// the original pattern missed) are all caught by this single rule.
///
/// A legitimate non-child `paint` call (e.g. painting a detached
/// transient RenderObject that has no subtree) can be opted out with a
/// `// paint-dispatch-ignore: <reason>` comment somewhere in the same
/// call (same line, or any line of a formatter-wrapped multi-line
/// invocation up to its closing `);`).
void main() {
  test('no parent->child .paint(...) dispatch under lib/src/', () {
    final root = Directory('lib/src');
    expect(
      root.existsSync(),
      isTrue,
      reason: 'run this test from the package root',
    );

    final paintCallPattern = RegExp(r'\.paint\(');
    final offenders = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('///')) {
          continue;
        }
        if (!paintCallPattern.hasMatch(line)) continue;
        if (line.contains('super.paint(')) continue;
        // Scan the rest of the call for an opt-out marker. dart format may
        // wrap `foo.paint(canvas, offset); // paint-dispatch-ignore: ...`
        // across several lines when the full expression exceeds the column
        // limit, leaving the marker on the line with the closing `);`.
        if (_hasIgnoreMarkerInCall(lines, i)) continue;

        offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Found parent-to-child paint dispatch bypassing paintWithContext.\n'
          'Use `child!.paintWithContext(...)` (or the appropriate variant)\n'
          'instead, so RepaintBoundary caching can engage for this subtree.\n'
          'For an intentional non-child paint call, add a trailing\n'
          '`// paint-dispatch-ignore: <reason>` comment on the same line.\n\n'
          'Offenders:\n${offenders.join('\n')}',
    );
  });
}

/// Returns true if the `.paint(` call that starts on [startLine] of [lines]
/// contains a `paint-dispatch-ignore` marker on any line up to and including
/// the line with its matching `);`. Bounded scan - at most a small handful
/// of lines - so there's no pathological case for oddly-formatted files.
bool _hasIgnoreMarkerInCall(List<String> lines, int startLine) {
  var depth = 0;
  for (var j = startLine; j < lines.length && j < startLine + 20; j++) {
    final l = lines[j];
    if (l.contains('paint-dispatch-ignore')) return true;
    for (final ch in l.codeUnits) {
      if (ch == 0x28 /* '(' */) depth++;
      if (ch == 0x29 /* ')' */) depth--;
    }
    if (depth <= 0 && j > startLine) return false;
  }
  return false;
}
