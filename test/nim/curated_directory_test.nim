import json, unittest

import app_service/service/community/curated_directory

type FakeBackend = ref object
  reads, refreshes, stops: int
  refreshFails: bool
  runIds: bool
  runId: int
  beforeReply: proc()
  busy: seq[bool]
  loaded: int
  errors: seq[CuratedRefreshError]
  log: seq[string]

proc newDirectory(fake: FakeBackend): CuratedDirectory =
  newCuratedDirectory(CuratedDirectoryBackend(
    read: proc() = (inc fake.reads),
    refresh: proc(): CuratedRefreshReply =
      inc fake.refreshes
      if not fake.beforeReply.isNil:
        fake.beforeReply()
      CuratedRefreshReply(
        asked: not fake.refreshFails,
        runId: if fake.runIds: fake.runId else: CuratedRunUnknown),
    stop: proc() = (inc fake.stops),
    busyChanged: proc(busy: bool) =
      fake.busy.add(busy)
      fake.log.add("busy " & $busy),
    loaded: proc(): int = fake.loaded,
    errorChanged: proc(error: CuratedRefreshError) =
      fake.errors.add(error)
      fake.log.add("error " & $error)))

proc answerWith(fake: FakeBackend, runId: int) =
  fake.runIds = true
  fake.runId = runId

suite "curated directory while the portal is open":
  setup:
    let backend = FakeBackend()
    let directory = newDirectory(backend)

  test "entering the portal reads the directory once and asks for a refresh":
    directory.enter()

    check backend.reads == 1
    check backend.refreshes == 1
    check backend.stops == 0

  test "an open with everything stored costs one read":
    directory.enter()
    directory.refreshStarted()
    directory.readDone(entries = 6)
    directory.refreshFinished()
    directory.leave()
    check backend.reads == 1

    directory.enter()
    directory.readDone(entries = 6)
    directory.refreshStarted()
    directory.refreshFinished()

    check backend.reads == 2
    check backend.refreshes == 2
    check backend.stops == 1

  test "a first open reads the empty directory, then the listed one, and nothing else":
    directory.enter()
    directory.readDone(entries = 0)
    check backend.reads == 1

    directory.refreshStarted()
    check backend.reads == 2

    directory.readDone(entries = 10)
    directory.refreshFinished()
    check backend.reads == 2

  test "a refresh starting during the entry read of an empty directory is followed by one read":
    directory.enter()
    directory.refreshStarted()
    check backend.reads == 1

    directory.readDone(entries = 0)
    check backend.reads == 2

    directory.readDone(entries = 10)
    check backend.reads == 2

  test "a refresh starting during the entry read of a stored directory causes no read":
    directory.enter()
    directory.refreshStarted()
    directory.readDone(entries = 10)

    check backend.reads == 1

  test "a directory that stays empty is not read again":
    directory.enter()
    directory.readDone(entries = 0)
    directory.refreshStarted()
    directory.readDone(entries = 0)
    directory.refreshFinished()

    check backend.reads == 2

  test "a refresh that finishes causes no read":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished()

    check backend.reads == 1

  test "a refresh that changed the list of a stored directory is followed by one read":
    directory.enter()
    directory.readDone(entries = 10)

    directory.refreshStarted(changed = true)
    check backend.reads == 2

    directory.readDone(entries = 11)
    directory.refreshFinished()
    check backend.reads == 2

  test "a refresh that left the list of a stored directory as it was causes no read":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted(changed = false)
    directory.refreshFinished()

    check backend.reads == 1

  test "a refresh that changed the list during the entry read is followed by one read":
    directory.enter()
    directory.refreshStarted(changed = true)
    check backend.reads == 1

    directory.readDone(entries = 10)
    check backend.reads == 2

    directory.readDone(entries = 11)
    check backend.reads == 2

  test "a changed list is not read after leaving the portal":
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    directory.refreshStarted(changed = true)

    check backend.reads == 1

  test "nothing is read after leaving the portal":
    directory.enter()
    directory.readDone(entries = 0)
    directory.leave()
    check backend.stops == 1

    directory.refreshStarted()
    directory.refreshFinished()

    check backend.reads == 1

  test "nothing is read after leaving during the entry read of an empty directory":
    directory.enter()
    directory.refreshStarted()
    directory.leave()
    directory.readDone(entries = 0)
    directory.refreshStarted()

    check backend.reads == 1

  test "entering again during a read left behind reads once more":
    directory.enter()
    directory.leave()
    directory.enter()
    check backend.reads == 1

    directory.readDone(entries = 10)
    check backend.reads == 2

    directory.readDone(entries = 10)
    check backend.reads == 2

