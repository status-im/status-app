# ADR 0004: Typed task-completion handoff for worker→GUI data transfer

## Status

Accepted

- **Date**: 2026-07-13
- **Owners**: Status Desktop (wallet / core task infrastructure)

## Context

Threadpool workers hand their results back to the GUI thread through a queued
invoke: the worker calls `finish`, which serializes the result to a string and
passes it across the bridge; the GUI-thread completion slot re-parses that
string and builds its models. For small payloads this is invisible. For the
wallet token results it is not — the payload is a multi-megabyte JSON document,
and **the parse happens on the GUI thread inside the completion slot**.

On a device wake (issue #21395) several of these completions land at once. The
GUI thread spends its time parsing JSON instead of drawing, and the app shows a
**black screen for ~13s** (measured on device). The work the worker did in
parallel is thrown away and redone, single-threaded, on the one thread that must
stay responsive.

The worker already holds the fully-built object graph. Serializing it only to
re-parse an identical graph on the GUI thread is pure overhead. We want the
worker to hand the *graph itself* to the GUI thread.

## Decision

Add an opt-in **typed completion path** alongside the existing string `finish`:

- The worker builds its result as a Nim `ref object` graph and calls
  `finishTyped(arg, graph)`. This **parks** the graph in an in-process registry
  and sends only a small integer handle across the queued-invoke bridge.
- The GUI-thread completion slot calls `takeTyped[T](response)`, which **claims**
  the graph back out of the registry by handle. No string is ever serialized or
  parsed; no copy of the graph is made.

Ownership is **exclusive and moved, never shared**. The worker must hold the
only reference at the call site and must not touch the graph after parking. The
registry is the sole owner while parked. The slot becomes the sole owner after
claiming, and the graph is destroyed on the GUI thread when that reference goes
out of scope. Because only one place ever references the graph at a time, its
(non-atomic) refcount is never mutated concurrently; a lock around the registry
table gives the park a happens-before edge to the claim so the graph's bytes are
visible to the GUI thread.

The following constraints are load-bearing and are enforced or documented in
the code:

1. **ORC (or ARC) only — enforced at compile time.** Under refc each thread has
   its own GC heap; claiming a worker-allocated graph on the GUI thread reads
   foreign-heap memory and SIGSEGVs. A `{.error.}` guard keyed on `-d:useMalloc`
   (which both the desktop and mobile app builds set, and the unit-test suite
   does not) turns this into a build failure for any production build that
   selects a non-ORC/ARC memory manager. The single-threaded unit tests keep
   compiling under the suite's refc.

2. **Move, not copy.** The whole point is to avoid duplicating the graph — a
   deep copy of the token graph was measured at ~1.1s (O(graph)), the same class
   of cost as the JSON round trip it replaces. The payload is `sink`-taken into
   the registry and `pop`-ed out, so the refcount stays 1 throughout and the
   graph is destroyed exactly once.

3. **Transferred ref types must be `{.acyclic.}`.** ORC's cycle collector,
   running over these graphs as they are destroyed on the GUI thread, is a
   known SIGSEGV class on arm64. The transferred DTOs are tree-shaped (value
   fields plus seqs of child refs, no back-edges), so marking them `{.acyclic.}`
   tells ORC to skip cycle tracking entirely — both a correctness fix and a
   cost saving.

4. **The finish path must be deadlock-safe.** Completion slots run inside
   coalescing gates and in-flight latches; if the claim ever *raised* out of the
   completion path, those gates would never clear and the caller would wedge.
   `takeTyped` therefore returns `nil` (never raises) for an unknown, already
   claimed, drained, or malformed handle, and the worker task body runs under
   `except Exception`. On shutdown the registry is swept by `drainHandoffs` at
   task-infra teardown, and `finishTyped` destroys its own payload (still
   exclusively owned, safe) rather than parking into a loop that has stopped.

The typed path is opt-in per producer. Callers with small payloads keep using
string `finish`; only the hot, large-payload completions migrate.

## Consequences

### Positive

- The wallet token completions no longer parse multi-MB JSON on the GUI thread;
  the graph the worker built is handed over directly. The GUI-thread cost of a
  completion drops from "re-parse the whole payload" to "take a pointer".
- The two completion paths coexist behind one task-arg type, so migration is
  incremental and low-risk.

### Negative / trade-offs

- Producers on the typed path carry an ownership obligation the compiler cannot
  fully check: the parked graph must be isolated at the call site. This is
  documented at both `finishTyped` and the registry, but it is a discipline, not
  a guarantee.
- New transferred DTO types must remember `{.acyclic.}`, and the whole path is
  bound to ORC/ARC — a constraint the build guard makes loud but which still
  narrows the memory-manager choice for the app.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Keep JSON, but parse off the GUI thread | Still serializes on the worker and re-parses into a second identical graph — two full O(graph) passes to move data the worker already had. Moves the cost, doesn't remove it. |
| Shared-memory result buffer with locks | Keeps the graph reachable from two threads, reintroducing concurrent refcount mutation (the exact hazard the move design avoids) and adding lock contention on the hot completion path. |
| Always-on typed path (retire string `finish`) | Unjustified churn: most completions are small and the string path is simpler and allocation-free of a registry entry. Opt-in keeps the risk on the few hot producers. |
