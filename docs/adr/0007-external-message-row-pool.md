# External row pool over view-owned delegate recycling

Status: accepted

The chat message view eliminates row-creation cost by acquiring pre-built row items from an app-level pool instead of letting the view instantiate delegates. The pool is filled asynchronously at background priority from app start (boosted while a view is actually waiting on it), and the display path never creates row content. The window cap is *defined* as the number of ready pool items — in-window ⇔ holds a pooled item — so window size, pool capacity, and skeleton behavior are one mechanism, not three.

Measured before committing to it: re-pointing a warm pooled `MessageView` at a different row costs 0.27 ms, against 15.5 ms to create and polish the same row from scratch (offscreen, text rows).

## Why not the obvious paths

- **ListView `reuseItems`** — the message view is a Flickable + Repeater + GridLayout over a windowed slice of an unbounded, resetting message model, so ListView's pool doesn't exist here; even where it does, it can't be pre-warmed at startup, gives no capacity guarantee, and is flushed on model reset. This is a verdict on today's message model: a model with a fixed row count per chat (unloaded rows as placeholders, filled in place) would remove the reasons the custom view exists, and a standard ListView hosting the same pooled rows is to be measured against it then.
- **Pooling per row variant / lean per-kind delegates** — all real message content types resolve to a single inner component (`messageComponent`) inside `MessageView`, so one pooled kind covers the common path. A lean text-only delegate rewrite was rejected as the pool unit: not production-ready, and not decisively faster than `MessageView`. The pool API stays kind-keyed so per-kind delegates can be introduced later if rebind measurements justify them. Rare kinds (system rows, gap, identifier, marker) are built on demand, unpooled.
- **`LayoutItemProxy`** — same problem shape (one item, many placements) but built for a handful of static responsive-layout alternatives; its visible-proxy-steals-target semantics would race the pool's own reparenting under per-page retarget churn, to save ~5 lines of explicit reparent/size glue.

## Consequences

- Row data reaches pooled items via a C++ bulk role assign + granular per-row `dataChanged` follow (RowBinder), which requires `MessageView` to be context-free: every input an explicit typed property, no model-context role reads, no state latched from birth values.
- Pooled items are invisible and disabled while parked; the rebind on acquire is the reset — no preemptive reset call exists.
- Window slides release outgoing rows before acquiring incoming ones, and a live message may trim the window's far end to free an item, so the pool cannot be dry when a live row needs one.
- Chat/section switching records position as {oldest row id, span, window-relative offset}, never indices or absolute contentY: clock-ordered inserts rot indices from both ends, while the same row set at the same width reproduces the same layout exactly.
- One pool, at most one dressed view app-wide (active section only).