suite "curated directory loading state":
  setup:
    let backend = FakeBackend()
    let directory = newDirectory(backend)

  test "it is loading only during the entry read when the refresh could not be asked for":
    backend.refreshFails = true
    directory.enter()
    check backend.busy == @[true]

    directory.readDone(entries = 10)
    check backend.busy == @[true, false]

  test "it is loading from the refresh call, before the refresh reports its start":
    directory.enter()
    directory.readDone(entries = 0)
    check backend.busy == @[true]

    directory.refreshStarted()
    directory.readDone(entries = 10)
    check backend.busy == @[true]

    directory.refreshFinished()
    check backend.busy == @[true, false]

  test "it stays loading until a read still in flight ends":
    directory.enter()
    directory.refreshStarted()
    directory.refreshFinished()
    check backend.busy == @[true]

    directory.readDone(entries = 10)
    check backend.busy == @[true, false]

  test "leaving the portal ends the loading without waiting for the refresh":
    directory.enter()
    directory.refreshStarted()
    directory.readDone(entries = 10)
    directory.leave()
    check backend.busy == @[true, false]

    directory.refreshFinished()
    check backend.busy == @[true, false]

  test "a refresh reported after leaving is not shown as loading":
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    directory.refreshStarted()

    check backend.busy == @[true, false]

  test "a run stopped by leaving ends without ending the loading of the run started on entering again":
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshFinished(cancelled = true)
    check backend.busy == @[true, false, true]

    directory.refreshStarted()
    directory.refreshFinished()
    check backend.busy == @[true, false, true, false]

  test "a read that could not start does not leave it loading":
    var failing: CuratedDirectory
    failing = newCuratedDirectory(CuratedDirectoryBackend(
      read: proc() = failing.readDone(),
      refresh: proc(): CuratedRefreshReply = CuratedRefreshReply(asked: true, runId: CuratedRunUnknown),
      stop: proc() = discard,
      busyChanged: proc(busy: bool) = backend.busy.add(busy)))

    failing.enter()
    failing.refreshStarted()
    failing.refreshFinished()

    check backend.busy == @[true, false]

suite "curated directory while the app is in the background":
  setup:
    let backend = FakeBackend()
    let directory = newDirectory(backend)

  test "going to the background with the portal open stops the refresh":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()

    directory.suspend()

    check backend.stops == 1
    check backend.busy == @[true, false]

  test "returning after the background interrupted a refresh reads once and asks for a refresh":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.suspend()

    directory.resume()

    check backend.reads == 2
    check backend.refreshes == 2
    check backend.busy == @[true, false, true]

  test "a refresh reported in the background causes no read and is not shown as loading":
    directory.enter()
    directory.readDone(entries = 0)
    directory.suspend()

    directory.refreshStarted(changed = true)

    check backend.reads == 1
    check backend.busy == @[true, false]

  test "a read still in flight when going to the background is not followed by another":
    directory.enter()
    directory.refreshStarted(changed = true)
    directory.suspend()

    directory.readDone(entries = 0)

    check backend.reads == 1

  test "nothing happens in the background or on return while the portal is closed":
    directory.suspend()
    directory.resume()
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    directory.suspend()
    directory.resume()

    check backend.reads == 1
    check backend.refreshes == 1
    check backend.stops == 1

  test "returning without having been in the background does nothing":
    directory.enter()
    directory.readDone(entries = 10)

    directory.resume()

    check backend.reads == 1
    check backend.refreshes == 1

  test "going to the background twice stops the refresh once":
    directory.enter()
    directory.suspend()
    directory.suspend()

    check backend.stops == 1

  test "a portal left in the background is not refreshed on return":
    directory.enter()
    directory.readDone(entries = 10)
    directory.suspend()
    directory.leave()

    directory.resume()

    check backend.reads == 1
    check backend.refreshes == 1

  test "a portal entered in the background is refreshed on return":
    directory.suspend()
    directory.enter()
    check backend.reads == 0
    check backend.refreshes == 0

    directory.resume()

    check backend.reads == 1
    check backend.refreshes == 1

  test "returning after a refresh that had finished does not start another":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished()
    directory.suspend()

    directory.resume()

    check backend.reads == 1
    check backend.refreshes == 1
    check backend.busy == @[true, false]

  test "returning after a refresh that could not be asked for does not ask again":
    backend.refreshFails = true
    directory.enter()
    directory.readDone(entries = 10)
    directory.suspend()

    directory.resume()

    check backend.reads == 1
    check backend.refreshes == 1

  test "a refresh interrupted by the background is restarted once":
    directory.enter()
    directory.readDone(entries = 10)
    directory.suspend()
    directory.resume()
    directory.refreshStarted()
    directory.refreshFinished()
    directory.suspend()

    directory.resume()

    check backend.refreshes == 2

