## GREEN counterpart of collectibles_selector_bench.nim.
##
## Boots an offscreen QQmlApplicationEngine, context-injects a real
## CollectiblesSelectorModel, and loads collectibles_selector_model_scene.qml --
## two ListViews bound DIRECTLY to the model + its filteredFlatModel (no proxies).
## The Nim driver builds the SAME synthetic universe as the RED adaptor bench
## (large GLOBAL set, the probed account owns ~30) and applies the SAME update
## classes (build / account switch / chain filter / append 50 / balance update)
## by calling the model's producer seam; the scene forwards the models' granular
## signals + delegate churn to the native `bench` object.
##
## GREEN gate (flips the adaptor baseline's RED): after the initial bulk load,
## NO scenario resets the model; a single ERC-1155 balance tick propagates as
## O(1) dataChanged rows with ZERO delegate churn; an account switch is bounded
## by the ~30 displayed rows, not the GLOBAL universe. The build stays a single
## bulk load whose cost tracks the pure O(global) scan, not the adaptor's
## per-row-QObject construction (compare wall/stall to the RED table).

import os, times, strformat
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

import app/modules/shared_models/collectibles_selector_model

type Row = object
  size: int
  scenario: string
  wallMs: float
  maxStallMs: float
  resetsG, resetsF: int
  insertsG, insertsF: int
  dcRowsG, dcRowsF: int
  delCreatedG, delDestroyedG: int
  delCreatedF, delDestroyedF: int
  countFlat, countGrouped: int

