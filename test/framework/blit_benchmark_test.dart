@Tags(['benchmark'])
library;

import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:test/test.dart';

/// Hand-rolled micro-benchmark: blit vs equivalent drawText for a
/// 80x40 buffer. Not run as part of the default suite (tagged
/// `benchmark`); invoke with `dart test -t benchmark` to print
/// numbers.
void main() {
  const width = 80;
  const height = 40;
  const iterations = 200;

  test('blit vs drawText for $width*$height', () {
    // Pre-fill the source buffer with 'X' so each cell has content
    // (mirrors a realistic "static block" cache).
    final src = Buffer(width, height);
    for (int y = 0; y < height; y++) {
      src.setString(0, y, 'X' * width);
    }

    // Warm up.
    for (int i = 0; i < 10; i++) {
      final dst = Buffer(width, height);
      final canvas = TerminalCanvas(
        dst,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );
      canvas.blitBuffer(src, Offset.zero);
    }

    // Time blit.
    final blitStopwatch = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      final dst = Buffer(width, height);
      final canvas = TerminalCanvas(
        dst,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );
      canvas.blitBuffer(src, Offset.zero);
    }
    blitStopwatch.stop();

    // Time equivalent drawText.
    final drawStopwatch = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      final dst = Buffer(width, height);
      final canvas = TerminalCanvas(
        dst,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );
      for (int y = 0; y < height; y++) {
        canvas.drawText(Offset(0, y.toDouble()), 'X' * width);
      }
    }
    drawStopwatch.stop();

    final blitMicros = blitStopwatch.elapsedMicroseconds / iterations;
    final drawMicros = drawStopwatch.elapsedMicroseconds / iterations;
    final ratio = drawMicros / blitMicros;

    // ignore: avoid_print
    print('blit:     ${blitMicros.toStringAsFixed(1)} µs/frame');
    // ignore: avoid_print
    print('drawText: ${drawMicros.toStringAsFixed(1)} µs/frame');
    // ignore: avoid_print
    print('blit is ${ratio.toStringAsFixed(1)}* faster');
  });
}
