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

proc finish*[T](arg: QObjectTaskArg, payload: T) =
  if isShuttingDown(): return
  signal_handler(cast[pointer](arg.vptr), cstring(Json.encode(payload)), cstring(arg.slot))

proc finish*(arg: QObjectTaskArg, payload: string) =
  if isShuttingDown(): return
  signal_handler(cast[pointer](arg.vptr), cstring(payload), cstring(arg.slot))

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
  ## shutdown the object is destroyed here on the worker thread (still exclusively
  ## owned — safe) and no slot is invoked; a handoff already parked when shutdown
  ## races in is swept by `drainHandoffs` at task-infra teardown.
  if isShuttingDown(): return
  let handle = parkHandoff(payload)
  signal_handler(cast[pointer](arg.vptr), cstring($handle), cstring(arg.slot))

proc takeTyped*[T](response: string): T =
  ## Claim the object delivered by `finishTyped`. Call from the completion slot,
  ## passing the slot's string argument. Transfers exclusive ownership to the GUI
  ## thread. Returns nil if the handoff was drained (shutdown) before the slot ran.
  let handle = parseBiggestUInt(response).TaskHandle
  claimHandoff[T](handle)
