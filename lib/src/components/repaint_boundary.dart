import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// A widget that creates a repaint boundary for its subtree.
///
/// When any descendant of a `RepaintBoundary` marks itself dirty, the
/// paint-dirty propagation stops at the boundary instead of walking to
/// the root. The boundary caches its subtree into a sub-buffer on the
/// first paint and blits that cache on subsequent frames - so
/// unchanged subtrees cost one cell-copy per frame rather than a full
/// paint walk.
///
/// Useful around isolated animation hotspots (spinners, progress
/// indicators) inside an otherwise idle screen.
///
/// The sub-buffer allocates `width * height` cells on the first paint
/// and whenever the boundary's size changes at layout time. Wrapping
/// very small widgets or whole-screen regions can cost more than it
/// saves; measure with the performance overlay before committing.
class RepaintBoundary extends SingleChildRenderObjectComponent {
  const RepaintBoundary({super.key, super.child});

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      RenderRepaintBoundary();
}

/// The render object backing [RepaintBoundary].
///
/// Caching, invalidation and blitting all happen in
/// `RenderObject.paintWithContext` - this class only declares the
/// child wiring and opts into the boundary behavior via
/// [isRepaintBoundary].
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
    // Called by RenderObject.paintWithContext INTO the sub-buffer when
    // the cache is dirty. The sub-canvas passes `offset == Offset.zero`
    // for us; for non-cached dispatch (never hit in practice because
    // isRepaintBoundary is always true) the offset is passed through.
    if (child != null) {
      child!.paintWithContext(canvas, offset);
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return child!.hitTest(result, position: position);
  }
}
