import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Demonstrates [RepaintBoundary] performance behavior.
///
/// A spinner ticks every 80 ms next to a block of static content. The
/// spinner's setState rebuilds the whole tree, which paints every
/// frame. Wrapping the **static block** in a RepaintBoundary lets it
/// paint once into a sub-buffer and blit on subsequent frames - the
/// boundary protects the part that does NOT change.
///
/// Press **Ctrl+G** to toggle the debug overlay and watch the
/// `Paint:` row.
/// Press **B** to toggle the RepaintBoundary around the static block.
/// Press **q** or **Esc** to quit.
///
/// Common pitfall (worth knowing): wrapping the *ticking* widget in a
/// RepaintBoundary does not help - the cache is invalidated every
/// tick, so you pay allocation + paint + blit instead of just paint.
/// Wrap the part that stays still.
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
                  'Panel ${p + 1} - idle dashboard tile',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                for (int row = 0; row < 3; row++)
                  Text(
                    '  metric ${p * 3 + row}: ${(p + 1) * (row + 1) * 137}'
                    '  - pretend this is a non-trivial idle UI panel',
                    style: TextStyle(
                      color: row.isEven ? Colors.white : Colors.gray,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    // Everything that does NOT change between ticks: header,
    // instructions, status indicator, and the 8 dashboard panels.
    // Wrapping ALL of this in a single RepaintBoundary means the
    // only paint work each frame is the spinner subtree + the blit.
    final staticUI = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RepaintBoundary demo',
          style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 1),
        const Text('Ctrl+G - toggle debug overlay (watch the Paint: row)'),
        const Text('B      - toggle RepaintBoundary around the static UI'),
        const Text('q/Esc  - quit'),
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
            // The ONLY thing that changes every tick: the spinner.
            // Kept outside the boundary because wrapping a ticker
            // would just invalidate the cache every frame.
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
