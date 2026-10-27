import std/[unittest, sets, tables]

import app/core/held_resource

type FakeTimer = ref object
  running: bool
  startedWith: int
  starts: int
  disposed: bool

proc fake(timer: FakeTimer): HeldResourceTimer =
  HeldResourceTimer(
    start: proc(ms: int) =
      timer.running = true
      timer.startedWith = ms
      timer.starts += 1,
    stop: proc() =
      timer.running = false,
    dispose: proc() =
      timer.disposed = true,
  )

proc fire(timer: FakeTimer, holders: HeldResource) =
  doAssert timer.running
  timer.running = false
  holders.onReleaseTimeout()

proc fireRetry(timer: FakeTimer, holders: HeldResource) =
  doAssert timer.running
  timer.running = false
  holders.onRetryTimeout()

suite "held resource":
  setup:
    let timer = FakeTimer()
    let retryTimer = FakeTimer()
    var loads = 0
    var drops = 0
    var gen = 0
    let holders = newHeldResource(timer.fake(), retryTimer.fake(),
      onLoad = (proc(generation: int) =
        inc loads
        gen = generation),
      onDrop = (proc() = inc drops))

  test "the first holder loads, later ones do not":
    holders.acquire()
    holders.acquire()
    check loads == 1
    check holders.holderCount == 2
    check holders.isActive

  test "the resource is dropped about two minutes after the last holder goes":
    holders.acquire()
    holders.acquire()
    holders.release()
    check not timer.running
    holders.release()
    check timer.running
    check timer.startedWith == DefaultIdleReleaseMs
    check DefaultIdleReleaseMs == 120_000
    check drops == 0
    timer.fire(holders)
    check drops == 1
    check not holders.isActive

  test "the idle release delay can be set":
    let custom = newHeldResource(timer.fake(), retryTimer.fake(),
      onLoad = (proc(generation: int) = discard), onDrop = (proc() = discard), idleReleaseMs = 500)
    custom.acquire()
    custom.release()
    check timer.startedWith == 500

  test "a holder arriving before the timeout keeps the resource":
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

  test "backgrounding without a resource does nothing":
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
      holders.onLoadFailed(gen)
      check not holders.isActive
      check retryTimer.running
      delays.add retryTimer.startedWith
      retryTimer.fireRetry(holders)
      check loads == attempt + 1
      check holders.isActive
    check delays == @[2_000, 5_000, 15_000, 60_000, 60_000]
    check LoadRetryDelaysMs == [2_000, 5_000, 15_000, 60_000]
    # a success starts the backoff over
    holders.onLoadSucceeded(gen)
    holders.onLoadFailed(gen)
    check retryTimer.startedWith == 2_000

  test "a failure then a success leaves the resource loaded":
    holders.acquire()
    holders.onLoadFailed(gen)
    retryTimer.fireRetry(holders)
    holders.onLoadSucceeded(gen)
    check loads == 2
    check holders.isActive
    check not retryTimer.running

  test "a success reported after the same load failed is ignored":
    holders.acquire()
    let failed = gen
    holders.onLoadFailed(failed)
    holders.onLoadSucceeded(failed)
    check not holders.isActive
    check retryTimer.running
    holders.release()
    check drops == 1
    check not retryTimer.running

  test "a retry still follows a success reported after the same load failed":
    holders.acquire()
    let failed = gen
    holders.onLoadFailed(failed)
    holders.onLoadSucceeded(failed)
    retryTimer.fireRetry(holders)
    check loads == 2
    check holders.isActive
    holders.onLoadFailed(gen)
    # the backoff did not start over
    check retryTimer.startedWith == 5_000

  test "backgrounding drops after a success reported for a failed load":
    holders.acquire()
    holders.onLoadFailed(gen)
    holders.onLoadSucceeded(gen)
    holders.onBackgrounded()
    check drops == 1

  test "a release during the backoff after a failed first load stops retrying":
    holders.acquire()
    holders.onLoadFailed(gen)
    check retryTimer.running
    holders.release()
    check not retryTimer.running
    holders.onRetryTimeout()
    check loads == 1
    check not timer.running
    # nothing was loaded; the drop only ends the capture of the failed load
    check drops == 1
    check not holders.isActive
    # the next first holder loads at once
    holders.acquire()
    check loads == 2

  test "a release after a failed reload drops the stale resource":
    holders.acquire()
    holders.onLoadSucceeded(gen)
    holders.onLoadFailed(gen)
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
    holders.onLoadSucceeded(gen)
    holders.onLoadFailed(gen)
    holders.release()
    check drops == 0
    check retryTimer.running

  test "backgrounding after a failed first load stops the backoff, foregrounding loads":
    holders.acquire()
    holders.onLoadFailed(gen)
    holders.onBackgrounded()
    check not retryTimer.running
    check drops == 1
    holders.onForegrounded()
    check loads == 2
    check holders.isActive

  test "backgrounding after a failed reload drops the stale resource":
    holders.acquire()
    holders.onLoadSucceeded(gen)
    holders.onLoadFailed(gen)
    holders.onBackgrounded()
    check drops == 1
    check not retryTimer.running
    check not holders.isActive
    holders.onForegrounded()
    check loads == 2
    check holders.isActive

  test "a drop after a failed reload happens once":
    holders.acquire()
    holders.onLoadSucceeded(gen)
    holders.onLoadFailed(gen)
    holders.onBackgrounded()
    holders.release()
    holders.onBackgrounded()
    check drops == 1

  test "an idle release during a retry load drops once, also on background":
    holders.acquire()
    holders.onLoadFailed(gen)
    retryTimer.fireRetry(holders)
    holders.release()
    timer.fire(holders)
    check drops == 1
    holders.onBackgrounded()
    check drops == 1

  test "a failed load after the last holder left drops the resource":
    holders.acquire()
    holders.release()
    check timer.running
    holders.onLoadFailed(gen)
    check drops == 1
    check not timer.running
    check not retryTimer.running
    check not holders.isActive

  test "a result of a load from before a drop is ignored":
    holders.acquire()
    let dropped = gen
    holders.release()
    timer.fire(holders)
    holders.acquire()
    holders.onLoadFailed(dropped)
    check holders.isActive
    check not retryTimer.running
    holders.release()
    holders.onLoadFailed(dropped)
    check drops == 1
    check timer.running

  test "after dispose nothing loads, drops or arms a timer":
    holders.acquire()
    holders.onLoadFailed(gen)
    check retryTimer.running
    holders.dispose()
    check not retryTimer.running
    check timer.disposed
    check retryTimer.disposed
    let starts = timer.starts + retryTimer.starts
    holders.onRetryTimeout()
    holders.onLoadFailed(gen)
    holders.onLoadSucceeded(gen)
    holders.release()
    holders.acquire()
    holders.invalidate()
    holders.onForegrounded()
    holders.onBackgrounded()
    holders.release()
    holders.onReleaseTimeout()
    check loads == 1
    check drops == 0
    check timer.starts + retryTimer.starts == starts
    check not timer.running
    check not retryTimer.running

