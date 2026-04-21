# RepaintBoundary for nocterm - design sketch

## Motivation

Today, any `setState()` in the tree forces a full-tree **paint walk** every
frame. Observed in the serverpod CLI TUI: a single spinner ticking at 12.5 FPS
(80 ms) drags the entire screen through `paint()` each tick - ~3 ms of paint
work for ~10 cells that actually change.

The terminal output is already optimized: `_renderDifferential()` in
`terminal_binding.dart` only writes **changed cells** to the TTY. But *getting
to* that per-cell diff still costs a full tree walk: layout + paint of every
`RenderObject` below the root.

A `RepaintBoundary` lets a subtree paint once into a **cached sub-buffer**,
then blit that cached buffer on subsequent frames as long as its descendants
haven't marked themselves dirty. The full-tree walk collapses into:

- paint walk stops at the boundary
- the parent canvas receives the cached sub-buffer via a cell-copy (blit)

This is essentially what Flutter's `RepaintBoundary` does, but far simpler
because nocterm has no alpha compositing, no transforms, no filters, and no
GPU layer tree. A sub-buffer is just `List<List<Cell>>`.

## Current pipeline (where the walk happens)

Paint today (`terminal_binding.dart:1265-1289`):

```dart
// Layout: already short-circuits at clean + identical-constraints nodes
// (render_object.dart:379).
renderObject.layout(BoxConstraints.tight(Size(w, h)));
pipelineOwner.flushLayout();

// flushPaint() currently just clears _needsPaint flags without actually
// painting anything (render_object.dart:84-100, note the comment
// "In a full implementation, this would trigger actual painting").
pipelineOwner.flushPaint();

// The real paint: root walks the whole tree unconditionally.
final canvas = TerminalCanvas(buffer, screenRect);
renderObject.paintWithContext(canvas, Offset.zero);
```

`paintWithContext` is where every parent manually recurses into children:

```dart
// render_object.dart:440
void paintWithContext(TerminalCanvas canvas, Offset offset) {
  if (_hasLayoutError) { ... return; }
  try { paint(canvas, offset); } catch (...) { ... }
}
```

Parents call `child.paintWithContext(canvas, offset + childOffset)` directly
(see `render_flex.dart:411`, `decorated_box.dart:771`, `clip.dart:78`, etc.).
There is no central paint dispatcher - which is actually good for this
feature, because the boundary behavior can be injected entirely inside
`paintWithContext`.

`markNeedsPaint` (`render_object.dart:341-354`) walks up to the root
unconditionally; this is where a boundary can short-circuit the propagation.

## Proposed design

### 1. API surface

Add a public widget + render object:

```dart
class RepaintBoundary extends SingleChildRenderObjectComponent {
  const RepaintBoundary({super.key, super.child});

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      RenderRepaintBoundary();
}

class RenderRepaintBoundary extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
}
```

Expose `isRepaintBoundary` as a virtual getter on `RenderObject` defaulting
to `false`. Any render object can opt in by overriding - useful for internal
widgets (scroll viewports, overlays) that should boundary-ize themselves.

### 2. Stop `markNeedsPaint` at boundaries

```dart
// render_object.dart
void markNeedsPaint() {
  _needsPaint = true;
  if (isRepaintBoundary) {
    // This subtree's cache is invalid; ask the owner to repaint this
    // subtree specifically, but don't walk further up.
    owner?.requestPaint(this);
    return;
  }
  if (parent != null) {
    parent!.markNeedsPaint();
  } else {
    owner?.requestVisualUpdate();
  }
}
```

Consequence: a setState deep in a boundaried subtree no longer marks
everything between it and the root as needing paint. Siblings and ancestors
that don't care keep their cached buffers.

### 3. Cached sub-buffer on the boundary

Add to `RenderObject` (only populated when `isRepaintBoundary`):

```dart
Buffer? _cachedBuffer;
// Tracks the size the cache was painted at. If size changes (relayout), we
// have to discard and repaint.
Size? _cachedBufferSize;
```

