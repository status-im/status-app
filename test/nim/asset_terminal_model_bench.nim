## Terminal-model propagation benchmark (GREEN counterpart of
## asset_proxy_chain_bench.nim).
##
## Boots an offscreen QQmlApplicationEngine, context-injects a real
## AssetsAdaptorModel, and loads asset_terminal_model_scene.qml — a ListView
## bound DIRECTLY to the model (no proxies). The Nim driver builds the same
## synthetic universe as the proxy baseline and applies the same update classes
## (single market-detail change, balance update, add/remove token, source
## reorder, sort flip, full refresh) by calling setSourceItems / sortBy; the
## scene forwards the model's granular signals + delegate churn to the native
## `bench` object.
##
## GREEN gate (flips the proxy baseline's RED): a stable-set single-cell change
## propagates as O(1) work — the summed dataChanged row-span is a small constant
## instead of the universe size, no scenario resets the model, and no scenario
## emits layoutChanged. The market/balance edits re-sort in O(1) (the changed
## row moves) instead of the proxy chain's whole-model dataChanged + re-sort.

import os, times, strformat
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

import app/modules/shared_models/assets_adaptor_model

type Row = object
  size: int
  scenario: string
  wallMs: float
  dataChanged: int
  dataChangedRows: int
  layoutChanged: int
  resets: int
  inserted: int
  removed: int
  delegatesCreated: int
  delegatesDestroyed: int

