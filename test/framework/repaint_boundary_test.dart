import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/buffer.dart';
import 'package:nocterm/src/framework/framework.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:nocterm/src/rectangle.dart';
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

  group('TerminalCanvas.blitBuffer', () {
    test('copies cells at offset', () {
      final dest = Buffer(10, 4);
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(0, 0, 10, 4));

      final src = Buffer(3, 2);
      src.setString(0, 0, 'AB');
      src.setString(0, 1, 'CD');

      canvas.blitBuffer(src, const Offset(2, 1));

      expect(dest.getCell(2, 1).char, 'A');
      expect(dest.getCell(3, 1).char, 'B');
      expect(dest.getCell(2, 2).char, 'C');
      expect(dest.getCell(3, 2).char, 'D');
      // Cells outside the blit rectangle stay empty.
      expect(dest.getCell(0, 0).char, ' ');
      expect(dest.getCell(5, 3).char, ' ');
    });

    test('respects the canvas clip area (top-left origin)', () {
      final dest = Buffer(20, 10);
      // Canvas clipped to the 4x3 region at (5, 2).
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(5, 2, 4, 3));

      final src = Buffer(4, 3);
      for (int y = 0; y < 3; y++) {
        src.setString(0, y, 'XXXX');
      }

      canvas.blitBuffer(src, Offset.zero);

      // Inside the clipped region.
      expect(dest.getCell(5, 2).char, 'X');
      expect(dest.getCell(8, 4).char, 'X');
      // Just outside.
      expect(dest.getCell(4, 2).char, ' ');
      expect(dest.getCell(9, 2).char, ' ');
      expect(dest.getCell(5, 5).char, ' ');
    });

    test('clips cells that would fall outside the canvas area', () {
      final dest = Buffer(10, 5);
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(0, 0, 5, 3));

      final src = Buffer(10, 10);
      for (int y = 0; y < 10; y++) {
        src.setString(0, y, '##########');
      }

      canvas.blitBuffer(src, Offset.zero);

      // Inside the clipped area: visible.
      expect(dest.getCell(0, 0).char, '#');
      expect(dest.getCell(4, 2).char, '#');
      // Outside the clipped area: unchanged.
      expect(dest.getCell(5, 0).char, ' ');
      expect(dest.getCell(0, 3).char, ' ');
    });

    test('translates pending sixel images by canvas + offset', () {
      final dest = Buffer(30, 20);
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(4, 3, 20, 10));

      final src = Buffer(10, 5);
      src.pendingImages.add(
        const PendingImage(x: 1, y: 2, width: 3, height: 2, sixelData: 'SIXEL'),
      );

      canvas.blitBuffer(src, const Offset(6, 1));

      expect(dest.pendingImages, hasLength(1));
      final translated = dest.pendingImages.single;
      expect(translated.x, 1 + 4 + 6);
      expect(translated.y, 2 + 3 + 1);
      expect(translated.width, 3);
      expect(translated.height, 2);
      expect(translated.sixelData, 'SIXEL');
    });

    test('preserves wide-character + zero-width continuation pair', () {
      final dest = Buffer(10, 1);
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(0, 0, 10, 1));

      final src = Buffer(4, 1);
      // Emoji takes 2 cells; setString writes a ZWSP marker in cell 1.
      src.setString(0, 0, 'A\u{1F600}B');

      canvas.blitBuffer(src, Offset.zero);

      expect(dest.getCell(0, 0).char, 'A');
      expect(dest.getCell(1, 0).char, '\u{1F600}');
      expect(dest.getCell(2, 0).char, '\u200B');
      expect(dest.getCell(3, 0).char, 'B');
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
