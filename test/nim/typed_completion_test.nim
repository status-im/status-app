## End-to-end test for the typed task-completion primitive (finishTyped/takeTyped,
## see app/core/tasks/qt) over the *real* StatusQ queued-invoke bridge.
##
## Proves the wiring the pure typed_handoff_test can't: a worker-built object graph
## is delivered to a QObject slot on the GUI thread by handle (no JSON round-trip),
## in emission order under rapid fire, that a handoff drained mid-flight makes the
## slot's claim return nil without crashing, and that finishTyped is a no-op once
## the app is shutting down. Mirrors signal_handler_test's QCoreApplication +
## processEvents harness.

import unittest, os
import nimqml
import app/core/tasks/qt
import app/global/app_lifecycle
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# QObject and make the nimqml QtObject macro below ambiguous.
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

# Pilot payload: a ref graph the worker builds and hands over intact. A dedicated
# task-arg subtype is declared for the pilot per project convention (every new
# threadpool task gets its own AsyncXxxTaskArg, even if empty).
type
  AsyncEchoPilotTaskArg* = ref object of QObjectTaskArg
    seqNo: int

  PilotResultObj = object of RootObj
    seqNo: int
    label: string
    items: seq[int]
  PilotResult = ref PilotResultObj

QtObject:
  type Receiver = ref object of QObject
    lastLabel: string
    lastItemsLen: int
    order: seq[int]
    nilCount: int

  proc delete(self: Receiver)

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

  proc delete(self: Receiver) =
    self.QObject.delete

  proc onTypedDone*(self: Receiver, response: string) {.slot.} =
    let r = takeTyped[PilotResult](response)
    if r.isNil:
      inc self.nilCount
      return
    self.lastLabel = r.label
    self.lastItemsLen = r.items.len
    self.order.add r.seqNo

discard QCoreApplication.create()   # one app for the whole suite

# Simulate a worker completion: build the finished graph, hand it off. In the real
# system this body runs on a threadpool thread; here we invoke it directly since
# the primitive under test is the completion handoff, not the scheduling.
proc completeEcho(r: Receiver, seqNo: int, label: string, n: int) =
  let arg = AsyncEchoPilotTaskArg(vptr: cast[uint](r.vptr), slot: "onTypedDone", seqNo: seqNo)
  var items = newSeq[int](n)
  for i in 0 ..< n:
    items[i] = i
  arg.finishTyped(PilotResult(seqNo: seqNo, label: label, items: items))

proc pump(until: proc(): bool) =
  var spins = 0
  while not until() and spins < 300:
    QCoreApplication.processEvents()
    sleep(2)
    inc spins

suite "typed task completion (end-to-end bridge)":

  test "typed object delivered to the slot by handle, not serialized":
    let r = newReceiver()
    r.completeEcho(1, "hello", 3)
    check r.order.len == 0                     # QueuedConnection: not synchronous
    pump(proc(): bool = r.order.len == 1)
    check r.order == @[1]
    check r.lastLabel == "hello"
    check r.lastItemsLen == 3

  test "rapid fire preserves emission order":
    let r = newReceiver()
    for i in 1 .. 50:
      r.completeEcho(i, "n", 0)
    pump(proc(): bool = r.order.len == 50)
    var expected: seq[int]
    for i in 1 .. 50:
      expected.add i
    check r.order == expected

  test "handoff drained in flight: slot claim returns nil, no crash":
    let r = newReceiver()
    r.completeEcho(99, "late", 1)              # parked + slot invoke queued
    drainHandoffs()                            # shutdown sweep before slot runs
    pump(proc(): bool = r.nilCount >= 1)
    check r.order.len == 0                      # drained object never applied
    check r.nilCount == 1                       # slot ran, claim nil-safe

  test "takeTyped returns nil on a malformed handle string (never raises)":
    # ADR 0004 contract: takeTyped is nil-safe for unknown/claimed/drained AND
    # malformed handles — the GUI-thread completion slot must never raise.
    for garbage in ["", "not-a-number", "12abc", "-1", "18446744073709551616999"]:
      let claimed = takeTyped[PilotResult](garbage)
      check claimed.isNil

  test "finishTyped is a no-op once shutting down":
    # Kept last: markShuttingDown flips a process-global that later completions
    # would also observe.
    let r = newReceiver()
    markShuttingDown()
    r.completeEcho(7, "ignored", 1)            # early-returns; nothing parked/queued
    pump(proc(): bool = r.order.len > 0 or r.nilCount > 0)
    check r.order.len == 0
    check r.nilCount == 0
