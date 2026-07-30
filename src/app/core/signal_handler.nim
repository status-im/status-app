## Async-delivery primitive: deliver a string into a named slot on a QObject on its owning
## (GUI/main) thread, via a queued cross-thread QMetaObject::invokeMethod

import statusq_bridge

proc signal_handler*(receiver: pointer, signal: cstring, slot: cstring) =
  if not receiver.isNil:
    statusq_invoke_method_queued(receiver, slot, signal)
