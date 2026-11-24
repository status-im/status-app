## Backend signal epoch gate (process lifetime).
##
## status-go stamps every signal with the epoch of the backend session that produced it
## (`{"type":"…","epoch":N,…}`) and starts a new epoch on a client-requested Logout. A
## signal of an earlier session can still arrive after a logout (Android's one-way
## Binder stream, a queued GUI invocation), so delivery accepts only signals of the
## accepted epoch. A signal without an epoch is never assumed to be current.

import std/[atomics, deques, strutils]

const NoEpoch* = 0'u64

var acceptedEpoch: Atomic[uint64]
var epochAcceptedListener: proc() {.closure.}

proc acceptedSignalEpoch*(): uint64 =
  acceptedEpoch.load()

proc onSignalEpochAccepted*(listener: proc()) =
  ## Called after each `acceptSignalEpoch`, on the thread that accepted the epoch (the
  ## GUI thread). SessionHost delivers the signals it held for that epoch.
  epochAcceptedListener = listener

proc acceptSignalEpoch*(epoch: uint64) =
  ## Delivery accepts the signals of `epoch` from now on: at process start, and
  ## whenever a Logout starts a new backend session.
  acceptedEpoch.store(epoch)
  if not epochAcceptedListener.isNil:
    epochAcceptedListener()

# status-go's envelope: {"type":"<type>","epoch":N,"event":…}. Only that position is
# read: an "epoch" key anywhere else (inside the event) is not the envelope's, and a
# large payload is never scanned.
const TypePrefix = "{\"type\":\""
const EpochKey = "\",\"epoch\":"
const MaxTypeLength = 128
const MaxEpochDigits = 19 # fits in uint64 without overflow

proc signalEpochOf*(signal: string): uint64 =
  ## The envelope's epoch, or `NoEpoch` when the envelope has none.
  if not signal.startsWith(TypePrefix):
    return NoEpoch
  # The type is a plain identifier: its closing quote is the first one.
  let typeEnd = signal.find('"', TypePrefix.len, last = min(signal.high,
    TypePrefix.len + MaxTypeLength))
  if typeEnd < 0 or not signal.continuesWith(EpochKey, typeEnd):
    return NoEpoch
  let first = typeEnd + EpochKey.len
  var i = first
  var epoch = 0'u64
  while i < signal.len and signal[i] in Digits and i - first < MaxEpochDigits:
    epoch = epoch * 10 + uint64(ord(signal[i]) - ord('0'))
    inc i
  if i == first or i >= signal.len or signal[i] notin {',', '}'}:
    return NoEpoch
  epoch

type
  SignalRoute* {.pure.} = enum
    Deliver ## of the accepted epoch, and a session receives signals
    Hold    ## of the accepted epoch while no session receives signals, or of a later
            ## epoch: status-go emits the logged-out backend's signals during Logout,
            ## before the client has accepted the epoch Logout returns
    Drop    ## of an earlier epoch, of a session that ended, or without one

  SignalGate* = object
    ## Routes signals by epoch and keeps the held ones until they can be delivered.
    held: Deque[tuple[epoch: uint64, signal: string]]
    capacity: int
    evicted: int

proc initSignalGate*(capacity: int): SignalGate =
  SignalGate(held: initDeque[tuple[epoch: uint64, signal: string]](), capacity: capacity)

proc route*(gate: var SignalGate, epoch, acceptedEpoch: uint64, signal: string,
    hasReceiver: bool, endedEpoch = NoEpoch): SignalRoute =
  ## `endedEpoch`: the epoch of a session whose activity was stopped. Its backend keeps
  ## running until it logs out, but nothing will ever receive its signals again.
  if epoch == NoEpoch or epoch < acceptedEpoch or epoch <= endedEpoch:
    return SignalRoute.Drop
  if epoch == acceptedEpoch and hasReceiver:
    return SignalRoute.Deliver
  if gate.held.len >= gate.capacity:
    discard gate.held.popFirst()
    inc gate.evicted
  gate.held.addLast((epoch, signal))
  SignalRoute.Hold

proc takeEvictedCount*(gate: var SignalGate): int =
  ## Held signals dropped to stay within the capacity since the last call.
  result = gate.evicted
  gate.evicted = 0

proc takeDeliverable*(gate: var SignalGate, acceptedEpoch: uint64): seq[string] =
  ## The held signals of the accepted epoch, in arrival order. Held signals of an
  ## earlier epoch are discarded; later ones stay held.
  var kept = initDeque[tuple[epoch: uint64, signal: string]]()
  for entry in gate.held:
    if entry.epoch == acceptedEpoch:
      result.add entry.signal
    elif entry.epoch > acceptedEpoch:
      kept.addLast(entry)
  gate.held = kept

proc heldCount*(gate: SignalGate): int =
  gate.held.len
