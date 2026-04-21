import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/framework.dart';
import 'package:test/test.dart';

/// Unit tests for the RepaintBoundary plumbing on RenderObject.
///
/// These tests use minimal synthetic render objects to exercise the
/// `isRepaintBoundary` / `markNeedsPaint` short-circuit without
/// involving a full component tree.
///
/// See doc/repaint-boundary-design.md.
void main() {
  group('markNeedsPaint short-circuit at RepaintBoundary', () {
    test('stops propagation to parent', () {
      final owner = PipelineOwner();
      final parent = _SpyRenderObject();
      final boundary = _BoundaryRenderObject();

      parent.owner = owner;
      boundary.owner = owner;
      boundary.parent = parent;

      parent.markCount = 0;

      boundary.markNeedsPaint();

      // Boundary itself is dirty …
      expect(boundary.needsPaint, isTrue);
      // … but the parent was never notified.
      expect(
        parent.markCount,
        0,
        reason: 'markNeedsPaint should not walk past a RepaintBoundary',
      );
    });

    test('registers the boundary with the PipelineOwner', () {
      final owner = PipelineOwner();
      final boundary = _BoundaryRenderObject();
      boundary.owner = owner;

      // No ancestor yet - this is the root of the synthetic tree.
      expect(owner.hasNodesToPaint, isFalse);

      boundary.markNeedsPaint();

      expect(
        owner.hasNodesToPaint,
        isTrue,
        reason: 'boundary should register with the owner so the '
            'frame-skip check does not drop the frame',
      );
    });

    test('schedules a visual update even on repeat marks', () {
      final owner = PipelineOwner();
      int visualUpdateCount = 0;
      owner.onNeedsVisualUpdate = () => visualUpdateCount++;

      final boundary = _BoundaryRenderObject();
      boundary.owner = owner;

      boundary.markNeedsPaint();
      boundary.markNeedsPaint();

      // requestPaint only adds once, but markNeedsPaint should still
      // schedule a frame on every call so animation loops don't stall.
      expect(
        visualUpdateCount,
        greaterThanOrEqualTo(2),
        reason: 'repeat markNeedsPaint on a dirty boundary must still '
            'schedule a visual update',
      );
    });

    test('non-boundary propagates as before', () {
      final owner = PipelineOwner();
      final parent = _SpyRenderObject();
      final child = _LeafRenderObject();

      parent.owner = owner;
      child.owner = owner;
      child.parent = parent;

      parent.markCount = 0;

      child.markNeedsPaint();

      // Non-boundary child walks up to the parent.
      expect(parent.markCount, 1);
    });
  });

  group('isRepaintBoundary getter', () {
    test('defaults to false on plain RenderObject', () {
      final ro = _LeafRenderObject();
      expect(ro.isRepaintBoundary, isFalse);
    });

    test('is overridable', () {
      final boundary = _BoundaryRenderObject();
      expect(boundary.isRepaintBoundary, isTrue);
    });
  });
}

/// A render object that records how many times markNeedsPaint fires on it.
class _SpyRenderObject extends RenderObject {
  int markCount = 0;

  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 5));
  }

  @override
  void markNeedsPaint() {
    markCount++;
    super.markNeedsPaint();
  }
}

/// A leaf render object with a fixed size.
class _LeafRenderObject extends RenderObject {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(5, 1));
  }
}

/// A leaf render object that opts into the boundary short-circuit.
class _BoundaryRenderObject extends RenderObject {
  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    size = constraints.constrain(const Size(5, 1));
  }
}
