import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:test/test.dart';

/// Counts paints by wrapping a child and incrementing in its render
/// object's paint(). Implemented as a SingleChildRenderObjectComponent
/// because nocterm has no leaf-render-object component base.
class _PaintCountingBox extends SingleChildRenderObjectComponent {
  const _PaintCountingBox({required this.onPaint, super.child});

  final void Function() onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintCountingBox(onPaint);

  @override
  void updateRenderObject(BuildContext context, _RenderPaintCountingBox r) {
    r.onPaint = onPaint;
  }
}

class _RenderPaintCountingBox extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  _RenderPaintCountingBox(this.onPaint);

  void Function() onPaint;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = child!.size;
    } else {
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    onPaint();
    if (child != null) child!.paintWithContext(canvas, offset);
  }
}

class _TickerWithStaticBoundary extends StatefulComponent {
  const _TickerWithStaticBoundary();

  @override
  State<_TickerWithStaticBoundary> createState() =>
      _TickerWithStaticBoundaryState();
}

class _TickerWithStaticBoundaryState extends State<_TickerWithStaticBoundary> {
  int _frame = 0;
  int staticPaintCount = 0;

  void tick() => setState(() => _frame++);

  @override
  Component build(BuildContext context) {
    return Column(
      children: [
        Text('tick $_frame'),
        RepaintBoundary(
          child: _PaintCountingBox(
            onPaint: () => staticPaintCount++,
            child: const Text('static'),
          ),
        ),
      ],
    );
  }
}

class _SwappingLabel extends StatefulComponent {
  const _SwappingLabel();

  @override
  State<_SwappingLabel> createState() => _SwappingLabelState();
}

class _SwappingLabelState extends State<_SwappingLabel> {
  String _text = 'before';

  void updateText(String value) => setState(() => _text = value);

  @override
  Component build(BuildContext context) {
    return RepaintBoundary(child: Text(_text));
  }
}

void main() {
  group('RepaintBoundary widget', () {
    test('renders its child', () async {
      await testNocterm('repaint boundary smoke', (tester) async {
        await tester.pumpComponent(
          const Center(child: RepaintBoundary(child: Text('Hello'))),
        );
        expect(tester.terminalState.getText(), contains('Hello'));
      }, size: const Size(40, 5));
    });

    test('descendant setState invalidates the cache', () async {
      // A descendant rebuild must reach the boundary's cache via
      // markNeedsPaint on the child render objects. If the boundary
      // failed to see the dirty flag, the second pump would still show
      // the stale "before" text.
      await testNocterm(
        'repaint boundary invalidation via descendant setState',
        (tester) async {
          await tester.pumpComponent(const _SwappingLabel());
          expect(tester.terminalState.getText(), contains('before'));

          final state = tester.findState<_SwappingLabelState>();
          state.updateText('after');
          await tester.pump();

          final output = tester.terminalState.getText();
          expect(output, contains('after'));
          expect(output, isNot(contains('before')));
        },
        size: const Size(40, 5),
      );
    });

    test(
      'static subtree under a boundary skips paint when sibling ticks',
      () async {
        // Pins the perf claim: a RepaintBoundary around static content
        // is NOT re-painted when an unwrapped sibling rebuilds. If this
        // test starts failing (the static block paints again on every
        // tick), the boundary mechanism is broken even if the unit
        // tests still pass.
        await testNocterm('boundary skips paint for static sibling', (
          tester,
        ) async {
          await tester.pumpComponent(const _TickerWithStaticBoundary());
          final state = tester.findState<_TickerWithStaticBoundaryState>();
          final initialStaticPaints = state.staticPaintCount;
          expect(
            initialStaticPaints,
            greaterThan(0),
            reason: 'static block should paint at least once',
          );

          // Tick the unwrapped sibling several times.
          for (int i = 0; i < 5; i++) {
            state.tick();
            await tester.pump();
          }

          expect(
            state.staticPaintCount,
            initialStaticPaints,
            reason: 'static subtree under a RepaintBoundary must NOT '
                're-paint when an unwrapped sibling triggers a rebuild',
          );
        }, size: const Size(40, 10));
      },
    );

    test('child stays visible across pumps', () async {
      await testNocterm('repaint boundary persistence', (tester) async {
        await tester.pumpComponent(
          const RepaintBoundary(child: Text('Cached')),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.terminalState.getText(), contains('Cached'));
      }, size: const Size(40, 5));
    });
  });
}
