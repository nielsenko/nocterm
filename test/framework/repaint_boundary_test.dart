import 'package:nocterm/nocterm.dart';
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

      // No ancestor. This boundary is the root of the synthetic tree.
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

    test('drops a wide glyph whose second column is clipped', () {
      final dest = Buffer(10, 1);
      dest.setString(0, 0, '..........');
      // Clip to columns 0..2; the emoji at source column 2 would spill
      // into column 3.
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(0, 0, 3, 1));
      final src = Buffer(5, 1);
      src.setString(0, 0, 'AB\u{1F600}C');

      canvas.blitBuffer(src, Offset.zero);

      expect(dest.getCell(0, 0).char, 'A');
      expect(dest.getCell(1, 0).char, 'B');
      expect(dest.getCell(2, 0).char, '.');
      expect(dest.getCell(3, 0).char, '.');
    });

    test('drops a continuation marker whose glyph is clipped', () {
      final dest = Buffer(10, 1);
      dest.setString(0, 0, '..........');
      // Clip starts at column 2; the emoji at source column 1 is outside
      // and its marker at source column 2 must not land in the clip.
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(2, 0, 5, 1));
      final src = Buffer(5, 1);
      src.setString(0, 0, 'A\u{1F600}B');

      canvas.blitBuffer(src, const Offset(-2, 0));

      expect(dest.getCell(2, 0).char, '.');
      expect(dest.getCell(3, 0).char, 'B');
    });

    test('crops a pending image to the clip area', () {
      final dest = Buffer(20, 10);
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(0, 2, 20, 4));
      final src = Buffer(10, 10);
      src.pendingImages.add(
        const PendingImage(x: 1, y: 0, width: 4, height: 6, sixelData: 'S'),
      );

      canvas.blitBuffer(src, const Offset(0, -1));

      // Source rows 0..6 land on buffer rows 1..7; the clip keeps 2..6.
      final img = dest.pendingImages.single;
      expect(img.x, 1);
      expect(img.y, 2);
      expect(img.width, 4);
      expect(img.height, 4);
    });

    test('drops a pending image outside the clip area', () {
      final dest = Buffer(20, 10);
      final canvas = TerminalCanvas(dest, Rect.fromLTWH(0, 5, 20, 5));
      final src = Buffer(10, 10);
      src.pendingImages.add(
        const PendingImage(x: 0, y: 0, width: 2, height: 2, sixelData: 'S'),
      );

      canvas.blitBuffer(src, const Offset(0, -3));

      expect(dest.pendingImages, hasLength(0));
    });

    test('leaves the destination untouched under unpainted cells', () {
      final dest = Buffer(4, 1);
      dest.setString(0, 0, 'abcd');
      final src = Buffer.transparent(4, 1);
      src.setString(1, 0, 'X');

      TerminalCanvas(dest, Rect.fromLTWH(0, 0, 4, 1))
          .blitBuffer(src, Offset.zero);

      expect(dest.getCell(0, 0).char, 'a');
      expect(dest.getCell(1, 0).char, 'X');
      expect(dest.getCell(2, 0).char, 'c');
      expect(dest.getCell(3, 0).char, 'd');
    });

    test('keeps the destination background under a cell painted without one',
        () {
      final dest = Buffer(4, 1);
      final destCanvas = TerminalCanvas(dest, Rect.fromLTWH(0, 0, 4, 1));
      destCanvas.fillRect(
        Rect.fromLTWH(0, 0, 4, 1),
        ' ',
        style: const TextStyle(backgroundColor: Colors.blue),
      );
      final src = Buffer.transparent(4, 1);
      TerminalCanvas(src, Rect.fromLTWH(0, 0, 4, 1)).drawText(
        Offset.zero,
        'X',
        style: const TextStyle(color: Colors.red),
      );

      destCanvas.blitBuffer(src, Offset.zero);

      final cell = dest.getCell(0, 0);
      expect(cell.char, 'X');
      expect(cell.style.color, Colors.red);
      expect(cell.style.backgroundColor, Colors.blue);
    });

    test('blends a translucent background over the destination', () {
      const under = Color.fromRGB(0, 0, 200);
      final tint = const Color.fromRGB(255, 255, 255).withOpacity(0.5);
      final dest = Buffer(1, 1);
      final destCanvas = TerminalCanvas(dest, Rect.fromLTWH(0, 0, 1, 1));
      destCanvas.fillRect(
        Rect.fromLTWH(0, 0, 1, 1),
        ' ',
        style: const TextStyle(backgroundColor: under),
      );
      final src = Buffer.transparent(1, 1);
      TerminalCanvas(src, Rect.fromLTWH(0, 0, 1, 1)).fillRect(
        Rect.fromLTWH(0, 0, 1, 1),
        ' ',
        style: TextStyle(backgroundColor: tint),
      );

      destCanvas.blitBuffer(src, Offset.zero);

      expect(
        dest.getCell(0, 0).style.backgroundColor,
        Color.alphaBlend(tint, under),
      );
    });
  });

  group('paintWithContext boundary cache', () {
    test('caches after the first paint and blits on subsequent frames', () {
      final boundary = _CountingBoundary();
      boundary.layout(BoxConstraints.tight(const Size(4, 2)));

      final parentBuffer = Buffer(10, 5);
      final canvas = TerminalCanvas(parentBuffer, Rect.fromLTWH(0, 0, 10, 5));

      boundary.paintWithContext(canvas, const Offset(1, 1));
      expect(boundary.paintCount, 1);
      expect(parentBuffer.getCell(1, 1).char, 'X');

      // Second paint while clean. paint() must not run again, but the
      // cached buffer still blits.
      parentBuffer.setCell(1, 1, Cell());
      boundary.paintWithContext(canvas, const Offset(1, 1));
      expect(boundary.paintCount, 1, reason: 'cache hit, no repaint');
      expect(
        parentBuffer.getCell(1, 1).char,
        'X',
        reason: 'cached sub-buffer was blitted',
      );
    });

    test('markNeedsPaint invalidates the cache', () {
      final boundary = _CountingBoundary();
      boundary.layout(BoxConstraints.tight(const Size(4, 2)));
      final canvas = TerminalCanvas(Buffer(10, 5), Rect.fromLTWH(0, 0, 10, 5));

      boundary.paintWithContext(canvas, Offset.zero);
      boundary.markNeedsPaint();
      boundary.paintWithContext(canvas, Offset.zero);

      expect(boundary.paintCount, 2);
    });

    test('size change invalidates the cache at layout time', () {
      final boundary = _CountingBoundary();
      boundary.layout(BoxConstraints.tight(const Size(4, 2)));
      final canvas = TerminalCanvas(Buffer(10, 5), Rect.fromLTWH(0, 0, 10, 5));

      boundary.paintWithContext(canvas, Offset.zero);
      expect(boundary.paintCount, 1);

      // Re-layout at a different size.
      boundary.paintSize = const Size(6, 3);
      boundary.markNeedsLayout();
      boundary.layout(BoxConstraints.tight(const Size(6, 3)));

      boundary.paintWithContext(canvas, Offset.zero);
      expect(boundary.paintCount, 2);
    });

    test('relayout with new constraints repaints the cache', () {
      final boundary = _CountingBoundary();
      boundary.layout(BoxConstraints.tight(const Size(4, 2)));
      final canvas = TerminalCanvas(Buffer(10, 5), Rect.fromLTWH(0, 0, 10, 5));

      boundary.paintWithContext(canvas, Offset.zero);
      expect(boundary.paintCount, 1);

      // Same resulting size, different constraints: performLayout ran.
      boundary.layout(const BoxConstraints(maxWidth: 4, maxHeight: 2));
      boundary.paintWithContext(canvas, Offset.zero);
      expect(boundary.paintCount, 2);
    });

    test('a layout error under the boundary does not pin the cache', () {
      final child = _FlakyLayoutChild();
      final boundary = RenderRepaintBoundary()..child = child;
      final buffer = Buffer(40, 10);
      final canvas = TerminalCanvas(buffer, Rect.fromLTWH(0, 0, 40, 10));

      child.markNeedsLayout();
      boundary.layout(BoxConstraints.tight(const Size(40, 10)));
      boundary.paintWithContext(canvas, Offset.zero);
      expect(_bufferText(buffer), contains('Layout Error'));
      expect(child.needsPaint, isFalse);

      child.markNeedsPaint();
      expect(
        boundary.needsPaint,
        isTrue,
        reason: 'a mark below the error box must still reach the boundary',
      );

      // Same boundary size, different constraints: the child lays out
      // again and succeeds this time.
      boundary.layout(const BoxConstraints(maxWidth: 40, maxHeight: 10));
      buffer.clear();
      boundary.paintWithContext(canvas, Offset.zero);
      final text = _bufferText(buffer);
      expect(text, contains('OK'));
      expect(text, isNot(contains('Layout Error')));
    });

    test('a paint override that skips super.paint fails an assert', () {
      final node = _ForgetfulLeaf();
      node.layout(BoxConstraints.tight(const Size(4, 2)));
      node.markNeedsPaint();
      final canvas = TerminalCanvas(Buffer(10, 5), Rect.fromLTWH(0, 0, 10, 5));

      expect(
        () => node.paintWithContext(canvas, Offset.zero),
        throwsA(isA<AssertionError>()),
      );
    });

    test('offset-only change reuses the cache', () {
      final boundary = _CountingBoundary();
      boundary.layout(BoxConstraints.tight(const Size(4, 2)));
      final buffer = Buffer(10, 5);
      final canvas = TerminalCanvas(buffer, Rect.fromLTWH(0, 0, 10, 5));

      boundary.paintWithContext(canvas, const Offset(0, 0));
      expect(boundary.paintCount, 1);
      expect(buffer.getCell(0, 0).char, 'X');

      // Same boundary, no size change, different offset.
      boundary.paintWithContext(canvas, const Offset(5, 3));
      expect(boundary.paintCount, 1, reason: 'cache reused for offset change');
      expect(
        buffer.getCell(5, 3).char,
        'X',
        reason: 'cached sub-buffer blitted at the new offset',
      );
    });
  });

  group('markNeedsLayout cascade', () {
    test('markNeedsLayout still cascades paint-dirty through ancestors', () {
      // RepaintBoundary is a paint boundary, not a relayout boundary.
      // When a layout actually changes, ancestors' sizes/positions may
      // change too, so their paint must re-run. The cascade is expected.
      // This test pins that expectation so a future "contain
      // markNeedsLayout too" change would be caught.
      final owner = PipelineOwner();
      final grandparent = _SpyRenderObject();
      final boundary = _BoundaryRenderObject();
      final child = _LeafRenderObject();

      grandparent.owner = owner;
      boundary.owner = owner;
      child.owner = owner;
      boundary.parent = grandparent;
      child.parent = boundary;

      grandparent.markCount = 0;

      child.markNeedsLayout();

      // markNeedsLayout cascades via parent?.markNeedsLayout(), and
      // markNeedsLayout itself calls markNeedsPaint() on every node on
      // the way up. So grandparent DOES get a paint mark.
      expect(
        grandparent.markCount,
        greaterThan(0),
        reason: 'markNeedsLayout must propagate paint dirtying to '
            'ancestors, because a relayout may resize them',
      );
    });
  });

  group('frame-skip interaction', () {
    test('boundary-scoped dirty keeps hasNodesToPaint truthy', () {
      // terminal_binding._drawFrameCallback consults
      // pipelineOwner.hasNodesToPaint to decide whether to skip a frame.
      // After the markNeedsPaint short-circuit, a descendant dirtying
      // under a boundary must still mark the owner as having work.
      final owner = PipelineOwner();
      final boundary = _BoundaryRenderObject();
      boundary.owner = owner;

      expect(owner.hasNodesToPaint, isFalse);
      boundary.markNeedsPaint();
      expect(owner.hasNodesToPaint, isTrue);
    });
  });

  group('error fallback in boundary', () {
    test('child paint exception paints error box into the sub-buffer', () {
      final boundary = RenderRepaintBoundary()..child = _ThrowingChild();
      boundary.layout(BoxConstraints.tight(const Size(40, 10)));

      final parentBuffer = Buffer(40, 10);
      final canvas = TerminalCanvas(parentBuffer, Rect.fromLTWH(0, 0, 40, 10));

      boundary.paintWithContext(canvas, Offset.zero);

      // The blit should have put "Paint Error" text from the error box
      // into the parent buffer.
      final rendered = _bufferText(parentBuffer);
      expect(rendered, contains('Paint Error'));
    });

    test('cached error box is reused on subsequent paints', () {
      final child = _ThrowingChild();
      final boundary = RenderRepaintBoundary()..child = child;
      boundary.layout(BoxConstraints.tight(const Size(40, 10)));
      final canvas = TerminalCanvas(
        Buffer(40, 10),
        Rect.fromLTWH(0, 0, 40, 10),
      );

      boundary.paintWithContext(canvas, Offset.zero);
      final firstThrowCount = child.paintCount;

      boundary.paintWithContext(canvas, Offset.zero);
      expect(
        child.paintCount,
        firstThrowCount,
        reason: 'cached error-box blit means the throwing child is not '
            're-invoked on a clean frame',
      );
    });
  });

  group('RenderRepaintBoundary paint', () {
    test('rejects a non-zero offset', () {
      final boundary = RenderRepaintBoundary();
      boundary.layout(BoxConstraints.tight(const Size(5, 3)));
      final canvas = TerminalCanvas(Buffer(10, 5), Rect.fromLTWH(0, 0, 10, 5));

      expect(
        // ignore: invalid_use_of_visible_for_overriding_member
        () => boundary.paint(canvas, const Offset(1, 0)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('RenderRepaintBoundary hit testing', () {
    test('hit test traverses the boundary to the child', () {
      final child = _HitTargetRenderObject();
      final boundary = RenderRepaintBoundary()..child = child;

      boundary.layout(BoxConstraints.tight(const Size(5, 3)));

      final result = HitTestResult();
      final hit = boundary.hitTest(result, position: const Offset(1, 1));

      expect(hit, isTrue);
      expect(
        result.path,
        contains(child),
        reason: 'hit test must traverse RepaintBoundary to reach the child',
      );
    });

    test('returns false when there is no child', () {
      final boundary = RenderRepaintBoundary();
      boundary.layout(BoxConstraints.tight(const Size(5, 3)));

      final result = HitTestResult();
      final hit = boundary.hitTestChildren(
        result,
        position: const Offset(1, 1),
      );

      expect(hit, isFalse);
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

/// A child whose first performLayout throws; later ones succeed and paint
/// "OK".
class _FlakyLayoutChild extends RenderObject {
  int layoutCount = 0;

  @override
  void performLayout() {
    layoutCount++;
    if (layoutCount == 1) throw StateError('first layout fails');
    size = constraints.constrain(const Size(40, 10));
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    canvas.drawText(offset, 'OK');
  }
}

/// A leaf whose paint() skips super.paint().
class _ForgetfulLeaf extends RenderObject {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(4, 2));
  }

  @override
  // ignore: must_call_super
  void paint(TerminalCanvas canvas, Offset offset) {}
}

/// A child render object whose paint() always throws.
class _ThrowingChild extends RenderObject {
  int paintCount = 0;

  @override
  void performLayout() {
    size = constraints.constrain(const Size(20, 5));
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    paintCount++;
    throw Exception('deliberate paint failure');
  }
}

String _bufferText(Buffer buffer) {
  final sb = StringBuffer();
  for (final row in buffer.cells) {
    for (final cell in row) {
      sb.write(cell.char);
    }
    sb.writeln();
  }
  return sb.toString();
}

/// A leaf that accepts any position as a hit.
class _HitTargetRenderObject extends RenderObject {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(5, 3));
  }

  @override
  bool hitTestSelf(Offset position) => true;
}

/// A boundary that counts paint invocations and draws a single cell.
class _CountingBoundary extends RenderObject {
  int paintCount = 0;
  Size paintSize = const Size(4, 2);

  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    size = paintSize;
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    paintCount++;
    // Something visible so the blit can be checked.
    canvas.drawText(offset, 'X');
  }
}
