## SessionHost driving the session lifecycle with its real parts: the drain is polled
## by a timer on the event loop (the GUI keeps processing events while a task of the
## ended session stays blocked, also past the deadline) and the backend logs out on
## its own thread, whose response comes back through the queued bridge. An integration
## test on purpose: the lifecycle's rules are covered deterministically by
## session_lifecycle_test; this one proves the real timer, thread and bridge.

import unittest, os, results
import nimqml
import app/boot/session_host
import app/core/signal_epoch
import app/core/keycard_epoch
import app/core/signal_handler
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

discard QCoreApplication.create()

# Stands in for status-keycard-qt: it queues its events through the GUI event loop
# before they reach the C callback, which stamps them only then.
QtObject:
  type KeycardLibrary = ref object of QObject
    host: pointer

  proc delete(self: KeycardLibrary)

  proc newKeycardLibrary(host: SessionHost): KeycardLibrary =
    new(result, delete)
    result.QObject.setup
    result.host = cast[pointer](host.vptr)

  proc delete(self: KeycardLibrary) =
    self.QObject.delete

  proc emitQueued*(self: KeycardLibrary, event: string) {.slot.} =
    deliverKeycardSignal(self.host, event.cstring)

proc queueKeycardEvent(library: KeycardLibrary, event: string) =
  signal_handler(cast[pointer](library.vptr), event.cstring, "emitQueued")

const Deadline = 100'i64

type Fake = ref object
  calls: seq[string]
  keycardEvents: seq[string]
  drained: bool
  failedStep: string

proc pumpUntil(ms: int, done: proc(): bool): int =
  ## Processes events until `done` or `ms` elapsed; returns the event-loop turns,
  ## which show that the GUI stayed responsive.
  var waited = 0
  while not done() and waited < ms:
    QCoreApplication.processEvents()
    sleep(1)
    inc waited
    inc result

proc newHostWithFakes(fakeBackend = false): (SessionHost, Fake) =
  ## `fakeBackend`: the backend logout never answers on its own; tests answer it
  ## through onBackendLogoutResponse.
  let host = newSessionHost(drainDeadlineMs = Deadline, logoutDeadlineMs = Deadline)
  let fake = Fake()
  var ops: SessionOps
  if fakeBackend:
    ops.startBackendLogout = proc() = fake.calls.add("backendLogout")
  ops.releaseUi = proc() =
    fake.calls.add("releaseUi")
    host.sessionUiReleased()
  ops.stopActivity = proc() = fake.calls.add("stopActivity")
  ops.isDrained = proc(): bool = fake.drained
  ops.finishDrain = proc() = fake.calls.add("finishDrain")
  ops.dispose = proc() = fake.calls.add("dispose")
  ops.sessionReady = proc(policy: AutoLoginPolicy) = fake.calls.add("ready")
  ops.drainTimedOut = proc() = fake.calls.add("drainTimedOut")
  ops.logoutTimedOut = proc() = fake.calls.add("logoutTimedOut")
  ops.failed = proc(step: SessionStep, error: string) =
    fake.calls.add("failed")
    fake.failedStep = $step
  ops.exit = proc(backendLoggedOut: bool) = fake.calls.add("exit")
  ops.hardExit = proc(backendLoggedOut: bool) = fake.calls.add("hardExit")
  host.setOps(ops, proc(): Result[SessionReceivers, string] =
    fake.calls.add("initialize")
    ok(SessionReceivers(signal: proc(s: string) = discard,
      keycardSignal: proc(s: string) = fake.keycardEvents.add(s))))
  (host, fake)

suite "SessionHost lifecycle":

  test "a task blocked past the deadline times out while events keep flowing":
    let (host, fake) = newHostWithFakes()
    defer: host.delete()
    check host.requestEnd(AutoLoginPolicy.Disabled)
    check host.state == SessionState.Draining

    let turns = pumpUntil(10 * Deadline.int, proc(): bool =
      host.state == SessionState.DrainTimeout)
    check host.state == SessionState.DrainTimeout
    check "drainTimedOut" in fake.calls
    check turns > 10

    # Still blocked: keeps waiting, the pool is not torn down.
    discard pumpUntil(3 * Deadline.int, proc(): bool = false)
    check host.state == SessionState.DrainTimeout
    check "finishDrain" notin fake.calls

    # Quit hard-exits at once, without waiting for the task.
    check host.requestQuit()
    check fake.calls[^1] == "hardExit"

  test "once drained, the backend logs out on its own thread and the transition completes":
    let (host, fake) = newHostWithFakes()
    defer: host.delete()
    check host.readBackendSignalEpoch().isOk
    let epochBefore = acceptedSignalEpoch()
    fake.drained = false
    check host.requestEnd(AutoLoginPolicy.Disabled)
    discard pumpUntil(2 * Deadline.int, proc(): bool = false)
    fake.drained = true

    discard pumpUntil(10_000, proc(): bool =
      host.state notin {SessionState.Draining, SessionState.DrainTimeout,
        SessionState.BackendLogout})
    check "finishDrain" in fake.calls
    # The real status-go Logout ran on the logout thread; its response came back
    # through the queued bridge with the next signal epoch.
    check host.state == SessionState.Active
    check fake.calls[^3 .. ^1] == @["dispose", "initialize", "ready"]
    check acceptedSignalEpoch() == epochBefore + 1

  test "a keycard event queued before the session ended does not reach the next one":
    let (host, fake) = newHostWithFakes()
    defer: host.delete()
    check host.readBackendSignalEpoch().isOk
    let library = newKeycardLibrary(host)
    defer: library.delete()

    fake.drained = true
    library.queueKeycardEvent("""{"type":"channel-state-changed","event":{"state":"reading"}}""")
    check host.requestEnd(AutoLoginPolicy.Disabled)
    discard pumpUntil(10_000, proc(): bool = host.state == SessionState.Active)
    check host.state == SessionState.Active
    check fake.keycardEvents.len == 0

    library.queueKeycardEvent("""{"type":"channel-state-changed","event":{"state":"idle"}}""")
    discard pumpUntil(1_000, proc(): bool = fake.keycardEvents.len > 0)
    check fake.keycardEvents == @["""{"type":"channel-state-changed","event":{"state":"idle"}}"""]

  test "a backend logout that never answers times out and a late answer completes it":
    let (host, fake) = newHostWithFakes(fakeBackend = true)
    defer: host.delete()
    fake.drained = true
    check host.requestEnd(AutoLoginPolicy.Disabled)
    check host.state == SessionState.BackendLogout

    discard pumpUntil(20 * Deadline.int, proc(): bool = host.state == SessionState.LogoutTimeout)
    check host.state == SessionState.LogoutTimeout
    check "logoutTimedOut" in fake.calls

    host.onBackendLogoutResponse("""{"error":"","signalEpoch":""" & $(acceptedSignalEpoch() + 1) & "}")
    check host.state == SessionState.Active
    check fake.calls[^1] == "ready"

  test "retrying a failed backend logout watches its deadline again":
    let (host, fake) = newHostWithFakes(fakeBackend = true)
    defer: host.delete()
    fake.drained = true
    check host.requestEnd(AutoLoginPolicy.Disabled)
    host.onBackendLogoutResponse("""{"error":"node stop failed","signalEpoch":0}""")
    check host.state == SessionState.Failed

    host.retry()
    check host.state == SessionState.BackendLogout
    discard pumpUntil(20 * Deadline.int, proc(): bool = host.state == SessionState.LogoutTimeout)
    check host.state == SessionState.LogoutTimeout
