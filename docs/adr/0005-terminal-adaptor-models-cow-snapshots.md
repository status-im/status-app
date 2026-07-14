# ADR 0005: Terminal adaptor models over COW snapshots for hot wallet views

## Status

Accepted

- **Date**: 2026-07-13
- **Owners**: Status Desktop (wallet)

## Context

The wallet assets list and the send/swap/buy token pickers are **update-hot**:
market prices, balances, and search results change continuously while the view
is on screen. Each was fed by a stack of QML proxies —
`LeftJoinModel → ObjectProxyModel → SortFilterProxyModel` with JS
`FastExpressionRole`s for the derived roles (grouping, market join, visibility,
sort keys).

Stacked proxies **amplify emissions**. A single granular source change does not
arrive at the view as one `dataChanged`; each proxy layer widens it, and a
`SortFilterProxyModel` with dynamic sort/filter turns any change into a full
re-sort and a `layoutChanged`, which forces delegate churn and re-evaluates the
JS expression roles across the model. Measured on the host propagation
benchmark:

- **One cell edit** (a single market price) → four whole-model `dataChanged`
  spanning 4×N rows; ~12s at 5k tokens.
- **All prices change** → O(N²) through the chain; unrunnable at 5k tokens and
  already ~15.7s at just 100 tokens.

The lesson from trying to fix this in place is recorded here deliberately: we
first tried to make each proxy layer emit incrementally. It is
**whack-a-mole** — granular emissions are only ever as cheap as the *dumbest
proxy above them*. One non-incremental layer in the stack re-inflates the whole
cascade. The chain has to be replaced, not tuned.

## Decision

For update-hot views, **one Nim "terminal" model per view feeds the `ListView`
directly**. The model computes the join, filter, sort, and derived roles
internally; there are **no proxy models and no expression roles between it and
the view**. Because it is terminal, a per-row `dataChanged` reaches the view as
exactly that — granular emissions become safe again.

The concrete terminal models are `AssetsAdaptorModel` (wallet assets list) and
`TokenSelectorAdaptor` (the shared send/swap/buy picker; grouping, chain filter,
search, and sort all in Nim). They are named by transformation per the QML
architecture guide, injected via context property behind the store layer, and
formatting stays in QML (financial values reach the delegate as big-integer
strings and are rendered there).

The service→model hand-off is a **COW snapshot container** (`CowSeq`):

- The service publishes an **immutable versioned container** — a fresh array per
  update whose row refs are *shared* with the previous version (no deep copy).
  Snapshot copy is O(1) (a refcount bump); the buffer forks only on mutation.
- A consumer holds a ref to the version it rendered. On the next version,
  `model_sync` diffs previous↔next by `key` and emits the minimal granular ops
  (per-row `dataChanged`, insert, remove, move-as-remove+insert).
- Worker-built state (see the typed-handoff ADR) becomes the next version **by
  move**, never by re-parse or copy.
- The container is **GUI-thread-only** — its refcount is a plain `int`, not an
  atomic, because the typed move keeps any given `CowSeq` from ever crossing a
  thread boundary. A debug-build assertion enforces the single-thread
  constraint. `model_sync` runs the diff on the GUI thread (O(n) over hundreds
  of rows); moving the diff to a worker is an escape hatch to be taken only if
  ever measured as necessary.

`model_sync` (the granular-diff engine) predates this work and is reused, not
introduced here.

### Behavioural decisions ratified during review

Moving these computations from QML expression roles into Nim exposed several
places where the old proxy chain was subtly wrong. The Nim models intentionally
**diverge** from the retired behaviour:

- **Picker section ordering** keys on `hasBalance` (a boolean), not on an ASCII
  string comparison of the section name. The old string-desc ordering was an
  accident of the sort role and is not locale-robust.
- **Per-group fiat totals** sum in `UInt256` and convert once at the end, rather
  than summing per-chip `double`s. This is an accuracy fix — floating-point
  per-chip sums drift.
- **Account matching** is an exact match, not a `RegExp` substring match, which
  could previously match unintended accounts.
- **`change1DayFiat` at −100%** is defined as `0`. When a position's value has
  gone to zero the DTO cannot reconstruct the absolute loss, so the derived role
  reports no change rather than a misleading figure.

## Consequences

### Positive

- The same updates that cost seconds through the proxy chain are O(changed-rows)
  on the terminal model: the one-cell-edit and all-prices-change classes land at
  ~13.6ms at 5k tokens on the host benchmark, and delegate churn / JS
  expression-role evaluation go to zero.
- Derived-role correctness lives in one typed, testable place instead of being
  spread across JS expression roles.

### Negative / trade-offs

- **Test topology shifts.** Model behaviour (join/filter/sort/derived roles) is
  tested in Nim; the QML tests assert *wiring* over stubbed models rather than
  re-testing the computation. A **host QML-propagation benchmark is the
  regression gate** — it instantiates the real QML consumers on the terminal
  models and asserts the structural contract (no `layoutChanged`/reset on
  stable-set updates, O(changed-rows) `dataChanged`, zero delegate churn), with
  timings trended.
- **Per-tick recompute is O(set).** Each update re-filters and re-sorts the
  working set rather than incrementally patching sort position. This was
  measured as acceptable at the target token-universe sizes and is deliberately
  left simple; revisit only if a profile shows it dominating.
- Divergence from the old visible behaviour (section order, totals rounding) is
  intentional but is a behaviour change reviewers and QA must expect.

## Scope / reuse boundary

This ADR governs **hot paths** — views whose backing data changes while they are
visible. QML proxy chains (`LeftJoinModel`, `ObjectProxyModel`,
`SortFilterProxyModel`, expression roles) remain the right tool for **cold or
static models**, where emission amplification never triggers because the model
does not churn. Do not rewrite a static view into a Nim terminal model on the
strength of this decision alone; the terminal-model cost (a bespoke Nim model
per view) is only repaid by update-hot traffic.
