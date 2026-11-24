## Lifecycle contract of an in-process logout: ends the current app session and starts
## the next one without restarting the process.
##
##   Active ─end─▶ ReleasingUi ─▶ Draining ─▶ BackendLogout ─▶ Disposing ─▶ Initializing ─▶ Active
##                                 │ ▲            │ ▲  │                       │
##                        deadline ▼ │ drained    ▼ │  └──── failure ──────────┴─▶ Failed
##                              DrainTimeout   LogoutTimeout (a late response still completes)
##
## Pure state machine: every side effect is an injected `SessionOps` operation, and the
## owner (SessionHost) feeds it events — the UI releasing the session, ticks, the
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
    LogoutTimeout ## the backend logout is still running past its deadline; the user may quit
    Disposing
    Initializing
    Failed        ## a step failed; the user may retry it or quit
    Exiting

  SessionStep* {.pure.} = enum
    BackendLogout
    Initialize

  BackendLogoutStatus* {.pure.} = enum
    ## Where the backend logout is when the process hard-exits.
    NotStarted ## the session's work did not drain: the backend is still logged in
    Running    ## the logout runs (past its deadline): a second one would only wait for it
    Done       ## the backend is logged out

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
    stateChanged*: proc(state: SessionState, failedStep: SessionStep)
      ## Every state change, before the operation of the new state runs: what the window
      ## shows follows from it. `failedStep` tells which step a Failed state is about.
    exit*: proc(backendLoggedOut: bool)
      ## Quit at a safe point: nothing of the ended session is running anymore.
    hardExit*: proc(backend: BackendLogoutStatus)
      ## Quit while tasks of the ended session, or the backend logout itself, may still
      ## run: no teardown that waits for them (nor joins the logout thread). Without a
      ## confirmed backend logout the backend must not outlive the process logged in:
      ## Android runs it in a separate service process, which must be stopped.

  SessionPhase* {.pure.} = enum
    ## What the window shows about the session (see SessionView.phase). Mirrored by
    ## SessionTransitionView.Phase in QML: keep the order in sync.
    Active        ## the session's UI
    Ending        ## signing out: a progress screen
    DrainTimeout  ## background work of the ended session takes long: keep waiting or quit
    LogoutTimeout ## the backend logout takes long: keep waiting or quit
    LogoutFailed  ## the backend logout failed: retry or quit
    StartFailed   ## logged out, but the next session failed to start: retry or quit

  SessionLifecycle* = ref object
    ops: SessionOps
    state: SessionState
    policy: AutoLoginPolicy
    quitLatched: bool
    backendLoggedOut: bool
    failedStep: SessionStep
    drainDeadlineMs: int64
    drainStartedMs: int64
    logoutDeadlineMs: int64
    logoutStartedMs: int64

proc autoLoginBlockedBy*(policy: AutoLoginPolicy, testEnvironment,
    suppressedAfterSignOut: bool): string =
  ## Why the login screen may not attempt a silent login with a stored credential,
  ## or "" when it may. Test runs never do: the OS secure store is not per data dir.
  ## A sign-out suppresses it until the next explicit login, also across restarts.
  if testEnvironment:
    return "test mode"
  if policy == AutoLoginPolicy.Disabled:
    return "after a logout"
  if suppressedAfterSignOut:
    return "suppressed after a sign-out"
  ""

proc newSessionLifecycle*(ops: SessionOps, drainDeadlineMs, logoutDeadlineMs: int64):
    SessionLifecycle =
  for name, op in ops.fieldPairs:
    doAssert not op.isNil, "session operation not set: " & name
  SessionLifecycle(ops: ops, state: SessionState.Active, drainDeadlineMs: drainDeadlineMs,
    logoutDeadlineMs: logoutDeadlineMs)

