# RepaintBoundary

A `RepaintBoundary` caches its subtree's output in a sub-buffer and
blits that cache on later frames. When a descendant marks itself
dirty, the dirty walk stops at the boundary. Ancestors and siblings
keep their own caches and do not repaint.

Wrap a widget in a `RepaintBoundary` to isolate its redraw cost from
the rest of the tree:

```dart
RepaintBoundary(
  child: MyDashboard(),
)
```

## When to wrap

Painting is a walk from the root. A node outside any boundary repaints
on every frame, whether or not anything in it changed. So the boundary
goes around the content that stays still, next to whatever animates:

- The dashboard beside a spinner or progress indicator.
- The log pane beside a clock or elapsed-time counter.
- The static chrome around an animated chart.

Each tick's `setState` still schedules a frame, but the boundary blits
its cache instead of walking its subtree.

Wrapping the ticking widget itself buys nothing. Its mark invalidates
its own cache every frame, so it pays a repaint plus a blit, and the
rest of the tree still walks.

See `example/repaint_boundary_demo.dart` for a runnable A/B demo.
Press `Ctrl+G` in the running app to see paint timings on the debug
overlay, and `B` to toggle the boundary.

## When not to wrap

The first paint allocates a `Buffer(width, height)`. Later repaints
reuse it, but each one still costs the paint plus a blit of
`width * height` cells.

Avoid wrapping:

- Very small subtrees, such as a single `Text` glyph. The blit costs
  about as much as the paint.
- Subtrees that change every frame. The cache is invalidated every
  frame, so you pay paint plus blit.
- Whole-screen regions that change often. A 200 by 60 boundary that
  invalidates on every frame is a regression.

The debug overlay (`Ctrl+G`) is the fastest way to tell. Watch
`Paint:` before and after adding the boundary.

## What it does not do

- It is not a relayout boundary. A descendant calling
  `markNeedsLayout` still cascades up to ancestors, because a layout
  change can resize them.
- It does not protect against stale caches from mutations that skip
  `markNeedsPaint`. Render objects and `InheritedComponent` consumers
  call `markNeedsPaint` on change, so the cache is invalidated through
  the normal dirty-flag path.
- It does not affect hit testing. Interactive widgets under a boundary
  receive events as before.
- It does not hide what is behind it. Cells the subtree never paints
  stay transparent, and painted cells without a background keep the
  background underneath, so a boundary inside a colored container
  looks the same as the bare subtree.

## How it works

`RepaintBoundary` overrides `isRepaintBoundary` on its render object.
The framework then:

1. In `markNeedsPaint`: when a descendant dirties, the walk up the
   tree stops at the boundary and calls
   `PipelineOwner.requestPaint(boundary)` instead of continuing to
   the root.
2. In `paintWithContext`: a boundary with a valid cache blits
   `_cachedBuffer` into the parent canvas at the current offset. A
   dirty or first-paint boundary paints its subtree into the
   sub-buffer, then blits it.
3. In `layout`: a size change drops `_cachedBuffer`, and any relayout
   marks the boundary dirty so the next paint rebuilds the cache.

For the full design, see
[`doc/repaint-boundary-design.md`](repaint-boundary-design.md).