Invalidate in `layout()` whenever `size` changes:

```dart
if (isRepaintBoundary && _cachedBufferSize != _size) {
  _cachedBuffer = null;
  _cachedBufferSize = null;
  _needsPaint = true;
}
```

### 4. Intercept `paintWithContext` at boundaries

This is the core of the feature:

```dart
void paintWithContext(TerminalCanvas canvas, Offset offset) {
  if (_hasLayoutError) { _paintErrorBox(canvas, offset); return; }

  if (!isRepaintBoundary) {
    // Unchanged path for non-boundary nodes.
    try { paint(canvas, offset); } catch (e, s) { ... }
    return;
  }

  // Boundary path: paint into sub-buffer if dirty, then blit.
  final w = size.width.toInt();
  final h = size.height.toInt();

  if (_cachedBuffer == null ||
      _cachedBufferSize != size ||
      _needsPaint) {
    _cachedBuffer = Buffer(w, h);
    final subCanvas = TerminalCanvas(_cachedBuffer!,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    try {
      // Paint the subtree into the sub-buffer at origin.
      paint(subCanvas, Offset.zero);
    } catch (e, s) {
      _reportException('paint', e, s);
      _paintErrorBox(subCanvas, Offset.zero);
    }
    _cachedBufferSize = size;
    _needsPaint = false;
  }

  // Blit the cached sub-buffer into the parent canvas at `offset`.
  canvas.blitBuffer(_cachedBuffer!, offset);
}
```

### 5. Add `TerminalCanvas.blitBuffer`

```dart
// terminal_canvas.dart
void blitBuffer(Buffer source, Offset offset) {
  final dx = offset.dx.toInt();
  final dy = offset.dy.toInt();
  for (int y = 0; y < source.height; y++) {
    for (int x = 0; x < source.width; x++) {
      final cell = source.cells[y][x];
      // Respect the canvas's clip area (_area in TerminalCanvas).
      setCell(dx + x, dy + y, cell);
    }
  }
  // Translate and forward pending sixel images.
  for (final img in source.pendingImages) {
    _buffer.pendingImages.add(PendingImage(
      x: img.x + dx,
      y: img.y + dy,
      width: img.width,
      height: img.height,
      sixelData: img.sixelData,
    ));
  }
}
```

Clip-aware: must honour the canvas's `area` so boundaries inside clips don't
paint outside their clipped region. The existing `setCell` already handles
the clip check.

### 6. Wire `flushPaint` to actually paint

Currently `flushPaint` (`render_object.dart:84-100`) just clears flags. With
boundaries, it becomes a no-op on the hot path (painting happens inside the
root walk when a boundary discovers `_needsPaint`), but it still serves as
the list of boundaries that want to be marked for visual update.

A later optimization: `flushPaint` could paint boundaries into their caches
*before* the root walk, so the root walk only blits. That avoids a second
pass but isn't required for correctness.

## Expected wins

With RepaintBoundary wrapped around a spinner that ticks at 80 ms:

- **Without boundary (today):** spinner setState -> whole-tree paint each tick
  -> ~3 ms paint work.
- **With boundary:** spinner paints ~10 cells into a 10*1 sub-buffer, blit
  is ~10 cell-copies. Rest of the tree: 0 paint calls, just blits of cached
  sub-buffers up to the root. Estimated paint cost: <0.3 ms.

On the serverpod CLI debug overlay we measured:

```
Build:  0.09ms
Layout: 3.96ms
Paint:  2.88ms
```

Targeting the `Paint: 2.88ms` line - a RepaintBoundary around each spinner
and the main log ListView (already virtualized but still repainting all
visible rows every tick) should bring paint to well under 1 ms in the idle
case. That's the difference between ~21% CPU (today's 30 FPS floor) and
something closer to single digits.

## Edge cases to design for