suite "curated directory refresh error":
  setup:
    let backend = FakeBackend()
    let directory = newDirectory(backend)

  test "a refresh that ends without a failure is no error":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished()

    check backend.errors.len == 0

  test "entries that failed next to entries with data are a partial error":
    backend.loaded = 6
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()

    directory.refreshFinished(failed = 2)

    check backend.errors == @[CuratedRefreshError.Partial]

  test "entries that failed while no entry has data are a full error":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()

    directory.refreshFinished(failed = 4)

    check backend.errors == @[CuratedRefreshError.Full]

  test "a directory that failed with a stored list is a partial error":
    backend.loaded = 6
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted(directoryFailed = true)

    directory.refreshFinished()

    check backend.errors == @[CuratedRefreshError.Partial]

  test "a directory that failed with a stored list without data and no failed entry is a partial error":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted(directoryFailed = true)

    directory.refreshFinished()

    check backend.errors == @[CuratedRefreshError.Partial]

  test "a directory that failed with nothing stored is a full error":
    directory.enter()
    directory.readDone(entries = 0)
    directory.refreshStarted(directoryFailed = true)
    directory.readDone(entries = 0)

    directory.refreshFinished()

    check backend.errors == @[CuratedRefreshError.Full]

  test "an outcome reported during a read is judged when the read ends":
    backend.loaded = 6
    directory.enter()
    directory.refreshStarted(directoryFailed = true)
    directory.refreshFinished()
    check backend.errors.len == 0

    directory.readDone(entries = 10)

    check backend.errors == @[CuratedRefreshError.Partial]

  test "a cancelled refresh leaves the error as it was":
    backend.loaded = 6
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished(failed = 2)
    directory.leave()
    directory.enter()
    directory.readDone(entries = 10)

    directory.refreshFinished(failed = 0, cancelled = true)

    check backend.errors == @[CuratedRefreshError.Partial, CuratedRefreshError.None]

  test "the error is cleared when the next refresh is asked for":
    backend.loaded = 6
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished(failed = 2)

    directory.retry()

    check backend.errors == @[CuratedRefreshError.Partial, CuratedRefreshError.None]

  test "the error is cleared when a refresh reports its start":
    backend.loaded = 6
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished(failed = 2)

    directory.refreshStarted()

    check backend.errors == @[CuratedRefreshError.Partial, CuratedRefreshError.None]

  test "a refresh that could not be asked for with nothing stored is a full error":
    backend.refreshFails = true
    directory.enter()

    directory.readDone(entries = 0)

    check backend.errors == @[CuratedRefreshError.Full]

  test "a refresh that could not be asked for with a stored list is a partial error and ends the loading":
    backend.loaded = 6
    backend.refreshFails = true
    directory.enter()
    check backend.busy == @[true]
    check backend.errors.len == 0

    directory.readDone(entries = 10)

    check backend.errors == @[CuratedRefreshError.Partial]
    check backend.busy == @[true, false]

  test "a refresh asked for by the user that could not be asked for keeps the error and ends the loading":
    backend.refreshFails = true
    directory.enter()
    directory.readDone(entries = 0)
    directory.retry()
    check backend.busy == @[true, false, true]

    directory.readDone(entries = 0)

    check backend.errors == @[CuratedRefreshError.Full]
    check backend.busy == @[true, false, true, false]

  test "a refresh that ends after leaving the portal is not judged":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.leave()

    directory.refreshFinished(failed = 4)

    check backend.errors.len == 0

  test "an outcome reported during a read is not judged when the portal is left before the read ends":
    backend.loaded = 6
    directory.enter()
    directory.refreshStarted(directoryFailed = true)
    directory.refreshFinished()
    directory.leave()

    directory.readDone(entries = 10)

    check backend.errors.len == 0

  test "the same error is reported once":
    backend.refreshFails = true
    directory.enter()
    directory.readDone(entries = 0)
    directory.retry()

    directory.readDone(entries = 0)

    check backend.errors == @[CuratedRefreshError.Full]

