import std/unittest

import app/modules/shared_models/community_roster_holders

type FakeTimer = ref object
  running: bool
  startedWith: int

proc fake(timer: FakeTimer): RosterReleaseTimer =
  RosterReleaseTimer(
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

suite "roster holders":
  setup:
    let timer = FakeTimer()
    var loads = 0
    var drops = 0
    let holders = newRosterHolders(timer.fake(),
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

  test "a failed load is retried by the next first holder, not in a loop":
    holders.acquire()
    holders.onLoadFailed()
    check not holders.isActive
    check loads == 1
    holders.release()
    check not timer.running
    holders.acquire()
    check loads == 2