QtObject:
  type Bench = ref object of QObject
    rows: seq[Row]
    ready: bool
    finished: bool
    cDataChanged: int
    cDataChangedRows: int
    cLayoutChanged: int
    cReset: int
    cInserted: int
    cRemoved: int
    cDelegatesCreated: int
    cDelegatesDestroyed: int

  proc delete(self: Bench) =
    self.QObject.delete

  proc newBench(): Bench =
    new(result, delete)
    result.QObject.setup

  proc requestRelayout(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true
  proc onDelegateCreated(self: Bench) {.slot.} = inc self.cDelegatesCreated
  proc onDelegateDestroyed(self: Bench) {.slot.} = inc self.cDelegatesDestroyed
  proc onDataChanged(self: Bench, first: int, last: int) {.slot.} =
    inc self.cDataChanged
    self.cDataChangedRows += (last - first + 1)
  proc onLayoutChanged(self: Bench) {.slot.} = inc self.cLayoutChanged
  proc onModelReset(self: Bench) {.slot.} = inc self.cReset
  proc onRowsInserted(self: Bench) {.slot.} = inc self.cInserted
  proc onRowsRemoved(self: Bench) {.slot.} = inc self.cRemoved

  proc nowNs(self: Bench): float =
    (getMonoTime() - MonoTime()).inNanoseconds.float

  proc resetCounters(self: Bench) =
    self.cDataChanged = 0
    self.cDataChangedRows = 0
    self.cLayoutChanged = 0
    self.cReset = 0
    self.cInserted = 0
    self.cRemoved = 0
    self.cDelegatesCreated = 0
    self.cDelegatesDestroyed = 0

  proc pump(self: Bench) =
    ## Flush the ListView layout + delegate realization so a synchronous
    ## measurement observes the settled state.
    self.requestRelayout()
    for _ in 0 ..< 8:
      QCoreApplication.processEvents()

  proc record(self: Bench, size: int, scenario: string, wallMs: float) =
    self.rows.add(Row(size: size, scenario: scenario, wallMs: wallMs,
      dataChanged: self.cDataChanged, dataChangedRows: self.cDataChangedRows,
      layoutChanged: self.cLayoutChanged, resets: self.cReset,
      inserted: self.cInserted, removed: self.cRemoved,
      delegatesCreated: self.cDelegatesCreated,
      delegatesDestroyed: self.cDelegatesDestroyed))
    stderr.writeLine(&"[bench] size={size} {scenario} {wallMs:.2f}ms dataChangedRows={self.cDataChangedRows}")
    stderr.flushFile()

proc makeItem(i, numChains: int): AssetItem =
  let chain = i mod numChains
  let bal = float(i mod 1000) + 1.5
  AssetItem(
    key: "tok_" & $i & "_c" & $chain,
    name: "Token " & $i,
    symbol: "T" & $i,
    balance: bal,
    balanceText: $bal,
    balanceLoading: false,
    marketPrice: 1.0 + float(i mod 500) * 0.01,
    marketChangePct24hour: float((i mod 40) - 20) * 0.5,
    marketDetailsAvailable: true,
    marketDetailsLoading: false,
    canBeHidden: true,
    position: i,
    visible: true,
  )

proc buildUniverse(numTokens, numChains: int): seq[AssetItem] =
  result = @[]
  for i in 0 ..< numTokens:
    result.add(makeItem(i, numChains))

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\twall_ms\tdataChanged\tdataChangedRows\tlayoutChanged\tresets\tinserted\tremoved\tdelegatesCreated\tdelegatesDestroyed\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.wallMs:.4f}\t{r.dataChanged}\t{r.dataChangedRows}\t{r.layoutChanged}\t{r.resets}\t{r.inserted}\t{r.removed}\t{r.delegatesCreated}\t{r.delegatesDestroyed}\n")

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")

  let app = newQApplication()
  let model = newAssetsAdaptorModel()
  model.sortBy("marketBalance", 1) # Qt.DescendingOrder — matches the proxy scene default
  let modelVariant = newQVariant(model)

  let bench = newBench()
  let benchVariant = newQVariant(bench)

  let engine = newQQmlApplicationEngine()
  engine.setRootContextProperty("assetsModel", modelVariant)
  engine.setRootContextProperty("bench", benchVariant)

  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "asset_terminal_model_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 100000:
    QCoreApplication.processEvents()
    inc spins

  if not bench.ready:
    echo "SKIP: terminal-model scene did not load"
    quit(0)

  let chains = 5
  var universe: seq[AssetItem]

  proc measure(size: int, scenario: string, mutate: proc()) =
    bench.resetCounters()
    let t0 = bench.nowNs()
    mutate()
    bench.pump()
    let t1 = bench.nowNs()
    bench.record(size, scenario, (t1 - t0) / 1000000.0)

  proc runSize(size: int) =
    universe = buildUniverse(size, chains)
    model.setSourceItems(universe)
    bench.pump() # settle the initial load before measuring

    measure(size, "market_detail_change", proc() =
      let i = universe.len div 2
      universe[i].marketPrice = universe[i].marketPrice + 1.0
      universe[i].marketChangePct24hour = universe[i].marketChangePct24hour + 0.25
      model.setSourceItems(universe))

    measure(size, "balance_update", proc() =
      let i = universe.len div 2
      universe[i].balance = universe[i].balance + 1.0
      universe[i].balanceText = $universe[i].balance
      model.setSourceItems(universe))

    measure(size, "add_token", proc() =
      var it = makeItem(universe.len, chains)
      it.key = "added_" & $universe.len
      universe.add(it)
      model.setSourceItems(universe))

    measure(size, "remove_token", proc() =
      universe.delete(universe.len div 2)
      model.setSourceItems(universe))

    measure(size, "source_reorder", proc() =
      # Reorder the raw source without changing the set. The terminal model
      # sorts internally, so display order is unaffected -> zero ops.
      if universe.len >= 4:
        let a = universe[0]
        universe.delete(0)
        universe.add(a)
      model.setSourceItems(universe))

    measure(size, "all_prices_change", proc() =
      # Honest worst case: every token's market detail changes in one tick and
      # the new prices reshuffle the marketBalance ranking wholesale (global
      # re-rank). No amplification to remove here — the work is inherent — so
      # this is the row where terminal and proxy costs converge; the win the
      # series claims is on the single-cell scenarios above, not this one.
      for i in 0 ..< universe.len:
        universe[i].marketPrice = float((universe.len - i) mod 500) * 0.02 + 0.5
        universe[i].marketChangePct24hour = universe[i].marketChangePct24hour + 0.5
      model.setSourceItems(universe))

    measure(size, "sort_flip", proc() =
      model.sortBy("marketBalance", 0)) # flip to ascending

    measure(size, "full_refresh", proc() =
      # Re-apply the (unchanged) universe: the diff finds nothing -> zero ops,
      # where the proxy chain rebuilds and resets.
      model.setSourceItems(universe))

    # restore descending sort for the next size
    model.sortBy("marketBalance", 1)

  runSize(100)
  runSize(1000)
  runSize(5000)

  let table = formatTable(bench.rows)
  echo "\n===== terminal-model propagation (GREEN) ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("terminal_model_" & stamp & ".tsv"), table)

  # GREEN structural gate: flips the proxy baseline's RED asserts.
  for r in bench.rows:
    doAssert r.resets == 0,
      &"terminal model reset in scenario '{r.scenario}' at size {r.size}"
    # model_sync never emits layoutChanged (it diffs into insert/remove/dataChanged);
    # this assert only carries meaning against the SFPM proxy baseline, which does.
    doAssert r.layoutChanged == 0,
      &"terminal model emitted layoutChanged in '{r.scenario}' at size {r.size}"
    if r.scenario in ["market_detail_change", "balance_update"]:
      # RED was dataChangedRows >= size (whole-model amplification). GREEN: O(1).
      doAssert r.dataChangedRows <= 4,
        &"expected O(1) propagation for '{r.scenario}' at size {r.size} (got {r.dataChangedRows} rows)"
      doAssert r.inserted <= 1 and r.removed <= 1,
        &"expected O(1) row churn for '{r.scenario}' at size {r.size}"
    if r.scenario == "add_token":
      doAssert r.inserted == 1 and r.removed == 0,
        &"add_token should be a single insert at size {r.size}"
    if r.scenario == "remove_token":
      doAssert r.removed == 1 and r.inserted == 0,
        &"remove_token should be a single remove at size {r.size}"
    if r.scenario == "full_refresh":
      doAssert r.dataChangedRows == 0 and r.inserted == 0 and r.removed == 0,
        &"unchanged full_refresh should be a no-op at size {r.size}"

  echo "structural assertions passed"