proc phaseOf*(state: SessionState, failedStep: SessionStep): SessionPhase =
  ## What the window shows in a lifecycle state.
  case state
  of SessionState.Active: SessionPhase.Active
  of SessionState.DrainTimeout: SessionPhase.DrainTimeout
  of SessionState.LogoutTimeout: SessionPhase.LogoutTimeout
  of SessionState.Failed:
    case failedStep
    of SessionStep.BackendLogout: SessionPhase.LogoutFailed
    of SessionStep.Initialize: SessionPhase.StartFailed
  of SessionState.ReleasingUi, SessionState.Draining, SessionState.BackendLogout,
      SessionState.Disposing, SessionState.Initializing, SessionState.Exiting:
    SessionPhase.Ending

proc state*(self: SessionLifecycle): SessionState =
  self.state

proc isTransitioning*(self: SessionLifecycle): bool =
  self.state != SessionState.Active

proc enter(self: SessionLifecycle, state: SessionState) =
  debug "session state", previous = self.state, state
  self.state = state
  self.ops.stateChanged(state, self.failedStep)

proc fail(self: SessionLifecycle, step: SessionStep, error: string) =
  error "ending the session failed", step, error
  self.failedStep = step
  self.enter(SessionState.Failed)

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

proc startBackendLogout(self: SessionLifecycle, nowMs: int64) =
  self.logoutStartedMs = nowMs
  self.enter(SessionState.BackendLogout)
  self.ops.startBackendLogout()

proc hardExit(self: SessionLifecycle) =
  let backend =
    if self.backendLoggedOut: BackendLogoutStatus.Done
    elif self.state in {SessionState.BackendLogout, SessionState.LogoutTimeout}:
      BackendLogoutStatus.Running
    else: BackendLogoutStatus.NotStarted
  self.enter(SessionState.Exiting)
  self.ops.hardExit(backend)

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

proc onTick*(self: SessionLifecycle, nowMs: int64) =
  ## Polls the drain and watches the deadlines of the drain and the backend logout.
  case self.state
  of SessionState.Draining, SessionState.DrainTimeout:
    if self.ops.isDrained():
      self.ops.finishDrain()
      self.startBackendLogout(nowMs)
    elif self.state == SessionState.Draining and
        nowMs - self.drainStartedMs >= self.drainDeadlineMs:
      if self.quitLatched:
        # The user already asked to quit; don't make them ask again.
        self.hardExit()
      else:
        self.enter(SessionState.DrainTimeout)
  of SessionState.BackendLogout:
    if nowMs - self.logoutStartedMs >= self.logoutDeadlineMs:
      if self.quitLatched:
        self.hardExit()
      else:
        self.enter(SessionState.LogoutTimeout)
  else:
    discard

proc isTicking*(self: SessionLifecycle): bool =
  ## Whether the owner has to keep feeding `onTick`. Not after the backend logout timed
  ## out: only its late response or a quit move on from there.
  self.state in {SessionState.Draining, SessionState.DrainTimeout, SessionState.BackendLogout}

proc logoutTimeLeftMs*(self: SessionLifecycle, nowMs: int64): int64 =
  ## Until the backend logout reaches its deadline: the only tick it needs.
  max(0'i64, self.logoutStartedMs + self.logoutDeadlineMs - nowMs)

proc onUiReleased*(self: SessionLifecycle, nowMs: int64) =
  if self.state != SessionState.ReleasingUi:
    return
  self.ops.stopActivity()
  self.drainStartedMs = nowMs
  self.enter(SessionState.Draining)
  self.onTick(nowMs)

proc onBackendLogoutDone*(self: SessionLifecycle, loggedOut: Result[void, string]) =
  if self.state notin {SessionState.BackendLogout, SessionState.LogoutTimeout}:
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

proc retry*(self: SessionLifecycle, nowMs: int64) =
  ## Reruns the failed step.
  if self.state != SessionState.Failed:
    return
  case self.failedStep
  of SessionStep.BackendLogout:
    self.startBackendLogout(nowMs)
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
  of SessionState.DrainTimeout, SessionState.LogoutTimeout:
    self.hardExit()
    true
  of SessionState.Failed:
    self.exitAtSafePoint()
    true
  of SessionState.Disposing, SessionState.Initializing, SessionState.Exiting:
    # Disposing and Initializing complete within one event; nothing can arrive then.
    true