suite "curated directory refresh asked for by the user":
  setup:
    let backend = FakeBackend()
    let directory = newDirectory(backend)

  test "it reads once and asks for a refresh like entering the portal":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted()
    directory.refreshFinished(failed = 2)

    directory.retry()

    check backend.reads == 2
    check backend.refreshes == 2
    check backend.busy == @[true, false, true]

  test "the error of a failed refresh is cleared only once it is loading again":
    directory.enter()
    directory.readDone(entries = 0)
    directory.refreshStarted(directoryFailed = true)
    directory.readDone(entries = 0)
    directory.refreshFinished()
    check backend.errors == @[CuratedRefreshError.Full]
    backend.log = @[]

    directory.retry()

    check backend.log == @["busy true", "error None"]

  test "the error of a failed run is cleared only once it is loading again":
    backend.loaded = 5
    backend.answerWith(1)
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted(runId = 1)
    directory.refreshFinished(failed = 2, runId = 1)
    check backend.errors == @[CuratedRefreshError.Partial]
    backend.log = @[]
    backend.answerWith(2)

    directory.retry()
    directory.readDone(entries = 10)
    directory.refreshStarted(runId = 2)

    check backend.log == @["busy true", "error None"]

  test "it is ignored while a refresh is running":
    directory.enter()
    directory.readDone(entries = 10)

    directory.retry()
    directory.refreshStarted()
    directory.retry()

    check backend.reads == 1
    check backend.refreshes == 1

  test "it is ignored while the portal is closed":
    directory.retry()
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshFinished()
    directory.leave()

    directory.retry()

    check backend.reads == 1
    check backend.refreshes == 1

  test "it is ignored while the app is in the background":
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshFinished()
    directory.suspend()

    directory.retry()

    check backend.reads == 1
    check backend.refreshes == 1

