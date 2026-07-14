import unittest

import app/core/eventemitter
import app/core/signals/signals_manager
import app/core/signals/signal_type_scan
import app/core/signals/remote_signals/signal_type

# Exercises the real ManageSignals dispatch path (`processSignal`) to prove that
# the cheap-triage guard skips unhandled types before parsing
# while leaving known-type decode/dispatch intact.

suite "SignalsManager - unhandled signal-type skipping":

  setup:
    resetUnhandledSignalCount()

  test "a known signal type is decoded and dispatched":
    let emitter = createEventEmitter()
    var dispatched = false
    # discovery.started is a known SignalType handled via the generic branch, so
    # it dispatches without needing any specific event fields.
    emitter.on(SignalType.DiscoveryStarted.event) do(a: Args):
      dispatched = true

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"discovery.started","event":{}}""")

    check dispatched
    check unhandledSignalCount() == 0

  test "an unknown type with a malformed body is skipped without raising and counted":
    let emitter = createEventEmitter()
    var dispatched = false
    emitter.on(SignalType.DiscoveryStarted.event) do(a: Args):
      dispatched = true

    let manager = newSignalsManager(emitter)
    # Deliberately malformed event body: the guard must drop it on the type
    # alone, before any parse (a full parse would raise).
    let raw = """{"type":"local-notifications","event":{ not valid json ,,, }}"""
    manager.processSignal(raw)

    check unhandledSignalCount() == 1
    check not dispatched

  test "a known type keeps dispatching after an unknown one was skipped":
    let emitter = createEventEmitter()
    var dispatchedCount = 0
    emitter.on(SignalType.DiscoveryStarted.event) do(a: Args):
      inc dispatchedCount

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"local-notifications","event":{}}""")
    manager.processSignal("""{"type":"discovery.started","event":{}}""")

    check dispatchedCount == 1
    check unhandledSignalCount() == 1
