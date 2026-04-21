import 'package:nocterm/nocterm.dart';

/// A widget that creates a repaint boundary for its subtree.
///
/// When a descendant of a `RepaintBoundary` marks itself dirty, the
/// paint-dirty walk stops at the boundary instead of continuing to the
/// root. The boundary caches its subtree in a sub-buffer on the first
/// paint and blits that cache on later frames, so an unchanged subtree
/// costs one cell copy per frame instead of a paint walk.
///
/// Wrap the content that stays still next to an animation, such as a
/// dashboard beside a spinner. Wrapping the ticking widget itself buys
/// nothing. Its cache is invalidated every frame, and nodes outside a
/// boundary repaint on every frame anyway.
///
/// The sub-buffer holds `width * height` cells and is rebuilt when the
/// boundary's size changes. See doc/repaint-boundary.md for when a
/// boundary costs more than it saves.
class RepaintBoundary extends SingleChildRenderObjectComponent {
  const RepaintBoundary({super.key, super.child});

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      RenderRepaintBoundary();
}

/// The render object backing [RepaintBoundary].
///
/// Caching, invalidation and blitting all happen in
/// `RenderObject.paintWithContext`. This class only declares the child
/// wiring and opts in via [isRepaintBoundary].
class RenderRepaintBoundary extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  @override
  bool get isRepaintBoundary => true;

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
      final childParentData = child!.parentData as BoxParentData;
      childParentData.offset = Offset.zero;
      size = child!.size;
    } else {
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    assert(
      offset.dx == 0 && offset.dy == 0,
      'paintWithContext paints a boundary into its own sub-buffer',
    );
    child?.paintWithContext(canvas, offset);
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return child!.hitTest(result, position: position);
  }
}
