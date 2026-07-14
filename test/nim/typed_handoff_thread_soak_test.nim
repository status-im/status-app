## Cross-thread ORC soak for the typed-completion handoff.
##
## The device gate SIGSEGV'd on the GUI thread inside eqcopy(token_group) ->
## rememberCycle while applying a worker-built token graph. This reproduces the
## SHAPE minimally, under the app's memory model (--mm:orc -d:useMalloc
## --threads:on): a real worker thread builds a big ref-of-seq-of-ref graph with
## items ALIASED across two containers (like tokensOfInterestByKey +
## groupsOfInterestByKey sharing TokenItems), hands it over via the registry, and
## the main thread "applies" it. Copy-apply is what crashed on device; move-apply
## is the candidate fix. `liveItems` is the independent leak/double-free witness.
##
## Build with: nim c -r --mm:orc -d:useMalloc --threads:on

import std/[tables, strutils, atomics, sequtils, times]
import unittest

import app/core/tasks/typed_handoff

var liveItems: Atomic[int]

type
  ItemObj {.acyclic.} = object of RootObj
    key: string
    payload: string
  Item = ref ItemObj
  GroupObj {.acyclic.} = object of RootObj
    key: string
    items: seq[Item]
  Group = ref GroupObj
  BuiltResult = ref object of RootObj
    byKey: Table[string, Item]
    groupsByKey: Table[string, Group]
    groupSeq: seq[Group]

proc `=destroy`(o: var ItemObj) =
  liveItems.atomicDec
  `=destroy`(o.key)
  `=destroy`(o.payload)

proc newItem(key: string): Item =
  result = Item(key: key, payload: "x".repeat(64))
  liveItems.atomicInc

proc buildGraph(n, groups: int): BuiltResult =
  result = BuiltResult(byKey: initTable[string, Item](), groupsByKey: initTable[string, Group]())
  for i in 0 ..< n:
    let it = newItem($i)
    result.byKey[it.key] = it                       # container 1
    let gk = "g" & $(i mod groups)
    if not result.groupsByKey.hasKey(gk):
      result.groupsByKey[gk] = Group(key: gk, items: @[])
    result.groupsByKey[gk].items.add(it)            # container 2 (aliased ref)
  result.groupSeq = toSeq(result.groupsByKey.values)

# --- worker thread: build + park ---------------------------------------------
type BuildSpec = tuple[n, groups: int, outHandle: ptr TaskHandle]
proc workerBuild(spec: BuildSpec) {.thread.} =
  let h = parkHandoff(buildGraph(spec.n, spec.groups))
  spec.outHandle[] = h

proc handoffFromWorker(n, groups: int): BuiltResult =
  var handle: TaskHandle
  var t: Thread[BuildSpec]
  createThread(t, workerBuild, (n, groups, addr handle))
  joinThread(t)
  claimHandoff[BuiltResult](handle)

# Copy the built containers into service state (the crashing path under refc).
proc applyByCopy(r: BuiltResult): tuple[a: Table[string, Item], b: Table[string, Group], c: seq[Group]] =
  result.a = r.byKey
  result.b = r.groupsByKey
  result.c = r.groupSeq

# Move the containers instead of copying.
proc applyByMove(r: BuiltResult): tuple[a: Table[string, Item], b: Table[string, Group], c: seq[Group]] =
  result.a = move r.byKey
  result.b = move r.groupsByKey
  result.c = move r.groupSeq

# The whole suite is ORC-only. The handoff transfers a ref graph BETWEEN threads,
# which is sound only on ORC's shared heap (the app builds --mm:orc -d:useMalloc).
# Under refc each thread has its own GC heap, so claiming a worker-allocated graph on
# the main thread reads freed/foreign memory and crashes — so these tests are skipped
# under refc (the mm the make suite uses); run them with `nim c -r --mm:orc`.
suite "typed handoff — cross-thread ORC graph apply":

  test "move-apply of a large worker-built aliased graph: no crash, no leak":
    when compileOption("mm", "orc"):
      liveItems.store(0)
      for iter in 0 ..< 20:
        let r = handoffFromWorker(2000, 50)
        var applied = applyByMove(r)
        check applied.a.len == 2000
        check applied.b.len == 50
        check applied.c.len == 50
      check liveItems.load == 0
    else:
      skip()

  test "copy-apply of a large worker-built aliased graph (device-crash repro)":
    when compileOption("mm", "orc"):
      liveItems.store(0)
      for iter in 0 ..< 20:
        let r = handoffFromWorker(2000, 50)
        var applied = applyByCopy(r)
        check applied.a.len == 2000
      check liveItems.load == 0
    else:
      skip()

  test "perf: copy-apply is the O(graph) cost; move-apply is O(1) per container":
    # The slot's copy is the O(graph) cost; move eliminates it. Timing only (no
    # hard threshold — just evidence that copy >> move on the same graph).
    when compileOption("mm", "orc"):
      const N = 20000
      var rCopy = handoffFromWorker(N, 200)
      let t0 = epochTime()
      var appliedCopy = applyByCopy(rCopy)
      let copyMs = (epochTime() - t0) * 1000
      var rMove = handoffFromWorker(N, 200)
      let t1 = epochTime()
      var appliedMove = applyByMove(rMove)
      let moveMs = (epochTime() - t1) * 1000
      echo "  [perf] copy-apply=", copyMs.formatFloat(ffDecimal, 3), "ms  move-apply=",
        moveMs.formatFloat(ffDecimal, 3), "ms  (N=", N, ")"
      check appliedCopy.a.len == N
      check appliedMove.a.len == N
      check moveMs < copyMs   # move must be cheaper than the per-element copy
    else:
      skip()
