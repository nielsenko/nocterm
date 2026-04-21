# RepaintBoundary

A `RepaintBoundary` caches its subtree's output into a sub-buffer and
blits that cache on subsequent frames. When any descendant marks
itself dirty, dirty propagation stops at the boundary - ancestors and
siblings keep their own caches and don't repaint.

Wrap a widget in a `RepaintBoundary` to isolate its redraw cost from
the rest of the tree:

```dart
RepaintBoundary(
  child: MyTickingSpinner(),
)
```

## When to wrap

Use `RepaintBoundary` around **isolated animation hotspots** inside an
otherwise idle UI:

- A spinner or progress indicator that ticks on a timer.
- A clock / elapsed-time counter.
- An animated chart or sparkline.

Without the boundary, one of these widgets' `setState` per tick
triggers a full-tree paint walk. With the boundary, only the tiny
sub-buffer gets repainted; the rest of the tree blits cached output.

See `example/repaint_boundary_demo.dart` for a runnable A/B demo.
Press `Ctrl+G` in the running app to see paint timings on the debug
overlay, and `B` to toggle the boundary on/off.

## When NOT to wrap

The first paint (and every invalidation) allocates a new
`Buffer(width, height)` and `width * height` new `Cell` instances.
That allocation has real cost; for small subtrees or for widgets that
change every frame anyway, it can outweigh the savings.

Avoid wrapping:

- **Very small subtrees** (a single `Text` glyph) - the boundary
  allocation costs more than a direct paint.
- **Subtrees that always change** - the cache is invalidated every
  frame, so you pay allocation *plus* paint.
- **Whole-screen regions** - the sub-buffer allocation is O(W*H)
  cells. A 200*60 boundary that invalidates on every frame is a
  regression.

The debug overlay (`Ctrl+G`) is the fastest way to tell: watch
`Paint:` before and after adding the boundary.

## What it does NOT do

- It is **not a relayout boundary**. A descendant calling
  `markNeedsLayout` still cascades up to ancestors - layout changes
  can resize ancestors, so their paint must re-run.
- It does **not** protect against stale caches from mutations that
  skip `markNeedsPaint`. All correctly-written render objects and
  `InheritedComponent` consumers already call `markNeedsPaint` on
  change, so the cache is invalidated through the normal dirty-flag
  path.
- It does **not** affect hit testing - interactive widgets under a
  boundary still receive events normally.

## How it works

Internally, `RepaintBoundary` overrides `isRepaintBoundary` on its
render object. The framework:

1. In `markNeedsPaint`: when a descendant dirtes, the walk up the
   tree stops at the boundary and calls
   `PipelineOwner.requestPaint(boundary)` instead of continuing to
   the root.
2. In `paintWithContext`: a boundary with a valid cache blits
   `_cachedBuffer` into the parent canvas at the current offset. A
   dirty or first-paint boundary paints its subtree into a fresh
   sub-buffer, stores that as `_cachedBuffer`, and then blits it.
3. In `layout`: a size change clears `_cachedBuffer` so the next
   paint rebuilds the cache.

For the full design, see
[`doc/repaint-boundary-design.md`](repaint-boundary-design.md).
