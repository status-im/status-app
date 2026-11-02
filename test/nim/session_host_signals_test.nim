## SessionHost is the permanent receiver of the status-go and keycard callbacks. Signals
## of a backend session that ended (logout) must not reach the next app session, even
## when they were already queued to the GUI thread before the logout; signals the next
## backend session emits while no app session receives them are delivered once one does.
## Runs over the real StatusQ queued-invoke bridge.

import unittest, os
import nimqml
import app/boot/session_host
import app/core/signal_epoch
import app/core/signal_handler
import backend/general as status_general
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

discard QCoreApplication.create()

proc pump() =
  for _ in 0 ..< 30:
    QCoreApplication.processEvents()
    sleep(1)

proc envelope(typ: string, epoch: uint64): string =
  """{"type":"""" & typ & """","epoch":""" & $epoch & ""","event":{}}"""

type Collected = ref object
  signals: seq[string]
  keycard: seq[string]

proc receiversInto(c: Collected): SessionReceivers =
  SessionReceivers(
    signal: proc(s: string) = c.signals.add(s),
    keycardSignal: proc(s: string) = c.keycard.add(s))

proc post(host: SessionHost, signal: string) =
  # What the status-go C callback does.
  signal_handler(cast[pointer](host.vptr), signal.cstring, "receiveSignal")

suite "SessionHost signal delivery":

  setup:
    acceptSignalEpoch(1)
    let host = newSessionHost()
    let first = Collected()
    host.attachSession(first.receiversInto())

  test "signals of the current backend session are delivered":
    host.post(envelope("node.ready", 1))
    pump()
    check first.signals == @[envelope("node.ready", 1)]

  test "a signal queued before a logout never reaches the next session":
    host.post(envelope("messages.new", 1))   # session A, still queued
    host.detachSession()
    acceptSignalEpoch(2)                      # the backend logged out
    let second = Collected()
    host.attachSession(second.receiversInto())
    host.post(envelope("node.ready", 2))
    pump()
    check first.signals.len == 0
    check second.signals == @[envelope("node.ready", 2)]

  test "signals the next backend session emits during the logout are delivered":
    host.detachSession()
    # Emitted by the re-initialized backend before the client learned epoch 2.
    host.post(envelope("mediaserver.started", 2))
    host.post(envelope("node.stopped", 1))
    pump()
    acceptSignalEpoch(2)
    let second = Collected()
    host.attachSession(second.receiversInto())
    check second.signals == @[envelope("mediaserver.started", 2)]

  test "a signal without an epoch is not delivered":
    host.post("""{"type":"node.ready","event":{}}""")
    pump()
    check first.signals.len == 0

  test "keycard signals of an ended session are dropped":
    deliverKeycardSignal(cast[pointer](host.vptr), """{"type":"status-changed"}""")
    host.detachSession()
    advanceKeycardEpoch()
    let second = Collected()
    host.attachSession(second.receiversInto())
    deliverKeycardSignal(cast[pointer](host.vptr), """{"type":"channel-state-changed"}""")
    pump()
    check first.keycard.len == 0
    check second.keycard == @["""{"type":"channel-state-changed"}"""]

suite "SessionHost epoch acceptance":

  test "accepting the next epoch while attached delivers what was held for it":
    # Logout outside a session transition (keycard conversion during onboarding).
    acceptSignalEpoch(1)
    let host = newSessionHost()
    let c = Collected()
    host.attachSession(c.receiversInto())
    host.post(envelope("mediaserver.started", 2))
    pump()
    check c.signals.len == 0
    acceptSignalEpoch(2)
    check c.signals == @[envelope("mediaserver.started", 2)]

  test "without a known epoch the first stamped signal sets it":
    acceptSignalEpoch(NoEpoch)
    let host = newSessionHost()
    let c = Collected()
    host.attachSession(c.receiversInto())
    host.post(envelope("node.ready", 4))
    host.post(envelope("late", 3))
    pump()
    check acceptedSignalEpoch() == 4
    check c.signals == @[envelope("node.ready", 4)]

suite "backend logout response":

  test "carries the next signal epoch":
    let r = status_general.parseLogoutResponse("""{"error":"","signalEpoch":5}""")
    check r.error == ""
    check r.signalEpoch == 5

  test "a failed logout still carries the epoch the backend moved to":
    let r = status_general.parseLogoutResponse("""{"error":"media server failed","signalEpoch":5}""")
    check r.error == "media server failed"
    check r.signalEpoch == 5

  test "a response without an epoch is an error":
    check status_general.parseLogoutResponse("""{"error":""}""").error.len > 0
    check status_general.parseLogoutResponse("not json").error.len > 0
