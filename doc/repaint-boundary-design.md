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

## Verified against source - drift from the initial sketch

Before any boundary code is written, a few assumptions in the sketch above
need correcting against the real tree.

1. **Several render objects bypass `paintWithContext` and call
   `child!.paint()` directly.** This is the single biggest issue: the
   boundary logic lives inside `paintWithContext`, so any parent that
   skips it defeats caching for its entire subtree. Confirmed offenders:

   - `lib/src/components/basic.dart:461` - `RenderConstrainedBox.paint`
   - `lib/src/components/basic.dart:508` - `RenderPadding.paint`
   - `lib/src/components/basic.dart:593` - `RenderPositionedBox.paint`
   - `lib/src/components/single_child_scroll_view.dart:345` -
     `_RenderSingleChildViewport.paint`
   - `lib/src/components/scrollbar.dart:243` - `RenderScrollbar.paint`
   - `lib/src/components/modal_barrier.dart:105, 473` - modal barrier /
     `RenderColoredBox.paint`
   - `lib/src/rendering/mouse_region.dart:112` - mouse region paint

   A `RepaintBoundary` placed under any of these (e.g. inside a `Padding`
   or `Align`) would silently never cache. These all need to be
   normalized to `child!.paintWithContext(...)` **as a plumbing
   prerequisite**, before any boundary logic lands. A regression test
   should fail if a new `child!.paint(` appears inside a `paint()` method
   under `lib/src/`.

2. **`RenderProxyBox` does not exist in this codebase.** The idiomatic
   base is `RenderObject with RenderObjectWithChildMixin<RenderObject>`.
   See `RenderPadding` in `lib/src/components/basic.dart` for the
   canonical shape. The API sketch in §1 below has been updated.

3. **`PipelineOwner.requestPaint` already exists**
   (`render_object.dart:31-36`) and populates `_nodesNeedingPaint`. No
   new pipeline API is needed for the short-circuit.

4. **Frame-skip interaction is safe.** `terminal_binding.dart:1195-1231`
   checks `pipelineOwner.hasNodesToPaint` *before* falling back to
   `rootRender.needsPaint`. A boundary-short-circuited `markNeedsPaint`
   calls `owner.requestPaint(this)`, which sets `hasNodesToPaint = true`
   and keeps the frame from being skipped. Verified - but leave a
   regression test.

5. **`markNeedsLayout` already calls `markNeedsPaint()` on self**
   (`render_object.dart:332`) and then walks parents via
   `parent?.markNeedsLayout()`. Layout propagation is unchanged by the
   boundary; paint propagation from a relayout-dirty descendant still
   stops at the nearest enclosing boundary. Worth a unit test.

6. **Line numbers cited above were accurate within a few lines** as of
   the sketch date. Re-check before editing.

7. **`PipelineOwner.flushPaint` clears `_needsPaint` *before* the root
   paint walk runs.** `flushPaint` (`render_object.dart:84-100`) today
   walks `_nodesNeedingPaint` and sets `node._needsPaint = false` on
   each without actually painting. `terminal_binding._drawFrameCallback`
   calls `flushPaint()` and *then* calls `renderObject.paintWithContext(...)`
   at the root. With the naive boundary check
   `_cachedBuffer == null || _cachedBufferSize != size || _needsPaint`,
   the dirty flag is already cleared by the time the boundary sees it,
   and a stale cache gets blitted.

   The cleanest fix is to **remove the `_needsPaint = false` clear from
   `flushPaint`**. The base `paint()` already sets `_needsPaint = false`
   (`render_object.dart:435`) during the real root walk, so the clearing
   in `flushPaint` is a pre-boundary placeholder that becomes incorrect
   the moment `_needsPaint` starts carrying cache-invalidation semantics.
   A lighter-touch alternative is to skip the clear only when
   `isRepaintBoundary` is true - but that leaves the placeholder in
   place for non-boundary nodes and makes `flushPaint` behave
   inconsistently. Remove the clear outright.

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

// nocterm has no RenderProxyBox - mirror the shape of RenderPadding.
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
      size = child!.size;
    } else {
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    // Called by the base paintWithContext into the sub-buffer with
    // offset == Offset.zero; cache + blit happens one level up in
    // paintWithContext().
    if (child != null) child!.paintWithContext(canvas, offset);
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) =>
      child?.hitTest(result, position: position) ?? false;
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

### 6. Stop `flushPaint` from clearing `_needsPaint`

Per "Verified against source" §7: `flushPaint`'s current clearing of
`_needsPaint` breaks the boundary's use of that flag as a
cache-invalidation signal. Remove the clear:

