## Process-lifetime host of the app sessions (one per login) — see session_lifecycle.
##
## - Permanent receiver of the status-go and keycard callbacks: the raw pointer the C
##   callbacks invoke never dangles across sessions. It forwards only the signals of
##   the current backend session (signal_epoch) to the current app session.
## - Drives `SessionLifecycle`: detaches the ended session from the signals, polls the
##   drain without blocking the GUI, runs the backend logout on its own thread and
##   attaches the next session.

import std/[monotimes, times, strutils]
import nimqml, chronicles, results
from seaqt/qtimer import QTimer, create, setInterval, onTimeout, start, stop, isActive

import app/core/signal_epoch
import app/core/signal_handler
import app/core/keycard_epoch
import app/boot/session_lifecycle
import backend/general as status_general
import status_go

export session_lifecycle

logScope:
  topics = "session-host"

const
  HeldSignalsCapacity = 2000
  TickMs = 50
  DrainDeadlineMs* = 15_000'i64
  # A logout stops the node and closes the databases, normally within seconds. Past
  # this deadline the session's UI offers to quit (LogoutTimeout).
  LogoutDeadlineMs* = 30_000'i64

proc nowMs(): int64 =
  getMonoTime().ticks div 1_000_000

type
  SessionReceivers* = object
    signal*: proc(signal: string)
    keycardSignal*: proc(signal: string)

  BackendLogoutThreadArg = object
    host: pointer

proc backendLogoutThread(arg: BackendLogoutThreadArg) {.thread.} =
  signal_handler(arg.host, status_go.logout().cstring, "onBackendLogoutResponse")

