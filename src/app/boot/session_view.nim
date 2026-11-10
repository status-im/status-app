## What QML may use of the app sessions. SessionHost itself stays out of QML: its slots
## are backend delivery entry points.

import nimqml, chronicles

import app/boot/session_host
import app/boot/session_lifecycle
import app/global/global_singleton

logScope:
  topics = "session-view"

type
  SessionPhase* {.pure.} = enum
    ## What the window shows about the session (see SessionView.phase). Mirrored by
    ## SessionTransitionView.Phase in QML: keep the order in sync.
    Active        ## the session's UI
    Ending        ## signing out: a progress screen
    DrainTimeout  ## background work of the ended session takes long: keep waiting or quit
    LogoutTimeout ## the backend logout takes long: keep waiting or quit
    LogoutFailed  ## the backend logout failed: retry or quit
    StartFailed   ## logged out, but the next session failed to start: retry or quit

QtObject:
  type SessionView* = ref object of QObject
    host: SessionHost
    phase: SessionPhase

  proc delete*(self: SessionView)

  proc newSessionView*(host: SessionHost): SessionView =
    new(result, delete)
    result.QObject.setup
    result.host = host

  proc delete*(self: SessionView) =
    self.QObject.delete

  proc phaseChanged*(self: SessionView) {.signal.}

  proc getPhase(self: SessionView): int {.slot.} =
    self.phase.int

  QtProperty[int] phase:
    read = getPhase
    notify = phaseChanged

  proc setPhase*(self: SessionView, phase: SessionPhase) =
    self.phase = phase
    self.phaseChanged()

  proc sessionEnding*(self: SessionView) {.signal.}
    ## Unload the session's UI, then call uiReleased().

  proc sessionReady*(self: SessionView) {.signal.}
    ## The next session is set up: load its UI.

  proc uiReleased*(self: SessionView) {.slot.} =
    self.host.sessionUiReleased()

  proc signOut*(self: SessionView): bool {.slot.} =
    ## Ends the session; the login screen follows. False when a transition runs.
    self.host.requestEnd(AutoLoginPolicy.Disabled)

  proc relogin*(self: SessionView): bool {.slot.} =
    ## Ends the session; the next one logs in silently if a credential is stored (to
    ## apply a setting the backend reads at login).
    self.host.requestEnd(AutoLoginPolicy.AllowOnce)

  proc retry*(self: SessionView) {.slot.} =
    self.host.retry()

  proc quit*(self: SessionView): bool {.slot.} =
    ## True when ending the session takes care of quitting; false when the caller quits
    ## the regular way.
    self.host.requestQuit()

  proc allowsAutoLogin*(self: SessionView, keyUid: string): bool {.slot.} =
    ## Whether the login screen may attempt a silent login for `keyUid`: decided by the
    ## policy the current session started with and the persisted rules.
    let blockedBy = autoLoginBlockedBy(self.host.autoLoginPolicy,
      singletonInstance.localAppSettings.getTestEnvironment(),
      singletonInstance.localAppSettings.isAutoLoginSuppressed(keyUid))
    if blockedBy.len > 0:
      info "auto-login disabled", reason = blockedBy
    blockedBy.len == 0