suite "curated directory refresh runs":
  setup:
    let backend = FakeBackend(loaded: 6)
    let directory = newDirectory(backend)

  test "the late finished of a stopped run is not the outcome of the run asked for next":
    backend.answerWith(1)
    directory.enter()
    directory.refreshStarted(runId = 1)
    directory.readDone(entries = 10)
    directory.leave()
    backend.answerWith(2)
    directory.enter()
    directory.readDone(entries = 10)

    directory.refreshFinished(failed = 3, runId = 1)
    check backend.busy == @[true, false, true]
    check backend.errors.len == 0

    directory.refreshStarted(runId = 2)
    directory.refreshFinished(runId = 2)
    check backend.busy == @[true, false, true, false]
    check backend.errors.len == 0

  test "the late started and finished of a stopped run are not those of the run asked for next":
    backend.answerWith(1)
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    backend.answerWith(2)
    directory.enter()
    directory.readDone(entries = 10)

    directory.refreshStarted(changed = true, directoryFailed = true, runId = 1)
    directory.refreshFinished(failed = 2, runId = 1)
    check backend.reads == 2
    check backend.busy == @[true, false, true]
    check backend.errors.len == 0

    directory.refreshStarted(runId = 2)
    directory.refreshFinished(runId = 2)
    check backend.busy == @[true, false, true, false]
    check backend.errors.len == 0

  test "a run joined on entering again ends the loading with its finished":
    backend.answerWith(1)
    directory.enter()
    directory.refreshStarted(runId = 1)
    directory.readDone(entries = 10)
    directory.leave()
    directory.enter()
    directory.readDone(entries = 10)
    check backend.busy == @[true, false, true]

    directory.refreshFinished(failed = 1, runId = 1)

    check backend.busy == @[true, false, true, false]
    check backend.errors == @[CuratedRefreshError.Partial]

  test "a refresh call that started nothing is not loading and no error":
    backend.answerWith(0)
    directory.enter()
    check backend.refreshes == 1

    directory.readDone(entries = 10)

    check backend.busy == @[true, false]
    check backend.errors.len == 0

  test "a refresh call that started nothing keeps the error of the last run":
    backend.answerWith(1)
    directory.enter()
    directory.readDone(entries = 10)
    directory.refreshStarted(runId = 1)
    directory.refreshFinished(failed = 1, runId = 1)
    backend.answerWith(0)

    directory.retry()
    directory.readDone(entries = 10)

    check backend.errors == @[CuratedRefreshError.Partial]
    check backend.busy == @[true, false, true, false]

  test "signals of any run are ignored after a refresh call that started nothing":
    backend.answerWith(0)
    directory.enter()
    directory.readDone(entries = 10)

    directory.refreshStarted(directoryFailed = true, runId = 4)
    directory.refreshFinished(failed = 1, runId = 4)

    check backend.busy == @[true, false]
    check backend.errors.len == 0

  test "signals without a run id are taken as those of the run asked for":
    backend.answerWith(1)
    directory.enter()
    directory.readDone(entries = 10)

    directory.refreshStarted()
    directory.refreshFinished(failed = 1)

    check backend.busy == @[true, false]
    check backend.errors == @[CuratedRefreshError.Partial]

  test "the started of a stopped run is ignored when the next refresh could not be asked for":
    backend.answerWith(1)
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    backend.refreshFails = true
    directory.enter()
    directory.readDone(entries = 10)
    check backend.errors == @[CuratedRefreshError.Partial]

    directory.refreshStarted(runId = 1)

    check backend.busy == @[true, false, true, false]
    check backend.errors == @[CuratedRefreshError.Partial]

  test "a run that started and finished before the reply of its refresh call ends the loading":
    backend.answerWith(1)
    backend.beforeReply = proc() =
      directory.refreshStarted(runId = 1)
      directory.refreshFinished(failed = 1, runId = 1)

    directory.enter()
    directory.readDone(entries = 10)

    check backend.busy == @[true, false]
    check backend.errors == @[CuratedRefreshError.Partial]

  test "a run that started and finished before the reply of the refresh call after a stop ends the loading":
    backend.answerWith(1)
    directory.enter()
    directory.refreshStarted(runId = 1)
    directory.readDone(entries = 10)
    directory.leave()
    backend.answerWith(2)
    backend.beforeReply = proc() =
      directory.refreshStarted(runId = 2)
      directory.refreshFinished(runId = 2)

    directory.enter()
    directory.readDone(entries = 10)

    check backend.busy == @[true, false, true, false]
    check backend.errors.len == 0

  test "a run that started before the reply of its refresh call keeps what its start reported":
    backend.answerWith(1)
    backend.beforeReply = proc() =
      directory.refreshStarted(directoryFailed = true, runId = 1)

    directory.enter()
    directory.readDone(entries = 10)
    check backend.busy == @[true]

    directory.refreshFinished(runId = 1)

    check backend.busy == @[true, false]
    check backend.errors == @[CuratedRefreshError.Partial]

  test "signals of a stopped run that arrive before the reply of the next refresh call are ignored":
    backend.answerWith(1)
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    backend.answerWith(2)
    backend.beforeReply = proc() =
      directory.refreshStarted(changed = true, directoryFailed = true, runId = 1)
      directory.refreshFinished(failed = 2, runId = 1)

    directory.enter()
    directory.readDone(entries = 10)

    check backend.reads == 2
    check backend.busy == @[true, false, true]
    check backend.errors.len == 0

    directory.refreshStarted(runId = 2)
    directory.refreshFinished(runId = 2)
    check backend.busy == @[true, false, true, false]
    check backend.errors.len == 0

  test "signals of a stopped run are ignored when its refresh call gave no run":
    backend.refreshFails = true
    backend.beforeReply = proc() =
      directory.refreshStarted(runId = 1)
    directory.enter()
    directory.readDone(entries = 10)
    directory.leave()
    backend.refreshFails = false
    backend.answerWith(2)
    backend.beforeReply = proc() =
      directory.refreshStarted(changed = true, directoryFailed = true, runId = 1)

    directory.enter()
    directory.readDone(entries = 10)
    check backend.reads == 2

    directory.refreshFinished(runId = 2)
    check backend.errors == @[CuratedRefreshError.Partial, CuratedRefreshError.None]

suite "curated refresh call reply":
  test "a number is the id of the run":
    let reply = toCuratedRefreshReply(%3)
    check reply.asked
    check reply.runId == 3

  test "zero is no run":
    let reply = toCuratedRefreshReply(%0)
    check reply.asked
    check reply.runId == 0

  test "a reply without a number has no run id":
    check toCuratedRefreshReply(newJNull()).runId == CuratedRunUnknown
    check toCuratedRefreshReply(nil).runId == CuratedRunUnknown
    check toCuratedRefreshReply(newJNull()).asked
