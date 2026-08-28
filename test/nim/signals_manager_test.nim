import json
import unittest

import app/core/eventemitter
import app/core/signals/signals_manager
import app/core/signals/signal_type_scan
import app/core/signals/remote_signals/signal_type
import app/core/signals/remote_signals/mediaserver
import app/core/signals/remote_signals/messages
import app/core/signals/remote_signals/storage_stats

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

  test "mediaserver.started decodes the port and dispatches a typed signal":
    # iOS restarts the media server on resume; the new port must survive the
    # decode so subscribers can rewrite cached media URLs (issue #47).
    let emitter = createEventEmitter()
    var receivedPort = 0
    emitter.on(SignalType.MediaServerStarted.event) do(a: Args):
      receivedPort = MediaServerStartedSignal(a).port

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"mediaserver.started","event":{"port":43210}}""")

    check receivedPort == 43210

  test "mediaserver.started with a null event dispatches with port 0":
    let emitter = createEventEmitter()
    var dispatched = false
    var receivedPort = -1
    emitter.on(SignalType.MediaServerStarted.event) do(a: Args):
      dispatched = true
      receivedPort = MediaServerStartedSignal(a).port

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"mediaserver.started","event":null}""")

    check dispatched
    check receivedPort == 0

  test "notification.reply.sent carries the full successful send response":
    let emitter = createEventEmitter()
    var response: JsonNode
    emitter.on(SignalType.NotificationReplySent.event) do(a: Args):
      response = NotificationReplySentSignal(a).response

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"notification.reply.sent","event":{"jsonrpc":"2.0","id":1,"result":{"chats":[{"id":"chat-id"}],"messages":[{"id":"message-id"}]}}}""")

    check response["result"]["chats"][0]["id"].getStr == "chat-id"
    check response["result"]["messages"][0]["id"].getStr == "message-id"

  test "a handled type in a whitespaced envelope still dispatches (scan-miss fallback)":
    # The fast substring scan assumes status-go's compact `"type":"` byte token.
    # If the marshaling format ever changes (e.g. a space after the colon), the
    # scan misses — that must degrade to the full-parse path, not drop the signal.
    let emitter = createEventEmitter()
    var dispatched = false
    emitter.on(SignalType.DiscoveryStarted.event) do(a: Args):
      dispatched = true

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type": "discovery.started", "event": {}}""")

    check dispatched
    check unhandledSignalCount() == 0

  test "storage-stats.progress carries a deterministic N of M":
    # The Storage stats section shows a real "N of M" rather than a spinner, so
    # both numbers have to survive the decode.
    let emitter = createEventEmitter()
    var step, total = -1
    var requestId = ""
    emitter.on(SignalType.StorageStatsProgress.event) do(a: Args):
      let signal = StorageStatsProgressSignal(a)
      requestId = signal.requestId
      step = signal.step
      total = signal.total

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"storage-stats.progress","event":{"requestId":"abc","step":7,"total":160}}""")

    check requestId == "abc"
    check step == 7
    check total == 160

  test "storage-stats.result carries the profile":
    # The profile is what the preview renders and what the user copies, so it
    # has to survive the decode intact.
    let emitter = createEventEmitter()
    var profileVersion = 0
    var messagesTotal = 0
    emitter.on(SignalType.StorageStatsResult.event) do(a: Args):
      let signal = StorageStatsResultSignal(a)
      profileVersion = signal.data{"profileVersion"}.getInt()
      messagesTotal = signal.data{"messaging"}{"messagesTotal"}.getInt()

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"storage-stats.result","event":{"requestId":"abc","data":{"profileVersion":1,"messaging":{"messagesTotal":100000}}}}""")

    check profileVersion == 1
    check messagesTotal == 100000

  test "a failed storage-stats.result reports the error and leaves data null":
    let emitter = createEventEmitter()
    var error = ""
    var dataIsNull = false
    emitter.on(SignalType.StorageStatsResult.event) do(a: Args):
      let signal = StorageStatsResultSignal(a)
      error = signal.error
      dataIsNull = signal.data.kind == JNull

    let manager = newSignalsManager(emitter)
    manager.processSignal("""{"type":"storage-stats.result","event":{"requestId":"abc","error":"no account is logged in"}}""")

    check error == "no account is logged in"
    check dataIsNull