1. **Resize.** The root layout is driven by terminal size. A resize must
   invalidate every boundary's `_cachedBuffer`. Layout-time invalidation
   (#3 above) handles this: resize changes `size`, which trips the
   size-mismatch check.

2. **Offset changes without size changes.** A boundary moves on screen but
   its content is unchanged. The cached buffer is still valid; only the
   blit offset changes. Parent's `paintWithContext` will pass a new
   `offset`, and we'll blit the cache at the new offset. No invalidation
   needed.

3. **TextStyle inheritance / theme.** If a theme change affects how a child
   paints but doesn't mark the boundary's subtree dirty, the cache will be
   stale. Mitigation: theme / inherited changes already trigger rebuilds
   via `InheritedComponent` dependencies, which reach the render objects
   via `markNeedsPaint`. As long as theme consumers mark dirty correctly,
   boundaries see the dirty flag and repaint. Verify with a test.

4. **Scroll viewports.** When a viewport scrolls, the content offset
   changes but items don't. A viewport that is itself a RepaintBoundary
   should invalidate its cache on scroll-offset change (it's essentially a
   layout change - child positions relative to the viewport shifted). The
   cheapest impl: `ScrollableRenderObject.applyOffset` calls
   `markNeedsPaint()`. Since the viewport is the boundary, that
   invalidates its own cache, not its ancestors'. Net result: scrolling
   still repaints the viewport subtree (as it must) but doesn't cascade
   elsewhere.

5. **Hit testing.** Unchanged. Hit testing walks the render tree by size
   and offset, not paint state. Boundaries don't affect hit testing.

6. **Sixel images inside a boundary.** Handled via `pendingImages`
   translation in `blitBuffer`. Needs a test.

7. **Selection regions.** `SelectionArea` etc. rely on
   `RenderObject.selectionId`. Selection is computed in a separate pass
   from hit-test positions, not paint output, so it's unaffected.

8. **Error boxes.** A boundary whose child throws during paint should fall
   back to the existing `_paintErrorBox` path, but into the sub-buffer. The
   sketch above handles this.

## Non-goals (for v1)

- **RelayoutBoundary.** `RenderObject.layout` already short-circuits when
  `!_needsLayout && identical(constraints, _constraints)`
  (`render_object.dart:379`), which effectively gives us a relayout
  boundary already: children whose constraints are stable and who aren't
  marked dirty skip `performLayout`. Making this explicit would be a
  cleaner API but the perf win over the existing short-circuit is small
  until we have profile data showing layout dominates.

- **Partial paint inside a boundary.** The boundary always repaints its
  whole sub-buffer when any descendant is dirty. Dirty-rect tracking
  inside a boundary would be another step and isn't needed for the
  spinner / animation use case.

- **Automatic boundary insertion.** Flutter inserts `RepaintBoundary`
  automatically around some widgets (e.g., list items). We should start
  with explicit opt-in via the `RepaintBoundary` widget, and only later
  consider promoting specific internal widgets (spinner,
  `ListView.builder` items) to auto-boundaries.

## Implementation phases

1. **Wire the plumbing** - `isRepaintBoundary`, `markNeedsPaint`
   short-circuit, `_cachedBuffer`, `blitBuffer`. No visible API yet; all
   boundaries return `false`. Goal: no behavior change, no perf
   regression.

2. **Add `RepaintBoundary` widget + `RenderRepaintBoundary`.** Manually
   wrap a hot spot in the example app; verify with the debug overlay that
   paint time drops.

3. **Resize / invalidation tests.** Ensure cache correctness across
   resize, theme changes, scroll, focus changes.

4. **Document + CHANGELOG + example.** `doc/repaint-boundary.md` +
   updates to `doc/` index.

5. **(Optional) Selective auto-boundaries.** e.g., `ListView.builder` items,
   `Spinner` widget - measure before committing.

## Rough sizing

- Framework changes: ~80-120 lines across `render_object.dart`,
  `terminal_canvas.dart`, `buffer.dart`.
- New files: `repaint_boundary.dart` (component + render object), ~60 lines.
- Tests: cache hit/miss, resize, theme, scroll, sixel translation, error
  fallback - ~300 lines.
- Docs + example: ~100 lines.

Total: probably a weekend of focused work, dominated by tests.
