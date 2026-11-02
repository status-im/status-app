import # vendor libs
  nimqml, json_serialization

import std/strutils

import app/core/signal_handler

import # status-desktop libs
  ./common,
  ./typed_handoff,
  app/global/app_lifecycle

export typed_handoff.TaskHandle, typed_handoff.drainHandoffs

type
  QObjectTaskArg* = ref object of TaskArg
    vptr*: uint
    slot*: string

export signal_handler.currentSessionGeneration, signal_handler.advanceSessionGeneration

proc isStale(arg: QObjectTaskArg): bool =
  ## The app is quitting or the session that submitted the task has ended. The GUI
  ## thread re-checks the generation on delivery, for completions queued before that.
  ## An arg completed without going through `ThreadPool.start` keeps generation 0 and
  ## is stale once the first session has ended.
  isShuttingDown() or arg.generation != currentSessionGeneration()

proc deliver(arg: QObjectTaskArg, payload: cstring) =
  signal_handler_in_generation(cast[pointer](arg.vptr), payload, cstring(arg.slot), arg.generation)

proc finish*[T](arg: QObjectTaskArg, payload: T) =
  if arg.isStale(): return
  arg.deliver(cstring(Json.encode(payload)))

proc finish*(arg: QObjectTaskArg, payload: string) =
  if arg.isStale(): return
  arg.deliver(cstring(payload))

proc finishTyped*[T](arg: QObjectTaskArg, payload: sink T) =
  ## Opt-in typed completion path — the companion to `finish`.
  ## The worker hands the GUI thread a fully-built, EXCLUSIVELY-OWNED object graph
  ## (`T` must be a `ref object of RootObj`) with no JSON serialize/re-parse round
  ## trip. Only a small integer handle crosses the queued-invoke bridge; the heavy
  ## graph is parked in the `typed_handoff` registry.
  ##
  ## Ownership: `payload` must be isolated — the sole reference at the call site.
  ## After this call the worker MUST NOT touch it. The receiving slot claims it via
  ## `takeTyped[T](response)`; the object is then destroyed on the GUI thread. On
  ## shutdown, or once the submitting session has ended, the object is destroyed here
  ## on the worker thread (still exclusively owned — safe) and no slot is invoked. A
  ## handoff parked before that, whose delivery the GUI thread then drops, is swept by
  ## `drainHandoffs` when the session's pool is torn down (`ThreadPool.teardown`).
  if arg.isStale(): return
  let handle = parkHandoff(payload)
  arg.deliver(cstring($handle))

proc takeTyped*[T](response: string): T =
  ## Claim the object delivered by `finishTyped`. Call from the completion slot,
  ## passing the slot's string argument. Transfers exclusive ownership to the GUI
  ## thread. Returns nil if the handoff was drained (shutdown) before the slot ran,
  ## or if `response` is not a valid handle — a non-numeric string must yield nil
  ## (drained semantics), never raise, so a slot wired to the wrong producer can't
  ## throw out of the completion path and wedge a caller's in-flight gate.
  var handle: TaskHandle
  try:
    handle = parseBiggestUInt(response).TaskHandle
  except ValueError:
    return nil
  claimHandoff[T](handle)
