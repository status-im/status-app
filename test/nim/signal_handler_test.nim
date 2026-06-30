## Unit test for the seaqt/StatusQ-backed signal_handler (app/core/signal_handler).
## Proves a queued, by-name slot invocation with a QString arg via QCoreApplication.processEvents.

import unittest, os
import nimqml
import app/core/signal_handler
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# gen_qobject_types.QObject and make the nimqml QtObject macro below ambiguous.
from seaqt/QtCore/gen_qcoreapplication import QCoreApplication, create, processEvents

QtObject:
  type Receiver = ref object of QObject
    got: string
    count: int

  proc delete(self: Receiver) =
    self.QObject.delete

  proc onSig*(self: Receiver, signal: string) {.slot.} =
    self.got = signal
    inc self.count

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

discard QCoreApplication.create()  # one app for the whole suite

suite "signal_handler":

  test "queued by-name invoke delivers the QString to the slot":
    let r = newReceiver()
    # signal_handler(receiver, signal, slot) -> invoke `slot` with `signal` as the QString arg.
    signal_handler(r.vptr, "payload-123".cstring, "onSig".cstring)

    check r.count == 0  # QueuedConnection: not delivered synchronously

    var spins = 0
    while r.count == 0 and spins < 100:
      QCoreApplication.processEvents()
      sleep(5)
      inc spins

    check r.count == 1
    check r.got == "payload-123"