```dart
// render_object.dart, inside PipelineOwner.flushPaint
for (final node in dirtyNodes) {
  // Removed: node._needsPaint = false;
  // The base paint() sets this during the real root walk.
}
```

The iteration over `_nodesNeedingPaint` is left in place as a
placeholder - future optimizations may use it to pre-paint boundaries
into their caches before the root walk (so the walk only blits). Not
required for correctness in v1.

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

### Phase 1 - Plumbing (no public API, no behavior change)

Done when the framework builds, all existing tests pass, and a synthetic
`isRepaintBoundary = true` override on a test render object demonstrates
caching + blit.

1.1 **Normalize child paint dispatch to `paintWithContext`.** Must land
    first. Replace `child!.paint(...)` with `child!.paintWithContext(...)`
    in each of the 8 call sites listed under "Verified against source"
    §1. Existing tests must stay green (the only effective change is
    that error handling now wraps these children, which is desirable).
    Re-grep `child!?\.paint\(` inside `lib/src/` after the edits - expect
    zero hits inside `paint()` overrides.

1.2 **Add `isRepaintBoundary` getter + cache fields to `RenderObject`.**
    In `lib/src/framework/render_object.dart`: add
    `bool get isRepaintBoundary => false;` near the other flag getters,
    and two private fields `Buffer? _cachedBuffer;` and
    `Size? _cachedBufferSize;`. Import `Buffer` via `framework.dart` if
    not already in scope.

1.3 **Invalidate cache on size change.** In `RenderObject.layout(...)`
    (after `performLayout()` succeeds) and in `_layoutWithoutResize`,
    guard on `isRepaintBoundary && _cachedBufferSize != _size` and null
    out the cache fields plus set `_needsPaint = true`. Confirm `Size`
    is a value type with `==` before relying on `!=`; otherwise compare
    width/height explicitly.

1.4 **Short-circuit `markNeedsPaint`.** Replace the body of
    `markNeedsPaint` per §2 above. Call `owner?.requestPaint(this)` in
    the boundary branch, plus an explicit `owner?.requestVisualUpdate()`
    so re-marking an already-dirty boundary still schedules a frame
    (`PipelineOwner.requestPaint` only schedules when newly added).

1.5 **Intercept in `paintWithContext`.** Replace the body per §4 above.
    Set `_needsPaint = false` explicitly in the boundary branch after
    the sub-paint completes, so descendant `markNeedsPaint` calls
    during the sub-paint are absorbed by this same pass.

1.6 **Implement `TerminalCanvas.blitBuffer`.** Per §5, but honour the
    canvas's `area` explicitly with bounds checks (the design's
    "existing `setCell` already handles the clip check" is imprecise -
    `TerminalCanvas` has no public `setCell`, so the blit writes
    directly to the underlying `Buffer` and must do its own clip
    check). Translate `pendingImages` by `area.left/top + dx/dy` when
    forwarding to the parent buffer.

1.7 **Plumbing test** - `test/framework/repaint_boundary_test.dart`:
    build a minimal render-object subclass with
    `isRepaintBoundary => true`, instrument its `paint()` with a
    counter, and assert that two consecutive `paintWithContext` calls
    trigger `paint()` exactly once. Then call `markNeedsPaint` and
    confirm the next `paintWithContext` paints again.

### Phase 2 - Public `RepaintBoundary` widget

Done when the example app shows a measurable drop in the debug
overlay's `Paint:` line after wrapping a hot spot.

2.1 Create `lib/src/components/repaint_boundary.dart` with the widget
    and render object from §1 above.

2.2 Export from `lib/nocterm.dart` near the other component exports.

2.3 Wrap a hot-spot widget (spinner / debug overlay demo) in
    `example/`. Toggle the debug overlay via `Ctrl+G` (see
    `debug_overlay.dart:333-335` for the `Build/Layout/Paint` display)
    and record before/after `Paint:` readings. Any measurable reduction
    passes correctness; the design's <0.3 ms target is aspirational.

### Phase 3 - Correctness tests

Add test coverage for every edge case. Tests live under
`test/framework/repaint_boundary_test.dart` (unit) and
`test/rendering/repaint_boundary_widget_test.dart` (integration via
`testNocterm`).

