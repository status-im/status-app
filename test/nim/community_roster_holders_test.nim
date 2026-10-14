import std/unittest

import app/modules/shared_models/community_roster_holders

type FakeTimer = ref object
  running: bool
  startedWith: int

proc fake(timer: FakeTimer): RosterTimer =
  RosterTimer(
    start: proc(ms: int) =
      timer.running = true
      timer.startedWith = ms,
    stop: proc() =
      timer.running = false,
  )

proc fire(timer: FakeTimer, holders: RosterHolders) =
  doAssert timer.running
  timer.running = false
  holders.onReleaseTimeout()

proc fireRetry(timer: FakeTimer, holders: RosterHolders) =
  doAssert timer.running
  timer.running = false
  holders.onRetryTimeout()

suite "roster holders":
  setup:
    let timer = FakeTimer()
    let retryTimer = FakeTimer()
    var loads = 0
    var drops = 0
    let holders = newRosterHolders(timer.fake(), retryTimer.fake(),
      onLoad = (proc() = inc loads),
      onDrop = (proc() = inc drops))

  test "the first holder loads, later ones do not":
    holders.acquire()
    holders.acquire()
    check loads == 1
    check holders.holderCount == 2
    check holders.isActive

  test "the roster is dropped about two minutes after the last holder goes":
    holders.acquire()
    holders.acquire()
    holders.release()
    check not timer.running
    holders.release()
    check timer.running
    check timer.startedWith == RosterIdleReleaseMs
    check RosterIdleReleaseMs == 120_000
    check drops == 0
    timer.fire(holders)
    check drops == 1
    check not holders.isActive

  test "a holder arriving before the timeout keeps the roster":
    holders.acquire()
    holders.release()
    check timer.running
    holders.acquire()
    check not timer.running
    check loads == 1
    check drops == 0

  test "a stale timeout with holders back drops nothing":
    holders.acquire()
    holders.release()
    holders.acquire()
    holders.onReleaseTimeout()
    check drops == 0
    check holders.isActive

  test "the next holder after a drop reloads":
    holders.acquire()
    holders.release()
    timer.fire(holders)
    holders.acquire()
    check loads == 2

  test "backgrounding drops at once, foregrounding reloads for live holders":
    holders.acquire()
    holders.onBackgrounded()
    check drops == 1
    check not holders.isActive
    holders.onForegrounded()
    check loads == 2
    check holders.isActive

  test "backgrounding while idle drops and cancels the timer":
    holders.acquire()
    holders.release()
    check timer.running
    holders.onBackgrounded()
    check drops == 1
    check not timer.running
    holders.onForegrounded()
    check loads == 1

  test "backgrounding without a roster does nothing":
    holders.onBackgrounded()
    holders.onForegrounded()
    check drops == 0
    check loads == 0

  test "release never goes below zero":
    holders.release()
    check holders.holderCount == 0
    check not timer.running

  test "a failed load is retried with backoff while holders remain":
    holders.acquire()
    var delays: seq[int]
    for attempt in 1 .. 5:
      holders.onLoadFailed()
      check not holders.isActive
      check retryTimer.running
      delays.add retryTimer.startedWith
      retryTimer.fireRetry(holders)
      check loads == attempt + 1
      check holders.isActive
    check delays == @[2_000, 5_000, 15_000, 60_000, 60_000]
    # a success starts the backoff over
    holders.onLoadSucceeded()
    holders.onLoadFailed()
    check retryTimer.startedWith == 2_000

  test "a failure then a success leaves the roster loaded":
    holders.acquire()
    holders.onLoadFailed()
    retryTimer.fireRetry(holders)
    holders.onLoadSucceeded()
    check loads == 2
    check holders.isActive
    check not retryTimer.running

  test "a release during the backoff after a failed first load stops retrying":
    holders.acquire()
    holders.onLoadFailed()
    check retryTimer.running
    holders.release()
    check not retryTimer.running
    holders.onRetryTimeout()
    check loads == 1
    check not timer.running
    # nothing was filled; the drop only ends the capture of the failed load
    check drops == 1
    check not holders.isActive
    # the next first holder loads at once
    holders.acquire()
    check loads == 2

  test "a release after a failed reload drops the stale roster":
    holders.acquire()
    holders.onLoadSucceeded()
    # a permission change reloads the snapshot under the live roster; it fails
    holders.onLoadFailed()
    check retryTimer.running
    holders.release()
    check drops == 1
    check not retryTimer.running
    check not timer.running
    check not holders.isActive
    holders.acquire()
    check loads == 2

  test "a release with holders left keeps retrying a failed reload":
    holders.acquire()
    holders.acquire()
    holders.onLoadSucceeded()
    holders.onLoadFailed()
    holders.release()
    check drops == 0
    check retryTimer.running

  test "backgrounding after a failed first load stops the backoff, foregrounding loads":
    holders.acquire()
    holders.onLoadFailed()
    holders.onBackgrounded()
    check not retryTimer.running
    check drops == 1
    holders.onForegrounded()
    check loads == 2
    check holders.isActive

  test "backgrounding after a failed reload drops the stale roster":
    holders.acquire()
    holders.onLoadSucceeded()
    holders.onLoadFailed()
    holders.onBackgrounded()
    check drops == 1
    check not retryTimer.running
    check not holders.isActive
    holders.onForegrounded()
    check loads == 2
    check holders.isActive

  test "a drop after a failed reload happens once":
    holders.acquire()
    holders.onLoadSucceeded()
    holders.onLoadFailed()
    holders.onBackgrounded()
    holders.release()
    holders.onBackgrounded()
    check drops == 1

  test "a failed load after the last holder left drops the roster":
    holders.acquire()
    holders.release()
    check timer.running
    holders.onLoadFailed()
    check drops == 1
    check not timer.running
    check not retryTimer.running
    check not holders.isActive