QtObject:
  type Bench = ref object of QObject
    ready: bool
    monitoring: bool
    lastTickNs: float
    maxStallMs: float
    resets: array[2, int]
    inserts: array[2, int]
    removes: array[2, int]
    dcRows: array[2, int]
    delCreated: array[2, int]
    delDestroyed: array[2, int]
    lastCountFlat: int
    lastCountGrouped: int

  proc newBench(): Bench =
    new(result)
    result.QObject.setup

  proc requestRelayout(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true
  proc nowMs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0

  proc onDataChanged(self: Bench, which: int, top: int, bottom: int) {.slot.} =
    if self.monitoring: self.dcRows[which] += (bottom - top + 1)
  proc onModelReset(self: Bench, which: int) {.slot.} =
    if self.monitoring: inc self.resets[which]
  proc onRowsInserted(self: Bench, which: int) {.slot.} =
    if self.monitoring: inc self.inserts[which]
  proc onRowsRemoved(self: Bench, which: int) {.slot.} =
    if self.monitoring: inc self.removes[which]
  proc onDelegateCreated(self: Bench, which: int) {.slot.} =
    if self.monitoring: inc self.delCreated[which]
  proc onDelegateDestroyed(self: Bench, which: int) {.slot.} =
    if self.monitoring: inc self.delDestroyed[which]
  proc reportCounts(self: Bench, flat: int, grouped: int) {.slot.} =
    self.lastCountFlat = flat
    self.lastCountGrouped = grouped

  proc onStallTick(self: Bench) {.slot.} =
    if not self.monitoring: return
    let n = self.nowMs()
    let delta = n - self.lastTickNs
    if delta > self.maxStallMs: self.maxStallMs = delta
    self.lastTickNs = n

  proc resetWindow(self: Bench) =
    self.maxStallMs = 0.0
    for i in 0 .. 1:
      self.resets[i] = 0; self.inserts[i] = 0; self.removes[i] = 0
      self.dcRows[i] = 0; self.delCreated[i] = 0; self.delDestroyed[i] = 0
  proc beginMonitor(self: Bench) =
    self.resetWindow()
    self.lastTickNs = self.nowMs()
    self.monitoring = true
  proc endMonitor(self: Bench) = self.monitoring = false

  proc pump(self: Bench) =
    self.requestRelayout()
    for _ in 0 ..< 8:
      QCoreApplication.processEvents()

# --- synthetic universe (mirrors the RED scene's makeRow / ownerOf) -----------

const
  chains = [1, 10, 42161, 8453, 56]
  probeAccounts = ["acc_0", "acc_1", "acc_2"]
  whaleAccount = "acc_whale"
  ownedPerAccount = 30

proc ownerOf(i: int): string =
  let probed = probeAccounts.len * ownedPerAccount
  if i < probed: probeAccounts[i div ownedPerAccount]
  else: whaleAccount

proc makeItem(i: int, owner = ""): CollectibleItem =
  let isComm = (i mod 10 == 0)
  let comm = i div 300
  let coll = i div 4
  let acc = if owner.len > 0: owner else: ownerOf(i)
  CollectibleItem(
    key: "col_" & $i,
    chainId: chains[i mod chains.len],
    collectionUid: if isComm: "ccoll_" & $(i div 40) else: "coll_" & $coll,
    collectionName: if isComm: "CCollection " & $(i div 40) else: "Collection " & $coll,
    contractAddress: "contract_" & $coll,
    tokenId: $i,
    name: "Collectible " & $i,
    communityId: if isComm: "community_" & $comm else: "",
    communityName: if isComm: "Community " & $comm else: "",
    communityPrivilegesLevel: 2,
    ownership: @[CollectibleOwnership(accountAddress: acc, balance: 1)])

proc buildUniverse(n: int): seq[CollectibleItem] =
  result = newSeqOfCap[CollectibleItem](n)
  for i in 0 ..< n:
    result.add(makeItem(i))

let networks = @[
  CollectiblesNetworkInfo(chainId: 1, chainName: "Mainnet", iconUrl: "network/ethereum"),
  CollectiblesNetworkInfo(chainId: 10, chainName: "Optimism", iconUrl: "network/ethereum"),
  CollectiblesNetworkInfo(chainId: 42161, chainName: "Arbitrum", iconUrl: "network/ethereum"),
  CollectiblesNetworkInfo(chainId: 8453, chainName: "Base", iconUrl: "network/ethereum"),
  CollectiblesNetworkInfo(chainId: 56, chainName: "BSC", iconUrl: "network/ethereum"),
]

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\twall_ms\tmax_stall_ms\tresetsG\tresetsF\tinsG\tinsF\tdcRowsG\tdcRowsF\tdelCreG\tdelDelG\tdelCreF\tdelDelF\tcountFlat\tcountGrouped\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.wallMs:.4f}\t{r.maxStallMs:.4f}\t{r.resetsG}\t{r.resetsF}\t{r.insertsG}\t{r.insertsF}\t{r.dcRowsG}\t{r.dcRowsF}\t{r.delCreatedG}\t{r.delDestroyedG}\t{r.delCreatedF}\t{r.delDestroyedF}\t{r.countFlat}\t{r.countGrouped}\n")

