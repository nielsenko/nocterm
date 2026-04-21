import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Demonstrates what a [RepaintBoundary] saves.
///
/// A spinner ticks every 80 ms next to a block of static content. The
/// spinner's setState rebuilds the whole tree, which paints every
/// frame. Wrapping the static block in a RepaintBoundary lets it paint
/// once into a sub-buffer and blit on later frames.
///
/// Press Ctrl+G to toggle the debug overlay and watch the `Paint:` row.
/// Press B to toggle the RepaintBoundary around the static block.
/// Press q or Esc to quit.
///
/// Wrapping the ticking widget instead does not help. Its cache is
/// invalidated every tick, so it pays paint plus blit, and the rest of
/// the tree still repaints. Wrap the part that stays still.
///
/// Run with: dart run example/repaint_boundary_demo.dart
void main() {
  runApp(const _RepaintBoundaryDemo());
}

class _RepaintBoundaryDemo extends StatefulComponent {
  const _RepaintBoundaryDemo();

  @override
  State<_RepaintBoundaryDemo> createState() => _RepaintBoundaryDemoState();
}

class _RepaintBoundaryDemoState extends State<_RepaintBoundaryDemo> {
  bool _withBoundary = true;
  int _frame = 0;
  Timer? _ticker;

  static const _spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => setState(() => _frame++),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final spinner = Row(
      children: [
        Text(
          _spinner[_frame % _spinner.length],
          style: const TextStyle(color: Colors.cyan),
        ),
        const SizedBox(width: 1),
        Text('tick ${_frame.toString().padLeft(4)}'),
      ],
    );

    // Expensive static content: bordered + filled "panels", each with
    // multiple Text rows. Borders + decorations cost real per-cell
    // paint work (border draws, alpha blends), so wrapping this in a
    // RepaintBoundary saves a lot more than wrapping plain text would.
    final staticBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int p = 0; p < 8; p++)
          Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.gray.withOpacity(0.08),
              border: BoxBorder.all(style: BoxBorderStyle.rounded),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel ${p + 1}: idle dashboard tile',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                for (int row = 0; row < 3; row++)
                  Text(
                    '  metric ${p * 3 + row}: ${(p + 1) * (row + 1) * 137}'
                    ' (idle panel filler)',
                    style: TextStyle(
                      color: row.isEven ? Colors.white : Colors.gray,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    // Everything that stays the same between ticks: header,
    // instructions, status indicator, and the 8 dashboard panels. One
    // RepaintBoundary around all of it leaves the spinner subtree and
    // the blit as the only paint work per frame.
    final staticUI = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RepaintBoundary demo',
          style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 1),
        const Text('Ctrl+G  toggle the debug overlay (watch the Paint row)'),
        const Text('B       toggle the RepaintBoundary around the static UI'),
        const Text('q/Esc   quit'),
        const SizedBox(height: 1),
        Row(
          children: [
            const Text('Static UI wrapped in RepaintBoundary: '),
            Text(
              _withBoundary ? 'YES' : 'NO',
              style: TextStyle(
                color: _withBoundary ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        staticBlock,
      ],
    );

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.character == 'b' || event.character == 'B') {
          setState(() => _withBoundary = !_withBoundary);
          return true;
        }
        if (event.character == 'q' ||
            event.character == 'Q' ||
            event.logicalKey == LogicalKey.escape) {
          shutdownApp();
          return true;
        }
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The spinner is the only thing that changes every tick. It
            // stays outside the boundary because wrapping a ticker would
            // invalidate the cache every frame.
            spinner,
            const SizedBox(height: 1),
            // Everything else: static between toggles, optionally
            // wrapped in a boundary so it paints once and blits on
            // every subsequent frame.
            _withBoundary ? RepaintBoundary(child: staticUI) : staticUI,
          ],
        ),
      ),
    );
  }
}
