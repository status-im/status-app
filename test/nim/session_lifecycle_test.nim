## Lifecycle contract of the in-process logout (SessionLifecycle): step order, the
## non-blocking drain and its timeout, backend logout/initialize failures, the quit
## latch, and the auto-login policy handed to the next session.

import unittest, results, std/sequtils
import app/boot/session_lifecycle

const Deadline = 1000'i64

type Fake = ref object
  calls: seq[string]
  drained: bool
  initializeResult: Result[void, string]
  readyPolicy: AutoLoginPolicy
  exitedLoggedOut: bool

proc newFake(): (Fake, SessionLifecycle) =
  let fake = Fake(drained: true, initializeResult: Result[void, string].ok())
  var ops: SessionOps
  ops.releaseUi = proc() = fake.calls.add("releaseUi")
  ops.stopActivity = proc() = fake.calls.add("stopActivity")
  ops.isDrained = proc(): bool = fake.drained
  ops.finishDrain = proc() = fake.calls.add("finishDrain")
  ops.startBackendLogout = proc() = fake.calls.add("backendLogout")
  ops.dispose = proc() = fake.calls.add("dispose")
  ops.initialize = proc(): Result[void, string] =
    fake.calls.add("initialize")
    fake.initializeResult
  ops.sessionReady = proc(policy: AutoLoginPolicy) =
    fake.calls.add("ready")
    fake.readyPolicy = policy
  ops.drainTimedOut = proc() = fake.calls.add("drainTimedOut")
  ops.failed = proc(step: SessionStep, error: string) = fake.calls.add("failed:" & $step)
  ops.exit = proc(backendLoggedOut: bool) =
    fake.calls.add("exit")
    fake.exitedLoggedOut = backendLoggedOut
  ops.hardExit = proc(backendLoggedOut: bool) =
    fake.calls.add("hardExit")
    fake.exitedLoggedOut = backendLoggedOut
  (fake, newSessionLifecycle(ops, Deadline))

let loggedOut = Result[void, string].ok()
let logoutFailed = Result[void, string].err("node stop failed")

