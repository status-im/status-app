## Keycard signal epoch (process lifetime).
##
## Keycard signals come from status-keycard-qt in this process; the C callback stamps
## them with this epoch on arrival. The library first queues them through the GUI event
## loop, and its Stop returns once card detection has stopped, so the epoch advances
## only once the ended session's queued events were delivered (SessionHost, when the
## ended session is disposed); signals of an earlier epoch are not delivered to the next
## session.

import std/atomics

import statusq_bridge

const KeycardEpochSeparator* = '|'

var keycardEpoch: Atomic[uint64]
keycardEpoch.store(1)

proc currentKeycardEpoch*(): uint64 =
  keycardEpoch.load()

proc advanceKeycardEpoch*() =
  discard keycardEpoch.fetchAdd(1)

proc deliverKeycardSignal*(receiver: pointer, signal: cstring) =
  ## Called from the keycard C callback thread: queues "<epoch>|<signal>" to the
  ## receiver's receiveStampedKeycardSignal slot. The payload is built on the C++ side:
  ## the callback thread must not allocate Nim memory.
  statusq_invoke_method_queued_tagged(receiver, "receiveStampedKeycardSignal", signal,
    currentKeycardEpoch())
