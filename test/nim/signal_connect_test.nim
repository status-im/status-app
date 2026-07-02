import unittest
import nimqml

QtObject:
  type Emitter = ref object of QObject

  proc delete(self: Emitter) =
    self.QObject.delete

  proc newEmitter(): Emitter =
    new(result, delete)
    result.QObject.setup

  proc ping*(self: Emitter, msg: string) {.signal.}

QtObject:
  type Receiver = ref object of QObject
    count: int
    last: string

  proc delete(self: Receiver) =
    self.QObject.delete

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

  proc onPing*(self: Receiver, msg: string) {.slot.} =
    inc self.count
    self.last = msg

# A QtObject that wires an *external* signal to its own slot inside its constructor,
# using the method-form connect — regression guard for the seaqt migration.
# The slot is declared BEFORE the constructor so the connect call sees it as a
# proper slot symbol (required for the string-based dispatch path in the connect macro).
QtObject:
  type SelfWired = ref object of QObject
    source: Emitter
    receivedCount: int
    receivedMsg: string

  proc delete(self: SelfWired) =
    self.QObject.delete

  proc onExternalPing*(self: SelfWired, msg: string) {.slot.} =
    inc self.receivedCount
    self.receivedMsg = msg

  proc newSelfWired(source: Emitter): SelfWired =
    new(result, delete)
    result.QObject.setup
    result.source = source
    # Method-form connect inside a QtObject constructor — the pattern used across
    # notifications_manager, keycard_popup/view, etc. after the seaqt migration.
    discard QObject.connect(source, ping, result, onExternalPing)

suite "nimqml QObject.connect (seaqt-backed)":
  test "method-arg connect with AutoConnection delivers synchronously":
    let e = newEmitter()
    let r = newReceiver()
    discard QObject.connect(e, ping, r, onPing)
    e.ping("hello")
    check r.count == 1
    check r.last == "hello"

  test "QueuedConnection is honored (defers; would fire synchronously if type were dropped)":
    let e = newEmitter()
    let r = newReceiver()
    discard QObject.connect(e, ping, r, onPing, ConnectionType.QueuedConnection)
    e.ping("queued")
    check r.count == 0

  test "method-form connect wired inside QtObject constructor delivers to self slot":
    let e = newEmitter()
    let sw = newSelfWired(e)
    e.ping("internal-wire")
    check sw.receivedCount == 1
    check sw.receivedMsg == "internal-wire"