suite "session lifecycle":

  test "logout runs every step in order and hands the policy to the next session":
    let (fake, lc) = newFake()
    check lc.requestEnd(AutoLoginPolicy.Disabled)
    check lc.state == SessionState.ReleasingUi
    lc.onUiReleased(0)
    check lc.state == SessionState.BackendLogout
    lc.onBackendLogoutDone(loggedOut)
    check lc.state == SessionState.Active
    check fake.calls == @["releaseUi", "stopActivity", "finishDrain", "backendLogout", "dispose",
      "initialize", "ready"]
    check fake.readyPolicy == AutoLoginPolicy.Disabled

  test "relogin hands AllowOnce to the next session":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.AllowOnce)
    lc.onUiReleased(0)
    lc.onBackendLogoutDone(loggedOut)
    check fake.readyPolicy == AutoLoginPolicy.AllowOnce

  test "ending waits for the UI to release the session":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onDrainTick(0)
    check fake.calls == @["releaseUi"]

  test "a second request during a transition is ignored":
    let (fake, lc) = newFake()
    check lc.requestEnd(AutoLoginPolicy.Disabled)
    check not lc.requestEnd(AutoLoginPolicy.AllowOnce)
    lc.onUiReleased(0)
    check not lc.requestEnd(AutoLoginPolicy.AllowOnce)
    lc.onBackendLogoutDone(loggedOut)
    check fake.readyPolicy == AutoLoginPolicy.Disabled
    check fake.calls.count("releaseUi") == 1

  test "the drain waits for running tasks without blocking":
    let (fake, lc) = newFake()
    fake.drained = false
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    check lc.state == SessionState.Draining
    lc.onDrainTick(Deadline - 1)
    check lc.state == SessionState.Draining
    check "finishDrain" notin fake.calls

    fake.drained = true
    lc.onDrainTick(Deadline - 1)
    check lc.state == SessionState.BackendLogout
    check fake.calls[^2 .. ^1] == @["finishDrain", "backendLogout"]

  test "a drain past the deadline times out and resumes once drained":
    let (fake, lc) = newFake()
    fake.drained = false
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    lc.onDrainTick(Deadline)
    check lc.state == SessionState.DrainTimeout
    check "drainTimedOut" in fake.calls
    check "finishDrain" notin fake.calls

    lc.onDrainTick(5 * Deadline)
    check fake.calls.count("drainTimedOut") == 1

    fake.drained = true
    lc.onDrainTick(6 * Deadline)
    check lc.state == SessionState.BackendLogout

  test "quit during a drain timeout hard-exits without tearing the pool down":
    let (fake, lc) = newFake()
    fake.drained = false
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    lc.onDrainTick(Deadline)
    check lc.requestQuit()
    check lc.state == SessionState.Exiting
    check fake.calls[^1] == "hardExit"
    check not fake.exitedLoggedOut
    check "finishDrain" notin fake.calls

  test "quit latched while draining hard-exits at the deadline":
    let (fake, lc) = newFake()
    fake.drained = false
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    check lc.requestQuit()
    lc.onDrainTick(Deadline)
    check fake.calls[^1] == "hardExit"
    check "drainTimedOut" notin fake.calls

  test "quit latched before the backend logout exits once it completes":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    check lc.state == SessionState.BackendLogout
    check lc.requestQuit()
    lc.onBackendLogoutDone(loggedOut)
    check lc.state == SessionState.Exiting
    check fake.calls[^1] == "exit"
    check fake.exitedLoggedOut
    check "dispose" notin fake.calls

  test "quit latched before a failed backend logout exits without a confirmed logout":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    check lc.requestQuit()
    lc.onBackendLogoutDone(logoutFailed)
    check fake.calls[^1] == "exit"
    check not fake.exitedLoggedOut

  test "quit while active is left to the caller":
    let (fake, lc) = newFake()
    check not lc.requestQuit()
    check fake.calls.len == 0

  test "quit before the UI released the session is left to the caller":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    check not lc.requestQuit()
    check fake.calls == @["releaseUi"]

  test "a failed backend logout neither disposes nor reports a ready session":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.AllowOnce)
    lc.onUiReleased(0)
    lc.onBackendLogoutDone(logoutFailed)
    check lc.state == SessionState.Failed
    check fake.calls[^1] == "failed:BackendLogout"
    check "dispose" notin fake.calls
    check "ready" notin fake.calls

  test "retrying a failed backend logout continues the transition":
    let (fake, lc) = newFake()
    discard lc.requestEnd(AutoLoginPolicy.AllowOnce)
    lc.onUiReleased(0)
    lc.onBackendLogoutDone(logoutFailed)
    lc.retry()
    check lc.state == SessionState.BackendLogout
    lc.onBackendLogoutDone(loggedOut)
    check lc.state == SessionState.Active
    check fake.readyPolicy == AutoLoginPolicy.AllowOnce

  test "a failed initialization reports no ready session and can be retried":
    let (fake, lc) = newFake()
    fake.initializeResult = Result[void, string].err("InitializeApplication failed")
    discard lc.requestEnd(AutoLoginPolicy.AllowOnce)
    lc.onUiReleased(0)
    lc.onBackendLogoutDone(loggedOut)
    check lc.state == SessionState.Failed
    check fake.calls[^1] == "failed:Initialize"
    check "ready" notin fake.calls

    fake.initializeResult = Result[void, string].ok()
    lc.retry()
    check lc.state == SessionState.Active
    check fake.calls.count("dispose") == 1
    check fake.calls[^1] == "ready"

  test "quit from a failed state exits with the backend logout outcome":
    let (fake, lc) = newFake()
    fake.initializeResult = Result[void, string].err("InitializeApplication failed")
    discard lc.requestEnd(AutoLoginPolicy.Disabled)
    lc.onUiReleased(0)
    lc.onBackendLogoutDone(loggedOut)
    check lc.requestQuit()
    check fake.calls[^1] == "exit"
    check fake.exitedLoggedOut

  test "events that don't belong to the current state are ignored":
    let (fake, lc) = newFake()
    lc.onUiReleased(0)
    lc.onDrainTick(0)
    lc.onBackendLogoutDone(loggedOut)
    lc.retry()
    check lc.state == SessionState.Active
    check fake.calls.len == 0