| # | Case | Type | Assertion |
|---|------|------|-----------|
| 1 | Cache hit | unit | Two frames, no dirty: child `paint()` counter == 1 |
| 2 | Cache miss on dirty descendant | unit | `markNeedsPaint` on child -> counter == 2 next frame |
| 3 | `markNeedsPaint` short-circuit | unit | Parent's `markNeedsPaint` NOT called when a descendant under a boundary marks dirty |
| 4 | Relayout via `markNeedsLayout` | unit | Confirms item 5 from "Verified against source" - relayout-dirty descendant stops at the boundary for paint purposes |
| 5 | Resize invalidation | integration | Terminal-size change invalidates cache (counter increments) |
| 6 | Theme / inherited change | integration | `Theme` setState above boundary -> child repaints |
| 7 | Scroll viewport as its own boundary | integration | Scroll offset change invalidates viewport's cache but not ancestors' |
| 8 | Sixel image inside boundary | integration | `buffer.pendingImages` contains the correctly translated position after blit |
| 9 | Error fallback | unit | Child throws in `paint` -> boundary paints error box into sub-buffer; subsequent frames reuse cached error box |
| 10 | Offset-only change | unit | Parent shifts boundary without size change -> cache reused, blit goes to new offset |
| 11 | Hit testing unchanged | unit | Position->hit result identical with and without boundary wrap |
| 12 | Frame-skip regression | integration | With a boundary-dirty descendant and otherwise clean tree, frame is NOT skipped |
| 13 | Paint-dispatch regression lint | test harness | Walk `lib/src/components/`, fail if `child!.paint(` reappears inside a `paint()` method |

### Phase 4 - Docs, CHANGELOG, example

- `doc/repaint-boundary.md` - user-facing docs with a "when to use /
  when not to" section (a sub-buffer allocation is O(W*H) cells; not
  worth it for tiny or cheap subtrees).
- CHANGELOG entry under Unreleased.
- `example/repaint_boundary_example.dart` demonstrating a spinner
  wrapped in a boundary with the debug overlay on.

### Phase 5 (optional) - Selective auto-boundaries

Promote specific internal widgets (`Spinner`,
`ListView.builder` items) to auto-boundaries only after benchmarking
each candidate. Small items carry enough sub-buffer-allocation overhead
to regress some workloads - measure first.

## Risks / unknowns

1. **(Highest)** Paint-dispatch bypass (see §1 of "Verified against
   source"). Must be fixed in 1.1 or boundaries silently don't work
   under common layout widgets. Add the lint-style regression test
   (case #13).

2. **Sub-buffer allocation cost.** A 120*40 boundary allocates ~4800
   `Cell` objects on its first frame. Acceptable for small widgets;
   less so for whole-screen boundaries. Document in the "when not to
   use" section.

3. **Hot reload / HMR.** Reloading a boundary whose child type changes
   may leave a stale cached buffer. Safest mitigation: null out the
   cache in `adoptChild`/`dropChild` on boundaries. One-liner; add
   when implementing 1.2.

4. **Layout callbacks spawning new RenderObjects under a boundary.**
   `invokeLayoutCallback` (render_object.dart:565) can create children
   during layout. Those children's `markNeedsPaint` during construction
   reaches the boundary via the short-circuit and dirties it - the
   cache rebuild that frame handles them correctly. Covered by case #4.

5. **`flushPaint` still doesn't actually paint.** Unchanged from today;
   painting happens inside the root walk when a boundary discovers
   `_needsPaint`. The later optimization mentioned in §6 above ("paint
   boundaries into caches in `flushPaint` before the root walk") stays
   out of scope for v1.

6. **Selection, hit testing, sixel translation.** Verified independent
   of paint output: selection uses `selectionId`; hit testing uses
   render-tree sizes/offsets; sixel `pendingImages` is explicitly
   translated in `blitBuffer`. Tests #7, #8, #11 cover these.

## Critical files

- `lib/src/framework/render_object.dart` - the core changes
- `lib/src/framework/terminal_canvas.dart` - `blitBuffer`
- `lib/src/components/repaint_boundary.dart` (new) - public API
- `lib/src/components/basic.dart`, `scrollbar.dart`, `modal_barrier.dart`,
  `single_child_scroll_view.dart`, `rendering/mouse_region.dart` -
  paint-dispatch normalization (phase 1.1)
- `lib/src/binding/terminal_binding.dart` - frame-skip verification
  (no change expected, but add a regression test)

## Rough sizing

- Framework changes: ~80-120 lines across `render_object.dart`,
  `terminal_canvas.dart`, `buffer.dart`.
- New files: `repaint_boundary.dart` (component + render object), ~60 lines.
- Tests: cache hit/miss, resize, theme, scroll, sixel translation, error
  fallback - ~300 lines.
- Docs + example: ~100 lines.

Total: probably a weekend of focused work, dominated by tests.
