## Unit tests for the seaqt-backed SingleInstance (app/global/single_instance).
## Exercises first/second-instance detection and the eventReceived forwarding path.
## Needs a QCoreApplication + processEvents pumping to deliver QLocalServer.newConnection.

import unittest, os
import nimqml
import app/global/single_instance
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# gen_qobject_types.QObject and make the nimqml QtObject macro below ambiguous.
from seaqt/QtCore/gen_qcoreapplication import QCoreApplication, create,
  processEvents

# Minimal receiver to capture the forwarded event via a method-form connect.
QtObject:
  type Catcher = ref object of QObject
    received: string
    count: int

  proc delete(self: Catcher) =
    self.QObject.delete

  proc onEvent*(self: Catcher, eventStr: string) {.slot.} =
    self.received = eventStr
    inc self.count

  proc newCatcher(): Catcher =
    new(result, delete)
    result.QObject.setup

discard QCoreApplication.create()  # one app for the whole suite

suite "SingleInstance":

  test "first instance is the owner (not a second instance)":
    let name = "si_test_first_" & $getCurrentProcessId()
    let first = newSingleInstance(name, "")
    check first.secondInstance() == false

  test "a second instance with the same name is detected":
    let name = "si_test_second_" & $getCurrentProcessId()
    let first = newSingleInstance(name, "")
    check first.secondInstance() == false
    let second = newSingleInstance(name, "")
    check second.secondInstance() == true

  test "second instance forwards eventStr to the first via eventReceived":
    let name = "si_test_event_" & $getCurrentProcessId()
    let first = newSingleInstance(name, "")
    let catcher = newCatcher()
    discard QObject.connect(first, eventReceived, catcher, onEvent,
      ConnectionType.AutoConnection)

    discard newSingleInstance(name, "status://open?x=1")

    var spins = 0
    while catcher.count == 0 and spins < 100:
      QCoreApplication.processEvents()
      sleep(5)
      inc spins

    check catcher.count == 1
    check catcher.received == "status://open?x=1\n"

  test "delete() tears down the server so a fresh instance can claim the socket again":
    # Proves delete() releases the QLocalServer deterministically (reset -> ~QLocalServer
    # closes/unlinks the socket). If it didn't, `revived` would either detect a second
    # instance (old server still listening) or fail to listen on the in-use socket.
    let name = "si_test_teardown_" & $getCurrentProcessId()
    let first = newSingleInstance(name, "")
    check first.secondInstance() == false
    first.delete()
    let revived = newSingleInstance(name, "")
    check revived.secondInstance() == false
    revived.delete()