suite "held resource invalidation":
  setup:
    let timer = FakeTimer()
    let retryTimer = FakeTimer()
    var loads = 0
    var drops = 0
    var gen = 0
    let holders = newHeldResource(timer.fake(), retryTimer.fake(),
      onLoad = (proc(generation: int) =
        inc loads
        gen = generation),
      onDrop = (proc() = inc drops))

  test "a held resource reloads in place":
    holders.acquire()
    holders.onLoadSucceeded(gen)
    holders.invalidate()
    check loads == 2
    check drops == 0
    check holders.isActive
    check holders.holderCount == 1

  test "a held resource waiting on a retry loads now":
    holders.acquire()
    holders.onLoadFailed(gen)
    check retryTimer.running
    holders.invalidate()
    check loads == 2
    check not retryTimer.running
    check holders.isActive
    holders.onLoadFailed(gen)
    check retryTimer.startedWith == 2_000

  test "an idle resource is dropped now":
    holders.acquire()
    holders.release()
    check timer.running
    holders.invalidate()
    check drops == 1
    check not timer.running
    check not holders.isActive
    check loads == 1
    holders.acquire()
    check loads == 2

  test "a resource that is not loaded is left alone":
    holders.invalidate()
    check loads == 0
    check drops == 0
    check not holders.isActive

  test "a superseded load failing does not undo the reload's success":
    holders.acquire()
    let first = gen
    holders.invalidate()
    let second = gen
    check second != first
    holders.onLoadFailed(first)
    check holders.isActive
    check not retryTimer.running
    holders.onLoadSucceeded(second)
    holders.release()
    timer.fire(holders)
    check drops == 1
    check loads == 2

  test "a superseded load succeeding does not reset the reload's backoff":
    holders.acquire()
    holders.onLoadFailed(gen)
    retryTimer.fireRetry(holders)
    holders.onLoadFailed(gen)
    retryTimer.fireRetry(holders)
    let first = gen
    holders.invalidate()
    holders.onLoadSucceeded(first)
    holders.onLoadFailed(gen)
    check not holders.isActive
    check retryTimer.startedWith == 15_000

  test "a backgrounded resource with holders waits for the foreground":
    holders.acquire()
    holders.onBackgrounded()
    holders.invalidate()
    check loads == 1
    check drops == 1
    holders.onForegrounded()
    check loads == 2

