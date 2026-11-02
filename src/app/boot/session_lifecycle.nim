## Lifecycle contract of an in-process logout: ends the current app session and starts
## the next one without restarting the process.
##
##   Active ─end─▶ ReleasingUi ─▶ Draining ─▶ BackendLogout ─▶ Disposing ─▶ Initializing ─▶ Active
##                                 │ ▲            │                            │
##                        deadline ▼ │ drained    └────────── failure ─────────┴─▶ Failed
##                              DrainTimeout
##
## Pure state machine: every side effect is an injected `SessionOps` operation, and the
## owner (SessionHost) feeds it events — the UI releasing the session, drain ticks, the
## backend logout completing. One transition at a time; requests that arrive during a
## transition are ignored, except Quit, which is latched until a safe point (or, before
## anything was torn down, left to the regular quit path).

import results, chronicles

logScope:
  topics = "session-lifecycle"

type
  SessionState* {.pure.} = enum
    Active
    ReleasingUi   ## waiting for the UI to release the session
    Draining      ## waiting for the session's async work to finish, GUI responsive
    DrainTimeout  ## still draining past the deadline; the user may quit
    BackendLogout ## the backend logs out on a worker thread
    Disposing
    Initializing
    Failed        ## a step failed; the user may retry it or quit
    Exiting

  SessionStep* {.pure.} = enum
    BackendLogout
    Initialize

  AutoLoginPolicy* {.pure.} = enum
    ColdStart ## process start: the regular startup rule decides
    AllowOnce ## relogin: one silent login if a stored credential exists
    Disabled  ## logout: stop at the login screen

  SessionOps* = object
    releaseUi*: proc()
      ## Unload the session UI; answered with `onUiReleased`.
    stopActivity*: proc()
      ## End the session generation, close task admission, stop the session's native
      ## producers (timers, keycard) and stop accepting its signals.
    isDrained*: proc(): bool
      ## No task of the ended session is still running.
    finishDrain*: proc()
      ## Tear the drained pool down; returns at once.
    startBackendLogout*: proc()
      ## Log the backend out off the GUI thread; answered with `onBackendLogoutDone`.
    dispose*: proc()
      ## Delete the ended session and reset per-account process state.
    initialize*: proc(): Result[void, string]
      ## Build the next session.
    sessionReady*: proc(policy: AutoLoginPolicy)
    drainTimedOut*: proc()
    failed*: proc(step: SessionStep, error: string)
    exit*: proc(backendLoggedOut: bool)
      ## Quit at a safe point: nothing of the ended session is running anymore.
    hardExit*: proc(backendLoggedOut: bool)
      ## Quit while tasks of the ended session may still run: no teardown that waits
      ## for them. Without a confirmed backend logout the backend must not outlive the
      ## process logged in (Android runs it in a separate service process).

  SessionLifecycle* = ref object
    ops: SessionOps
    state: SessionState
    policy: AutoLoginPolicy
    quitLatched: bool
    backendLoggedOut: bool
    failedStep: SessionStep
    drainDeadlineMs: int64
    drainStartedMs: int64

proc newSessionLifecycle*(ops: SessionOps, drainDeadlineMs: int64): SessionLifecycle =
  SessionLifecycle(ops: ops, state: SessionState.Active, drainDeadlineMs: drainDeadlineMs)

proc state*(self: SessionLifecycle): SessionState =
  self.state

proc isTransitioning*(self: SessionLifecycle): bool =
  self.state != SessionState.Active

proc enter(self: SessionLifecycle, state: SessionState) =
  debug "session state", previous = self.state, state
  self.state = state

proc fail(self: SessionLifecycle, step: SessionStep, error: string) =
  error "ending the session failed", step, error
  self.failedStep = step
  self.enter(SessionState.Failed)
  self.ops.failed(step, error)

proc exitAtSafePoint(self: SessionLifecycle) =
  self.enter(SessionState.Exiting)
  self.ops.exit(self.backendLoggedOut)

proc initialize(self: SessionLifecycle) =
  self.enter(SessionState.Initializing)
  let initialized = self.ops.initialize()
  if initialized.isErr:
    self.fail(SessionStep.Initialize, initialized.error)
    return
  self.enter(SessionState.Active)
  self.ops.sessionReady(self.policy)

proc startBackendLogout(self: SessionLifecycle) =
  self.enter(SessionState.BackendLogout)
  self.ops.startBackendLogout()

proc requestEnd*(self: SessionLifecycle, policy: AutoLoginPolicy): bool =
  ## Starts ending the session; the next one starts with `policy`. Ignored, returning
  ## false, unless the session is active.
  if self.state != SessionState.Active:
    warn "ignoring a session end request during a transition", state = self.state
    return false
  self.policy = policy
  self.quitLatched = false
  self.backendLoggedOut = false
  self.enter(SessionState.ReleasingUi)
  self.ops.releaseUi()
  true

proc onDrainTick*(self: SessionLifecycle, nowMs: int64) =
  if self.state notin {SessionState.Draining, SessionState.DrainTimeout}:
    return
  if self.ops.isDrained():
    self.ops.finishDrain()
    self.startBackendLogout()
  elif self.state == SessionState.Draining and nowMs - self.drainStartedMs >= self.drainDeadlineMs:
    self.enter(SessionState.DrainTimeout)
    if self.quitLatched:
      # The user already asked to quit; don't make them ask again.
      self.enter(SessionState.Exiting)
      self.ops.hardExit(self.backendLoggedOut)
    else:
      self.ops.drainTimedOut()

proc onUiReleased*(self: SessionLifecycle, nowMs: int64) =
  if self.state != SessionState.ReleasingUi:
    return
  self.ops.stopActivity()
  self.drainStartedMs = nowMs
  self.enter(SessionState.Draining)
  self.onDrainTick(nowMs)

proc onBackendLogoutDone*(self: SessionLifecycle, loggedOut: Result[void, string]) =
  if self.state != SessionState.BackendLogout:
    return
  self.backendLoggedOut = loggedOut.isOk
  if self.quitLatched:
    self.exitAtSafePoint()
  elif loggedOut.isErr:
    # The backend may be partially torn down: neither resume the ended session nor
    # build the next one on top of it.
    self.fail(SessionStep.BackendLogout, loggedOut.error)
  else:
    self.enter(SessionState.Disposing)
    self.ops.dispose()
    self.initialize()

proc retry*(self: SessionLifecycle) =
  ## Reruns the failed step.
  if self.state != SessionState.Failed:
    return
  case self.failedStep
  of SessionStep.BackendLogout:
    self.startBackendLogout()
  of SessionStep.Initialize:
    self.initialize()

proc requestQuit*(self: SessionLifecycle): bool =
  ## Returns false when no transition runs and the caller quits the usual way.
  ## Otherwise the lifecycle quits once that is safe and returns true.
  case self.state
  of SessionState.Active, SessionState.ReleasingUi:
    # Nothing of the session is torn down yet while the UI releases it, so the regular
    # quit path (full teardown, backend logout) applies. Waiting could also block the
    # quit forever if the UI never released the session.
    false
  of SessionState.Draining, SessionState.BackendLogout:
    info "quit requested during a session transition, deferred", state = self.state
    self.quitLatched = true
    true
  of SessionState.DrainTimeout:
    self.enter(SessionState.Exiting)
    self.ops.hardExit(self.backendLoggedOut)
    true
  of SessionState.Failed:
    self.exitAtSafePoint()
    true
  of SessionState.Disposing, SessionState.Initializing, SessionState.Exiting:
    # Disposing and Initializing complete within one event; nothing can arrive then.
    true
