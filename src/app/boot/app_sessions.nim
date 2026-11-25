## The app sessions of the process: builds each one (StatusFoundation + AppController),
## ends it on logout and builds the next, with SessionHost driving the lifecycle.

import std/[atomics, os, monotimes, times]
import nimqml, chronicles, results

import app/boot/app_controller
import app/boot/session_host
import app/boot/session_view
import app/core/main
import app/core/custom_urls/urls_manager
import app/global/global_singleton
import app/android/lifecycle as android_lifecycle
import constants as main_constants
from app/modules/shared_modules/collectibles/controller import releaseAllRequestIds
from app_service/service/keycardV2/service import receiveKeycardSignalV2
import backend/core as backend_core
import status_go

logScope:
  topics = "app-sessions"

proc c_Exit(code: cint) {.importc: "_Exit", header: "<stdlib.h>", noreturn.}

const HardExitLogoutDeadlineMs = 3_000

type
  AppSession = ref object
    foundation: StatusFoundation
    controller: AppController
    signalsVariant: QVariant

  AppSessions* = ref object
    host: SessionHost
    view*: SessionView
    urlsManager: UrlsManager
    current: AppSession
    # The backend was logged out by an ended session: the process exit must not log it
    # out again.
    backendLoggedOut: bool

proc current*(self: AppSessions): AppSession = self.current
proc foundation*(self: AppSession): StatusFoundation = self.foundation

proc newAppSession(urlsManager: UrlsManager): AppSession =
  result = AppSession()
  result.foundation = newStatusFoundation()
  result.foundation.attachUrlsManager(urlsManager)
  result.controller = newAppController(result.foundation)
  result.signalsVariant = newQVariant(result.foundation.signalsManager)
  singletonInstance.setSessionContextProperty("signals", result.signalsVariant)

proc receivers(self: AppSession): SessionReceivers =
  let session = self
  SessionReceivers(
    signal: proc(signal: string) = session.foundation.signalsManager.processSignal(signal),
    keycardSignal: proc(signal: string) =
      featureGuard KEYCARD_ENABLED:
        session.controller.keycardServiceV2.receiveKeycardSignalV2(signal)
  )

proc delete(self: AppSession, logoutBackend: bool) =
  self.foundation.threadpool.teardown()
  self.controller.delete(logoutBackend)
  self.foundation.delete()
  self.signalsVariant.delete()

proc disposeSession(self: AppSessions) =
  ## Deletes the ended session (its UI is unloaded, its work drained, the backend logged
  ## out) and resets the per-account state of the process. The settings file stays bound for
  ## the login screen, which preselects the same profile.
  self.urlsManager.detachSession()
  singletonInstance.clearSessionContextProperties()
  if not self.current.isNil:
    self.current.delete(logoutBackend = false)
    self.current = nil
  singletonInstance.localAccountSettings.flush()
  backend_core.DB_BLOCKED_DUE_TO_PROFILE_MIGRATION = false
  releaseAllRequestIds()
  # The ended profile's debug mode must not carry over to the login screen and the next
  # profile.
  if not main_constants.runtimeLogLevelSet():
    setLogLevel(main_constants.defaultLogLevel())

proc initializeSession(self: AppSessions): Result[SessionReceivers, string] =
  if not self.current.isNil:
    # Retrying after a failed attempt: its partly built session goes first.
    self.disposeSession()
  try:
    self.current = newAppSession(self.urlsManager)
    # A failed start keeps self.current: Retry disposes it, quitting deletes it.
    ? self.current.controller.start(firstSession = false)
    ok(self.current.receivers())
  except Exception as e:
    error "building the next session failed", error = e.msg
    err(e.msg)

var hardExitLogoutDone: Atomic[bool]

proc hardExitLogout() {.thread.} =
  discard status_go.logout()
  hardExitLogoutDone.store(true)

proc logoutWithDeadline() =
  ## Best effort before a hard exit: the backend's own logout may hang (that's why the
  ## exit is hard), so it gets a bounded wait on a thread of its own.
  var thread: Thread[void]
  hardExitLogoutDone.store(false)
  createThread(thread, hardExitLogout)
  let deadline = getMonoTime() + initDuration(milliseconds = HardExitLogoutDeadlineMs)
  while not hardExitLogoutDone.load() and getMonoTime() < deadline:
    sleep(20)

proc hardExit(backend: BackendLogoutStatus) =
  ## Quits while work of the ended session may still run (or the backend logout hangs):
  ## nothing that waits for it. The backend must not outlive the process logged in.
  if backend != BackendLogoutStatus.Done:
    when defined(android):
      # status-go runs in a separate service process: stop it.
      android_lifecycle.stopBackgroundService()
    else:
      # A logout still running past its deadline holds the backend: a second one would
      # only wait for it.
      if backend == BackendLogoutStatus.NotStarted:
        logoutWithDeadline()
  info "hard exit after ending the session", backend
  c_Exit(0)

proc exitAtSafePoint(self: AppSessions, backendLoggedOut: bool) =
  ## Quits once nothing of the ended session runs anymore: the regular teardown.
  self.backendLoggedOut = backendLoggedOut
  when defined(android):
    if not backendLoggedOut:
      android_lifecycle.stopBackgroundService()
  singletonInstance.application.quit()

proc newAppSessions*(host: SessionHost, urlsManager: UrlsManager): AppSessions =
  let self = AppSessions(host: host, urlsManager: urlsManager)
  self.view = newSessionView(host)

  var ops: SessionOps
  ops.releaseUi = proc() =
    # Links and shares arriving from now on wait for the next session (its appReady)
    # instead of reaching the ended one, whose UI is gone.
    self.urlsManager.detachSession()
    self.view.sessionEnding()
  ops.stopActivity = proc() =
    self.current.controller.stopActivity()
  ops.isDrained = proc(): bool =
    self.current.foundation.threadpool.isIdle()
  ops.finishDrain = proc() =
    self.current.foundation.threadpool.teardown()
  ops.dispose = proc() =
    self.disposeSession()
  ops.sessionReady = proc(policy: AutoLoginPolicy) =
    self.view.sessionReady()
  ops.stateChanged = proc(state: SessionState, failedStep: SessionStep) =
    # Leaving a timeout or failure screen (Retry, a late drain or logout) included.
    self.view.setPhase(phaseOf(state, failedStep))
  ops.exit = proc(backendLoggedOut: bool) =
    self.exitAtSafePoint(backendLoggedOut)
  ops.hardExit = proc(backend: BackendLogoutStatus) =
    hardExit(backend)
  self.view.setIntakeOps(
    hold = proc() = self.urlsManager.detachSession(),
    release = proc() =
      # An ending session (a transition runs) leaves them to the next one.
      if not self.current.isNil and self.host.state == SessionState.Active:
        self.current.foundation.attachUrlsManager(self.urlsManager)
        self.current.foundation.appReady())
  host.setOps(ops, proc(): Result[SessionReceivers, string] = self.initializeSession())
  self

proc startFirstSession*(self: AppSessions) =
  ## At process start: the first session, which loads main.qml.
  self.current = newAppSession(self.urlsManager)
  self.host.attachSession(self.current.receivers())

proc runFirstSession*(self: AppSessions) =
  # At process start a failure stays on the login screen, which reports it (as before).
  discard self.current.controller.start(firstSession = true)

proc delete*(self: AppSessions) =
  ## Process exit: the current session, if any, and the backend unless an ended session
  ## logged it out already.
  if not self.current.isNil:
    self.current.delete(logoutBackend = not self.backendLoggedOut)
    self.current = nil
  self.view.delete()
