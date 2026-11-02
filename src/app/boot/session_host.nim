## Process-lifetime host of the app sessions (one per login) — see session_lifecycle.
##
## - Permanent receiver of the status-go and keycard callbacks: the raw pointer the C
##   callbacks invoke never dangles across sessions. It forwards only the signals of
##   the current backend session (signal_epoch) to the current app session.
## - Drives `SessionLifecycle`: detaches the ended session from the signals, polls the
##   drain without blocking the GUI, runs the backend logout on its own thread and
##   attaches the next session.

import std/[atomics, monotimes, times, strutils]
import nimqml, chronicles, results
from seaqt/qtimer import QTimer, create, setInterval, onTimeout, start, stop

import app/core/signal_epoch
import app/core/signal_handler
import statusq_bridge
import app/boot/session_lifecycle
import backend/general as status_general
import status_go

export session_lifecycle

logScope:
  topics = "session-host"

const
  HeldSignalsCapacity = 2000
  DrainPollMs = 50
  DrainDeadlineMs* = 15_000'i64
  KeycardEpochSeparator = '|'

# Keycard signals come from status-keycard-qt in this process, synchronously with their
# producer, so the C callback stamps them with this epoch on arrival. It advances
# after the ended session's keycard operations are stopped.
var keycardEpoch: Atomic[uint64]
keycardEpoch.store(1)

proc deliverKeycardSignal*(host: pointer, signal: cstring) =
  ## Called from the keycard C callback thread: queues "<epoch>|<signal>" to the host.
  statusq_invoke_method_queued_tagged(host, "receiveStampedKeycardSignal", signal,
    keycardEpoch.load())

proc advanceKeycardEpoch*() =
  discard keycardEpoch.fetchAdd(1)

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
    drainTimer: QTimer
    logoutThread: Thread[BackendLogoutThreadArg]
    logoutThreadRunning: bool
    # Backend epoch of the session whose activity was stopped, until the next session
    # is attached: its signals are dropped, not held.
    endedEpoch: uint64

  proc delete*(self: SessionHost)
  proc setup(self: SessionHost)
  proc deliverHeld(self: SessionHost)

  proc newSessionHost*(): SessionHost =
    new(result, delete)
    result.setup()

  proc setup(self: SessionHost) =
    self.QObject.setup
    self.signals = initSignalGate(HeldSignalsCapacity)
    self.keycardSignals = initSignalGate(HeldSignalsCapacity)
    let host = self
    onSignalEpochAccepted(proc() = host.deliverHeld())
    self.drainTimer = QTimer.create()
    self.drainTimer.setInterval(DrainPollMs)
    self.drainTimer.onTimeout(proc() {.closure, raises: [].} =
      try:
        host.lifecycle.onDrainTick(nowMs())
        if host.lifecycle.state notin {SessionState.Draining, SessionState.DrainTimeout}:
          host.drainTimer.stop()
      except Exception as e:
        error "drain tick failed", error = e.msg
    )

  proc delete*(self: SessionHost) =
    # Graceful exit only; a hard exit never runs this, so it never waits for the node.
    if self.logoutThreadRunning:
      joinThread(self.logoutThread)
    if not self.drainTimer.h.isNil:
      self.drainTimer.stop()
    onSignalEpochAccepted(nil)
    self.QObject.delete

  proc readBackendSignalEpoch*(self: SessionHost): Result[void, string] =
    ## At process start: accept the signals of the backend session running now.
    let epoch = ?status_general.readSignalEpoch()
    info "accepting backend signals", signalEpoch = epoch
    acceptSignalEpoch(epoch)
    ok()

  proc deliverHeld(self: SessionHost) =
    if not self.hasReceivers:
      return
    for signal in self.signals.takeDeliverable(acceptedSignalEpoch()):
      self.receivers.signal(signal)
    for signal in self.keycardSignals.takeDeliverable(keycardEpoch.load()):
      self.receivers.keycardSignal(signal)

  proc attachSession*(self: SessionHost, receivers: SessionReceivers) =
    ## The session that receives signals from now on. Signals held while no session
    ## received them are delivered first.
    self.receivers = receivers
    self.hasReceivers = true
    self.endedEpoch = NoEpoch
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
    case self.keycardSignals.route(epoch, keycardEpoch.load(), signal, self.hasReceivers)
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
    var ops = ops
    let host = self
    let stopActivity = ops.stopActivity
    ops.stopActivity = proc() =
      host.detachSession()
      host.endedEpoch = acceptedSignalEpoch()
      stopActivity()
      host.drainTimer.start()
    ops.startBackendLogout = proc() =
      host.logoutThreadRunning = true
      createThread(host.logoutThread, backendLogoutThread,
        BackendLogoutThreadArg(host: cast[pointer](host.vptr)))
    ops.initialize = proc(): Result[void, string] =
      let receivers = ?initializeSession()
      host.attachSession(receivers)
      ok()
    self.lifecycle = newSessionLifecycle(ops, DrainDeadlineMs)

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

  proc retry*(self: SessionHost) {.slot.} =
    if not self.lifecycle.isNil:
      self.lifecycle.retry()
