import options, unittest

import app/core/eventemitter
import app/core/signals/signals_manager
import app/core/signals/remote_signals/signal_type
import app/core/signals/remote_signals/community

suite "curated communities refresh signals":
  setup:
    let emitter = createEventEmitter()
    let manager = newSignalsManager(emitter)

  test "started carries whether the directory list changed":
    var started: seq[CuratedCommunitiesRefreshStartedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshStarted.event) do(a: Args):
      started.add(CuratedCommunitiesRefreshStartedSignal(a))

    manager.processSignal("""{"type":"curated.communities.refresh.started","event":{"changed":true}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.started","event":{"changed":false}}""")

    check started.len == 2
    check started[0].changed
    check not started[1].changed

  test "started without a payload is read as an unchanged list":
    var started: seq[CuratedCommunitiesRefreshStartedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshStarted.event) do(a: Args):
      started.add(CuratedCommunitiesRefreshStartedSignal(a))

    manager.processSignal("""{"type":"curated.communities.refresh.started","event":null}""")
    manager.processSignal("""{"type":"curated.communities.refresh.started","event":{}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.started"}""")

    check started.len == 3
    check not started[0].changed
    check not started[1].changed
    check not started[2].changed

  test "started carries whether the directory could be read":
    var started: seq[CuratedCommunitiesRefreshStartedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshStarted.event) do(a: Args):
      started.add(CuratedCommunitiesRefreshStartedSignal(a))

    manager.processSignal(
      """{"type":"curated.communities.refresh.started","event":{"changed":false,"directoryFailed":true}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.started","event":{"changed":true}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.started"}""")

    check started.len == 3
    check started[0].directoryFailed
    check not started[1].directoryFailed
    check not started[2].directoryFailed

  test "finished carries the outcome":
    var finished: seq[CuratedCommunitiesRefreshFinishedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshFinished.event) do(a: Args):
      finished.add(CuratedCommunitiesRefreshFinishedSignal(a))

    manager.processSignal(
      """{"type":"curated.communities.refresh.finished","event":{"resolved":6,"notFound":3,"failed":1,"cancelled":true}}""")

    check finished.len == 1
    check finished[0].resolved == 6
    check finished[0].notFound == 3
    check finished[0].failed == 1
    check finished[0].cancelled

  test "finished without a payload is read as nothing failed and not cancelled":
    var finished: seq[CuratedCommunitiesRefreshFinishedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshFinished.event) do(a: Args):
      finished.add(CuratedCommunitiesRefreshFinishedSignal(a))

    manager.processSignal("""{"type":"curated.communities.refresh.finished","event":null}""")
    manager.processSignal("""{"type":"curated.communities.refresh.finished","event":{}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.finished"}""")

    check finished.len == 3
    for signal in finished:
      check signal.resolved == 0
      check signal.notFound == 0
      check signal.failed == 0
      check not signal.cancelled

  test "started and finished carry the id of their run":
    var started: seq[CuratedCommunitiesRefreshStartedSignal]
    var finished: seq[CuratedCommunitiesRefreshFinishedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshStarted.event) do(a: Args):
      started.add(CuratedCommunitiesRefreshStartedSignal(a))
    emitter.on(SignalType.CuratedCommunitiesRefreshFinished.event) do(a: Args):
      finished.add(CuratedCommunitiesRefreshFinishedSignal(a))

    manager.processSignal(
      """{"type":"curated.communities.refresh.started","event":{"runId":7,"changed":true,"directoryFailed":false}}""")
    manager.processSignal(
      """{"type":"curated.communities.refresh.finished","event":{"runId":8,"resolved":6,"notFound":4,"failed":3,"cancelled":true}}""")

    check started.len == 1
    check started[0].runId == some(7)
    check finished.len == 1
    check finished[0].runId == some(8)

  test "started and finished without a run id have none":
    var started: seq[CuratedCommunitiesRefreshStartedSignal]
    var finished: seq[CuratedCommunitiesRefreshFinishedSignal]
    emitter.on(SignalType.CuratedCommunitiesRefreshStarted.event) do(a: Args):
      started.add(CuratedCommunitiesRefreshStartedSignal(a))
    emitter.on(SignalType.CuratedCommunitiesRefreshFinished.event) do(a: Args):
      finished.add(CuratedCommunitiesRefreshFinishedSignal(a))

    manager.processSignal("""{"type":"curated.communities.refresh.started","event":{"changed":true}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.started"}""")
    manager.processSignal("""{"type":"curated.communities.refresh.finished","event":{"failed":1}}""")
    manager.processSignal("""{"type":"curated.communities.refresh.finished","event":null}""")

    check started.len == 2
    check started[0].runId.isNone
    check started[1].runId.isNone
    check finished.len == 2
    check finished[0].runId.isNone
    check finished[1].runId.isNone

  test "the removed per community signal is not a known signal":
    var received = 0
    emitter.on("curated.communities.refresh.resolved") do(a: Args):
      inc received

    manager.processSignal(
      """{"type":"curated.communities.refresh.resolved","event":{"communityID":"0x02aa","stored":true}}""")

    check received == 0