const sizes = [200, 1000, 3000]

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()

  let model = newCollectiblesSelectorModel()
  model.setParams(CollectiblesSelectorParams(accountKey: "acc_0",
    enabledChainIds: @[], filterCommunityOwnerAndMasterTokens: true))

  let bench = newBench()
  let engine = newQQmlApplicationEngine()
  engine.setRootContextProperty("collectiblesModel", newQVariant(model))
  engine.setRootContextProperty("bench", newQVariant(bench))

  let base = getCurrentDir()
  let sceneFile = base / "test" / "nim" / "benchmarks" / "collectibles_selector_model_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 200000:
    QCoreApplication.processEvents(); inc spins
  if not bench.ready:
    echo "SKIP: collectibles terminal-model scene did not load"
    quit(0)

  var rows: seq[Row] = @[]
  var universe: seq[CollectibleItem]

  proc capture(size: int, scenario: string, wallMs: float): Row =
    Row(size: size, scenario: scenario, wallMs: wallMs, maxStallMs: bench.maxStallMs,
      resetsG: bench.resets[0], resetsF: bench.resets[1],
      insertsG: bench.inserts[0], insertsF: bench.inserts[1],
      dcRowsG: bench.dcRows[0], dcRowsF: bench.dcRows[1],
      delCreatedG: bench.delCreated[0], delDestroyedG: bench.delDestroyed[0],
      delCreatedF: bench.delCreated[1], delDestroyedF: bench.delDestroyed[1],
      countFlat: bench.lastCountFlat, countGrouped: bench.lastCountGrouped)

  proc measure(size: int, scenario: string, mutate: proc()): Row =
    bench.beginMonitor()
    let t0 = bench.nowMs()
    mutate()
    bench.pump()
    let wall = bench.nowMs() - t0
    bench.endMonitor()
    result = capture(size, scenario, wall)
    rows.add(result)
    stderr.writeLine(&"[bench] size={size} {scenario} wall={result.wallMs:.2f}ms stall={result.maxStallMs:.2f} resetsF={result.resetsF} dcRowsF={result.dcRowsF} insF={result.insertsF} delCreF={result.delCreatedF} delDelF={result.delDestroyedF} counts={result.countFlat}/{result.countGrouped}")
    stderr.flushFile()

  proc runSize(size: int) =
    # fresh account/chain state per size
    model.setAccountKey("acc_0")
    model.setEnabledChainIds(@[])
    universe = buildUniverse(size)

    discard measure(size, "build", proc() = model.setSource(universe, networks))
    discard measure(size, "account_switch", proc() = model.setAccountKey("acc_1"))
    discard measure(size, "chain_filter", proc() = model.setEnabledChainIds(@[1, 10]))
    # restore no chain filter before append so its output is comparable
    model.setEnabledChainIds(@[])
    bench.pump()
    discard measure(size, "append_50", proc() =
      let start = universe.len
      for i in 0 ..< 50:
        universe.add(makeItem(start + i, owner = "acc_1")) # owned by the current account
      model.setSource(universe, networks))
    discard measure(size, "balance_update", proc() =
      # bump the ERC-1155 balance of the first item owned by the current account
      for i in 0 ..< universe.len:
        if universe[i].ownership.len > 0 and universe[i].ownership[0].accountAddress == "acc_1":
          universe[i].ownership[0].balance += 1
          break
      model.setSource(universe, networks))

  for size in sizes:
    runSize(size)

  let table = formatTable(rows)
  echo "\n===== CollectiblesSelectorModel terminal-model cost (host, offscreen, GREEN) ====="
  echo table

  let resultsDir = base / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("collectibles_selector_green_" & stamp & ".tsv"), table)

  proc rowFor(size: int, scenario: string): Row =
    for r in rows:
      if r.size == size and r.scenario == scenario: return r
    doAssert false, &"missing {scenario}@{size}"

  # GREEN structural gate: flips the adaptor baseline's RED.
  for r in rows:
    if r.scenario == "build":
      # First bulk load is a single reset per view (empty -> N); allowed.
      continue
    doAssert r.resetsG == 0 and r.resetsF == 0,
      &"terminal model reset in '{r.scenario}' at size {r.size}"
  for size in sizes:
    let bu = rowFor(size, "balance_update")
    # a single ERC-1155 tick: O(1) dataChanged rows, and NO delegate churn (the
    # shown balance updates in place; the group's subitem count is unchanged).
    doAssert bu.dcRowsF <= 4 and bu.dcRowsG <= 4,
      &"balance_update not O(1) at size {size} (flat {bu.dcRowsF}, grouped {bu.dcRowsG} rows)"
    doAssert bu.delCreatedF == 0 and bu.delDestroyedF == 0,
      &"balance_update churned flat delegates at size {size} ({bu.delCreatedF}/{bu.delDestroyedF})"
    doAssert bu.delCreatedG == 0 and bu.delDestroyedG == 0,
      &"balance_update churned grouped delegates at size {size}"
    let ap = rowFor(size, "append_50")
    doAssert ap.insertsF > 0 and ap.resetsF == 0,
      &"append_50 should be a bounded insert (no reset) at size {size}"
    # account switch output stays ~30 regardless of GLOBAL size (O(displayed)).
    let asw = rowFor(size, "account_switch")
    doAssert asw.countFlat > 0 and asw.countFlat < 200,
      &"account_switch output not bounded to the account's ~30 at size {size} (got {asw.countFlat})"

  echo "GREEN structural assertions passed"