QtObject:
  type SessionHost* = ref object of QObject
    lifecycle: SessionLifecycle
    receivers: SessionReceivers
    hasReceivers: bool
    signals: SignalGate
    keycardSignals: SignalGate
    tickTimer: QTimer
    logoutThread: Thread[BackendLogoutThreadArg]
    logoutThreadRunning: bool
    autoLoginPolicy: AutoLoginPolicy
    drainDeadlineMs: int64
    logoutDeadlineMs: int64
    # Backend and keycard epochs of the session whose activity was stopped, until the
    # next session is attached: their signals are dropped, not held.
    endedEpoch: uint64
    endedKeycardEpoch: uint64

  proc delete*(self: SessionHost)
  proc setup(self: SessionHost)
  proc scheduleTick(self: SessionHost)
  proc deliverHeld(self: SessionHost)

  proc newSessionHost*(drainDeadlineMs = DrainDeadlineMs,
      logoutDeadlineMs = LogoutDeadlineMs): SessionHost =
    new(result, delete)
    result.drainDeadlineMs = drainDeadlineMs
    result.logoutDeadlineMs = logoutDeadlineMs
    result.setup()

  proc setup(self: SessionHost) =
    self.QObject.setup
    self.autoLoginPolicy = AutoLoginPolicy.ColdStart
    self.signals = initSignalGate(HeldSignalsCapacity)
    self.keycardSignals = initSignalGate(HeldSignalsCapacity)
    let host = self
    onSignalEpochAccepted(proc() = host.deliverHeld())
    self.tickTimer = QTimer.create()
    self.tickTimer.setInterval(TickMs)
    self.tickTimer.onTimeout(proc() {.closure, raises: [].} =
      try:
        host.lifecycle.onTick(nowMs())
        host.scheduleTick()
      except Exception as e:
        error "session tick failed", error = e.msg
    )

  proc delete*(self: SessionHost) =
    # Graceful exit only; a hard exit never runs this, so it never waits for the node.
    if self.logoutThreadRunning:
      joinThread(self.logoutThread)
    if not self.tickTimer.h.isNil:
      self.tickTimer.stop()
    onSignalEpochAccepted(nil)
    self.QObject.delete

  proc readBackendSignalEpoch*(self: SessionHost): Result[void, string] =
    ## At process start: accept the signals of the backend session running now.
    let epoch = ?status_general.readSignalEpoch()
    info "accepting backend signals", signalEpoch = epoch
    acceptSignalEpoch(epoch)
    ok()

  proc scheduleTick(self: SessionHost) =
    ## Keeps the tick going while the lifecycle needs it: the drain is polled, the
    ## backend logout only needs one wakeup at its deadline.
    if self.lifecycle.isNil or not self.lifecycle.isTicking():
      self.tickTimer.stop()
      return
    let interval =
      if self.lifecycle.state == SessionState.BackendLogout:
        max(1'i64, self.lifecycle.logoutTimeLeftMs(nowMs()))
      else:
        TickMs.int64
    self.tickTimer.setInterval(interval.cint) # restarts a running timer
    if not self.tickTimer.isActive():
      self.tickTimer.start()

  proc deliverHeld(self: SessionHost) =
    if not self.hasReceivers:
      return
    for signal in self.signals.takeDeliverable(acceptedSignalEpoch()):
      self.receivers.signal(signal)
    for signal in self.keycardSignals.takeDeliverable(currentKeycardEpoch()):
      self.receivers.keycardSignal(signal)

  proc attachSession*(self: SessionHost, receivers: SessionReceivers) =
    ## The session that receives signals from now on. Signals held while no session
    ## received them are delivered first.
    self.receivers = receivers
    self.hasReceivers = true
    self.endedEpoch = NoEpoch
    self.endedKeycardEpoch = NoEpoch
    self.deliverHeld()

  proc detachSession*(self: SessionHost) =
    self.receivers = SessionReceivers()
    self.hasReceivers = false

  proc warnEvicted(gate: var SignalGate, kind: string) =
    let evicted = gate.takeEvictedCount()
    if evicted > 0:
      warn "held signals over capacity, dropped the oldest", kind, evicted

  proc receiveSignal*(self: SessionHost, signal: string) {.slot.} =
    let epoch = signalEpochOf(signal)
    if acceptedSignalEpoch() == NoEpoch and epoch != NoEpoch:
      # The epoch could not be read at process start. No earlier session exists in
      # this process, so the first stamped signal tells the current one.
      warn "adopting the backend signal epoch from the first signal", signalEpoch = epoch
      acceptSignalEpoch(epoch)
    case self.signals.route(epoch, acceptedSignalEpoch(), signal, self.hasReceivers,
        self.endedEpoch)
    of SignalRoute.Deliver:
      self.receivers.signal(signal)
    of SignalRoute.Hold:
      warnEvicted(self.signals, "backend")
    of SignalRoute.Drop:
      debug "dropping a signal of an ended backend session", epoch,
        acceptedEpoch = acceptedSignalEpoch(), signal = signal[0 ..< min(signal.len, 80)]

  proc receiveStampedKeycardSignal*(self: SessionHost, stamped: string) {.slot.} =
    let at = stamped.find(KeycardEpochSeparator)
    var epoch = NoEpoch
    if at > 0:
      try:
        epoch = parseBiggestUInt(stamped[0 ..< at]).uint64
      except ValueError:
        discard
    let signal = if at >= 0: stamped[at + 1 .. ^1] else: stamped
    case self.keycardSignals.route(epoch, currentKeycardEpoch(), signal, self.hasReceivers,
        self.endedKeycardEpoch)
    of SignalRoute.Deliver:
      self.receivers.keycardSignal(signal)
    of SignalRoute.Hold:
      warnEvicted(self.keycardSignals, "keycard")
    of SignalRoute.Drop:
      debug "dropping a keycard signal of an ended session", epoch

  # Lifecycle

  proc setOps*(self: SessionHost, ops: SessionOps,
      initializeSession: proc(): Result[SessionReceivers, string]) =
    ## The operations of the app sessions this host runs. The host adds detaching the
    ## ended session from the signals, the drain polling, the backend logout thread and
    ## attaching the session `initializeSession` builds.
    for name, op in ops.fieldPairs:
      if name notin ["startBackendLogout", "initialize"]:
        doAssert not op.isNil, "session operation not set: " & name
    var ops = ops
    let host = self
    let sessionReady = ops.sessionReady
    ops.sessionReady = proc(policy: AutoLoginPolicy) =
      host.autoLoginPolicy = policy
      sessionReady(policy)
    let stopActivity = ops.stopActivity
    ops.stopActivity = proc() =
      host.detachSession()
      host.endedEpoch = acceptedSignalEpoch()
      host.endedKeycardEpoch = currentKeycardEpoch()
      stopActivity()
    let dispose = ops.dispose
    ops.dispose = proc() =
      # The keycard library queues its events through the GUI event loop before they
      # reach the callback that stamps them. Its Stop (in stopActivity) returns only once
      # card detection has stopped, so every event of the ended session was queued by
      # then (an Android NFC intent included). The GUI thread delivers posted events of
      # the same priority in posting order, so they were delivered by now - ahead of the
      # backend logout response that led here, posted later - and dropped as the ended
      # session's. Advancing only now keeps them from being stamped with the next
      # session's epoch.
      advanceKeycardEpoch()
      dispose()
    if ops.startBackendLogout.isNil:
      # Set only by tests that stand in for the backend (and answer through
      # onBackendLogoutResponse themselves).
      ops.startBackendLogout = proc() =
        host.logoutThreadRunning = true
        createThread(host.logoutThread, backendLogoutThread,
          BackendLogoutThreadArg(host: cast[pointer](host.vptr)))
    ops.initialize = proc(): Result[void, string] =
      let receivers = ?initializeSession()
      host.attachSession(receivers)
      ok()
    self.lifecycle = newSessionLifecycle(ops, self.drainDeadlineMs, self.logoutDeadlineMs)

  proc onBackendLogoutResponse*(self: SessionHost, response: string) {.slot.} =
    if self.logoutThreadRunning:
      joinThread(self.logoutThread)
      self.logoutThreadRunning = false
    let loggedOut = status_general.parseLogoutResponse(response)
    # Accepted also when Logout failed after the backend had started the next epoch.
    if loggedOut.signalEpoch != NoEpoch:
      acceptSignalEpoch(loggedOut.signalEpoch)
    if self.lifecycle.isNil:
      return
    if loggedOut.error.len > 0:
      self.lifecycle.onBackendLogoutDone(Result[void, string].err(loggedOut.error))
    else:
      info "backend logged out", signalEpoch = loggedOut.signalEpoch
      self.lifecycle.onBackendLogoutDone(Result[void, string].ok())
    self.scheduleTick()

  proc autoLoginPolicy*(self: SessionHost): AutoLoginPolicy =
    ## The policy the current session started with: process start, logout or relogin.
    self.autoLoginPolicy

  proc state*(self: SessionHost): SessionState =
    if self.lifecycle.isNil: SessionState.Active else: self.lifecycle.state

  proc requestEnd*(self: SessionHost, policy: AutoLoginPolicy): bool =
    if self.lifecycle.isNil:
      error "no session operations set, cannot end the session"
      return false
    self.lifecycle.requestEnd(policy)

  proc requestQuit*(self: SessionHost): bool =
    not self.lifecycle.isNil and self.lifecycle.requestQuit()

  proc sessionUiReleased*(self: SessionHost) {.slot.} =
    if not self.lifecycle.isNil:
      self.lifecycle.onUiReleased(nowMs())
      self.scheduleTick()

  proc retry*(self: SessionHost) {.slot.} =
    if not self.lifecycle.isNil:
      self.lifecycle.retry(nowMs())
      self.scheduleTick()
