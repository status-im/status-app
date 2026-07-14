## Typed task-completion handoff registry.
##
## Companion to the string-based `finish` path (see `qt.nim`): instead of
## serializing a worker-built result to JSON and re-parsing it on the GUI thread,
## the worker parks the *finished object graph* here and delivers only a tiny
## integer handle through the existing queued-invoke bridge. The GUI slot claims
## the graph back by handle — no multi-MB string ever crosses the boundary.
##
## OWNERSHIP RULE (read before use):
##   `parkHandoff` takes EXCLUSIVE ownership of `obj`. The object must be isolated
##   at the call site — the producing thread must hold the *only* reference and
##   MUST NOT touch it again after parking. `claimHandoff` transfers that
##   exclusive ownership to the calling (receiving) thread; the object is
##   destroyed on the receiving thread when the returned ref goes out of scope.
##
## Why this is safe under ORC (and refc):
##   The object is only ever reachable from one place at a time — the producer's
##   local before `parkHandoff`, the registry table in between, the consumer's
##   local after `claimHandoff`. No two threads ever hold a reference at once, so
##   its (non-atomic) refcount is never mutated concurrently. The lock around the
##   table gives the producer's `park` a happens-before edge to the consumer's
##   `claim`, so the stored bytes and the object's fields are visible to the
##   consumer thread. Payloads are moved in and out (`sink` / `pop`), so the
##   refcount stays 1 throughout and the graph is destroyed exactly once.
##
## Shutdown: any handoff whose slot never runs (GUI loop stopped mid-flight)
## stays parked. `drainHandoffs` destroys all such stragglers; call it from the
## task-infra teardown so nothing leaks at shutdown.

import std/[locks, tables]

# This registry transfers a ref graph BETWEEN threads (a worker parks; the GUI
# thread claims). That is sound only on a shared heap — ORC/ARC. Under refc each
# thread has its own GC heap, so claiming a worker-allocated graph on another
# thread reads foreign-heap memory and SIGSEGVs (observed in claimHandoff ->
# tables.pop). Turn that runtime footgun into a BUILD error for the real app build.
#
# The guard keys on `-d:useMalloc`, which BOTH app builds set (desktop Makefile and
# mobile buildNimStatusClient.sh) and the nim-test suite does not. That is
# deliberate: the danger is the cross-thread transfer, which only the threaded app
# exercises; the unit tests use the registry single-threaded (safe on any mm) and
# must keep compiling under the suite's refc. So: error only when a production
# (useMalloc) build picks a non-orc/arc mm — e.g. someone flips `--mm:orc` to refc.
when defined(useMalloc) and not (defined(gcOrc) or defined(gcArc)):
  {.error: "app/core/tasks/typed_handoff requires --mm:orc (or --mm:arc): it moves a ref graph across threads, unsound on refc's thread-local GC heaps. (Guarded on -d:useMalloc so it fires on the app build, not the refc unit-test suite.)".}

type TaskHandle* = uint64

var
  gLock: Lock
  gNextHandle: uint64
  gTable {.guard: gLock.}: Table[TaskHandle, RootRef]

gLock.initLock()

# gcsafe is asserted on the registry procs: `gTable` is a GC'd global, which the
# compiler flags as unsafe to touch from a threaded (gcsafe) context — but the
# producer (a threadpool worker calling finishTyped -> parkHandoff) needs exactly
# that. It is genuinely safe here: `gLock` serializes ALL access so no two threads
# ever touch the table or an entry's refcount concurrently, and under --mm:orc the
# shared-heap allocator the table grows into is itself thread-safe. The compiler
# cannot see the lock, so we assert what the lock guarantees.

proc parkHandoff*[T](obj: sink T): TaskHandle {.gcsafe.} =
  ## Park an isolated object graph, returning a handle to deliver out-of-band.
  ## Transfers exclusive ownership into the registry. `T` must be a
  ## `ref object of RootObj` so it can be reclaimed via `claimHandoff[T]`.
  {.cast(gcsafe).}:                 # gTable access is lock-serialized (see note above)
    withLock gLock:
      inc gNextHandle
      result = gNextHandle
      gTable[result] = obj          # move: table becomes the sole owner

proc claimHandoff*[T](handle: TaskHandle): T {.gcsafe.} =
  ## Retrieve and remove the object for `handle`, transferring exclusive
  ## ownership to the caller. Returns nil if the handle is unknown (already
  ## claimed, or drained at shutdown before the slot ran).
  var base: RootRef
  {.cast(gcsafe).}:
    withLock gLock:
      discard gTable.pop(handle, base)   # move out; entry removed
  if base.isNil:
    return nil
  result = T(base)                     # checked ref down-conversion

proc drainHandoffs*() {.gcsafe.} =
  ## Destroy every still-parked object. Call on shutdown (from the thread that
  ## owns the receiving event loop) so in-flight handoffs don't leak.
  {.cast(gcsafe).}:
    withLock gLock:
      gTable.clear()

proc pendingHandoffs*(): int {.gcsafe.} =
  ## Number of parked-but-unclaimed handoffs. Diagnostics / tests only.
  {.cast(gcsafe).}:
    withLock gLock:
      result = gTable.len
