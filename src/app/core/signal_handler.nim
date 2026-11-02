## Async-delivery primitive: deliver a string into a named slot on a QObject on its owning
## (GUI/main) thread, via a queued cross-thread QMetaObject::invokeMethod

import std/atomics

import statusq_bridge

# Generation of the current app session (one login lifetime). Async work captures it
# when submitted; the worker and the GUI thread both drop completions of an earlier
# generation. The GUI side keeps its own copy in StatusQ, which only
# `advanceSessionGeneration` updates, so the two never drift apart.
var sessionGeneration: Atomic[uint64]

proc currentSessionGeneration*(): uint64 =
  sessionGeneration.load()

proc advanceSessionGeneration*(): uint64 =
  ## Ends the current session generation for deliveries of async work.
  result = sessionGeneration.fetchAdd(1) + 1
  statusq_set_session_generation(result)

proc signal_handler*(receiver: pointer, signal: cstring, slot: cstring) =
  if not receiver.isNil:
    statusq_invoke_method_queued(receiver, slot, signal)

proc signal_handler_in_generation*(receiver: pointer, payload: cstring, slot: cstring,
    generation: uint64) =
  ## Like `signal_handler`, but the GUI thread drops the delivery when the session
  ## generation has moved on since `generation` was captured.
  if not receiver.isNil:
    statusq_invoke_method_queued_in_generation(receiver, slot, payload, generation)