suite "held resources by key":
  setup:
    let timer = FakeTimer()
    let retryTimer = FakeTimer()
    var clock = 0'i64
    var loads: seq[string]
    var drops: seq[string]
    var gens: Table[string, int]
    let registry = newHeldResources[string](timer.fake(), retryTimer.fake(),
      now = (proc(): int64 = clock),
      onLoad = (proc(key: string, generation: int) =
        loads.add key
        gens[key] = generation),
      onDrop = (proc(key: string) = drops.add key))

    proc elapse(ms: int) =
      clock += ms

    proc fireRelease() =
      doAssert timer.running
      timer.running = false
      registry.onReleaseTimeout()

    proc fireRetry() =
      doAssert retryTimer.running
      retryTimer.running = false
      registry.onRetryTimeout()

  test "keys are held independently":
    registry.acquire("a")
    registry.acquire("a")
    registry.acquire("b")
    check loads == @["a", "b"]
    check registry.holderCount("a") == 2
    check registry.holderCount("b") == 1
    registry.release("a")
    check registry.holderCount("a") == 1
    check not timer.running
    check registry.isActive("a")
    check registry.isActive("b")

  test "an unknown key has no holders and is not active":
    check registry.holderCount("x") == 0
    check not registry.isActive("x")
    registry.release("x")
    registry.onLoadFailed("x", gens.getOrDefault("x"))
    registry.onLoadSucceeded("x", gens.getOrDefault("x"))
    registry.invalidate("x")
    check loads.len == 0
    check drops.len == 0
    check not timer.running
    check registry.len == 0

  test "the shared release timer is armed for the earliest deadline":
    registry.acquire("a")
    registry.acquire("b")
    registry.release("a")
    check timer.running
    check timer.startedWith == DefaultIdleReleaseMs
    let starts = timer.starts
    elapse 30_000
    registry.release("b")
    # "a" is still due first
    check timer.starts == starts
    elapse 90_000
    fireRelease()
    check drops == @["a"]
    check timer.running
    check timer.startedWith == 30_000
    elapse 30_000
    fireRelease()
    check drops == @["a", "b"]
    check not timer.running

  test "every due key is dropped on one timeout":
    registry.acquire("a")
    registry.acquire("b")
    registry.acquire("c")
    registry.release("a")
    registry.release("b")
    elapse 1_000
    registry.release("c")
    elapse DefaultIdleReleaseMs
    fireRelease()
    check drops.toHashSet == ["a", "b", "c"].toHashSet
    check drops.len == 3
    check not timer.running

  test "an early timeout drops nothing and re-arms for the remaining time":
    registry.acquire("a")
    registry.release("a")
    elapse 100_000
    fireRelease()
    check drops.len == 0
    check timer.running
    check timer.startedWith == 20_000

  test "re-acquiring in the idle window cancels only that key's release":
    registry.acquire("a")
    registry.acquire("b")
    registry.release("a")
    elapse 10_000
    registry.release("b")
    registry.acquire("a")
    check timer.running
    check timer.startedWith == DefaultIdleReleaseMs
    elapse DefaultIdleReleaseMs
    fireRelease()
    check drops == @["b"]
    check registry.isActive("a")
    check loads == @["a", "b"]

  test "re-acquiring the only idle key stops the shared timer":
    registry.acquire("a")
    registry.release("a")
    check timer.running
    registry.acquire("a")
    check not timer.running

  test "a dropped key leaves the table":
    registry.acquire("a")
    registry.release("a")
    check registry.len == 1
    elapse DefaultIdleReleaseMs
    fireRelease()
    check registry.len == 0
    registry.acquire("a")
    check loads == @["a", "a"]
    check registry.len == 1

  test "backgrounding drops every key, foregrounding reloads the held ones":
    registry.acquire("a")
    registry.acquire("b")
    registry.release("b")
    registry.onBackgrounded()
    check drops.toHashSet == ["a", "b"].toHashSet
    check not timer.running
    check not registry.isActive("a")
    check registry.holderCount("a") == 1
    check registry.len == 1
    registry.onForegrounded()
    check loads == @["a", "b", "a"]
    check registry.isActive("a")

  test "a failed load retries per key with its own backoff":
    registry.acquire("a")
    registry.acquire("b")
    registry.onLoadFailed("a", gens.getOrDefault("a"))
    check retryTimer.running
    check retryTimer.startedWith == 2_000
    elapse 1_000
    registry.onLoadFailed("b", gens.getOrDefault("b"))
    elapse 1_000
    fireRetry()
    check loads == @["a", "b", "a"]
    check retryTimer.running
    check retryTimer.startedWith == 1_000
    registry.onLoadFailed("a", gens.getOrDefault("a"))
    elapse 1_000
    fireRetry()
    check loads == @["a", "b", "a", "b"]
    # the second failure of "a" waits 5 s
    check retryTimer.startedWith == 4_000
    elapse 4_000
    fireRetry()
    check loads == @["a", "b", "a", "b", "a"]
    check not retryTimer.running

  test "releasing a key during its backoff drops it and leaves the table":
    registry.acquire("a")
    registry.onLoadFailed("a", gens.getOrDefault("a"))
    registry.release("a")
    check drops == @["a"]
    check not retryTimer.running
    check registry.len == 0

  test "a success reported after a key's load failed is ignored":
    registry.acquire("a")
    let failed = gens["a"]
    registry.onLoadFailed("a", failed)
    registry.onLoadSucceeded("a", failed)
    check not registry.isActive("a")
    check retryTimer.running
    registry.release("a")
    check drops == @["a"]
    check not retryTimer.running
    check registry.len == 0

  test "invalidating a key reloads it if held and drops it if idle":
    registry.acquire("a")
    registry.acquire("b")
    registry.release("b")
    registry.invalidate("a")
    registry.invalidate("b")
    check loads == @["a", "b", "a"]
    check drops == @["b"]
    check not timer.running
    check registry.len == 1

  test "invalidating all keys applies to each":
    registry.acquire("a")
    registry.acquire("b")
    registry.release("b")
    registry.invalidateAll()
    check loads == @["a", "b", "a"]
    check drops == @["b"]
    check registry.len == 1

  test "a drop callback may acquire another key":
    var chained: HeldResources[string]
    chained = newHeldResources[string](timer.fake(), retryTimer.fake(),
      now = (proc(): int64 = clock),
      onLoad = (proc(key: string, generation: int) =
        loads.add key
        gens[key] = generation),
      onDrop = (proc(key: string) =
        drops.add key
        if key == "a":
          chained.acquire("c")))
    chained.acquire("a")
    chained.acquire("b")
    chained.release("a")
    chained.release("b")
    elapse DefaultIdleReleaseMs
    timer.running = false
    chained.onReleaseTimeout()
    check drops.toHashSet == ["a", "b"].toHashSet
    check chained.isActive("c")
    check chained.len == 1

  test "a release timeout survives a drop callback releasing another key":
    var chained: HeldResources[string]
    chained = newHeldResources[string](timer.fake(), retryTimer.fake(),
      now = (proc(): int64 = clock),
      onLoad = (proc(key: string, generation: int) =
        loads.add key
        gens[key] = generation),
      onDrop = (proc(key: string) =
        drops.add key
        if key == "a":
          chained.release("b")))
    chained.acquire("a")
    chained.acquire("b")
    chained.acquire("c")
    # "b" waits on a retry, so its release drops it at once
    chained.onLoadFailed("b", gens["b"])
    chained.release("a")
    chained.release("c")
    elapse DefaultIdleReleaseMs
    timer.running = false
    chained.onReleaseTimeout()
    check drops.toHashSet == ["a", "b", "c"].toHashSet
    check drops.len == 3
    check chained.len == 0
    check not timer.running
    check not retryTimer.running

  test "a retry timeout survives a load callback releasing another key":
    # both keys are due; whichever reloads first releases the other
    var chained: HeldResources[string]
    chained = newHeldResources[string](timer.fake(), retryTimer.fake(),
      now = (proc(): int64 = clock),
      onLoad = (proc(key: string, generation: int) =
        loads.add key
        gens[key] = generation
        if loads.len == 3:
          chained.release(if key == "a": "b" else: "a")),
      onDrop = (proc(key: string) = drops.add key))
    chained.acquire("a")
    chained.acquire("b")
    chained.onLoadFailed("a", gens["a"])
    chained.onLoadFailed("b", gens["b"])
    elapse 2_000
    retryTimer.running = false
    chained.onRetryTimeout()
    check loads.len == 3
    check drops.len == 1
    check drops[0] != loads[2]
    check chained.len == 1
    check not retryTimer.running

  test "an idle release of a key during its retry load drops it once, also on background":
    registry.acquire("a")
    registry.onLoadFailed("a", gens["a"])
    elapse 2_000
    fireRetry()
    registry.release("a")
    elapse DefaultIdleReleaseMs
    fireRelease()
    check drops == @["a"]
    check registry.len == 0
    registry.onBackgrounded()
    check drops == @["a"]

  test "a failed load of an idle key drops it":
    registry.acquire("a")
    registry.release("a")
    check timer.running
    registry.onLoadFailed("a", gens["a"])
    check drops == @["a"]
    check registry.len == 0
    check not timer.running
    check not retryTimer.running

  test "a superseded load of a key is ignored after a reload":
    registry.acquire("a")
    let first = gens["a"]
    registry.invalidate("a")
    registry.onLoadFailed("a", first)
    check registry.isActive("a")
    check not retryTimer.running
    registry.onLoadSucceeded("a", gens["a"])
    registry.onLoadFailed("a", first)
    check registry.isActive("a")
    registry.onLoadFailed("a", gens["a"])
    check not registry.isActive("a")
    check retryTimer.running

  test "a result of a key's load from before its drop is ignored":
    registry.acquire("a")
    let dropped = gens["a"]
    registry.release("a")
    elapse DefaultIdleReleaseMs
    fireRelease()
    check registry.len == 0
    registry.acquire("a")
    check gens["a"] != dropped
    registry.onLoadFailed("a", dropped)
    check registry.isActive("a")
    check not retryTimer.running

  test "after dispose no key loads or drops and no timer is armed":
    registry.acquire("a")
    registry.acquire("b")
    registry.onLoadFailed("a", gens["a"])
    registry.release("b")
    registry.dispose()
    check not timer.running
    check not retryTimer.running
    check timer.disposed
    check retryTimer.disposed
    let starts = timer.starts + retryTimer.starts
    registry.acquire("c")
    registry.release("a")
    registry.invalidateAll()
    registry.onRetryTimeout()
    registry.onReleaseTimeout()
    registry.onBackgrounded()
    registry.onForegrounded()
    registry.onLoadFailed("b", gens["b"])
    check loads == @["a", "b"]
    check drops.len == 0
    check registry.len == 0
    check timer.starts + retryTimer.starts == starts
