## RED baseline for the send modal's collectibles picker.
##
## The picker renders off CollectiblesSelectionAdaptor (ui/app/AppLayouts/Wallet/
## adaptors/CollectiblesSelectionAdaptor.qml): a LeftJoin(networks) feeding an
## ObjectProxyModel that builds THREE QObjects PER GLOBAL ROW (a delegate + a
## per-row ownership SortFilterProxyModel + a SumAggregator), then a RangeFilter
## (balance>=1) + sort + GroupingModel + a second ObjectProxyModel with nested
## per-community GroupingModels. Its cost is O(GLOBAL collectibles universe) even
## though the user owns ~30 per account.
##
## This bench loads the REAL adaptor (collectibles_selector_scene.qml) under an
## offscreen engine with StatusQ linked, drives its `model` + `filteredFlatModel`
## through two REAL ListViews, and measures the update classes the modal pays:
##   build                - first fill of the GLOBAL universe (initial structural build)
##   account_switch        - flip the probed account (re-filters O(GLOBAL) rows)
##   chain_filter          - toggle enabledChainIds
##   append_50             - paging churn: append 50 rows
##   balance_update        - one ERC-1155 ownership balance bump on a shown row
## For each: wall ms, worst 16ms-tick GUI stall, model resets/inserts/dataChanged
## rows (grouped + flat), and delegate create/destroy churn.
##
## RED expectation (documented, not asserted as a target): build + account_switch
## scale with the GLOBAL size, not the ~30 the account owns; a single balance
## update fans a whole-model reset/dataChanged through the proxy chain and churns
## delegates. The GREEN Nim terminal model (collectibles_selector_model_bench.nim)
## flips these to O(displayed) with zero resets.
##
## Absolute host numbers sit below the device open, but the ATTRIBUTION RANKING
## (a synchronous O(universe) build) transfers. Links StatusQ like the sibling
## send benches.

import os, times, strformat
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes
import benchmarks/perf_gate

{.compile: "bench_statusq_register.cpp".}
proc bench_registerStatusQTypes() {.importc.}

type Row = object
  size: int
  scenario: string
  wallMs: float
  maxStallMs: float
  # grouped model / flat model granular signal tallies
  resetsG, resetsF: int
  insertsG, insertsF: int
  dcRowsG, dcRowsF: int
  # ListView delegate churn (0 = grouped, 1 = flat)
  delCreatedG, delDestroyedG: int
  delCreatedF, delDestroyedF: int
  countFlat, countGrouped: int
  error: string

QtObject:
  type Bench = ref object of QObject
    ready: bool
    monitoring: bool
    lastTickNs: float
    maxStallMs: float
    # per-model (0 grouped, 1 flat) tallies for the current window
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

  proc requestScenario(self: Bench, kind: int, arg: int) {.signal.}
  proc requestRelayout(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true

  proc nowMs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0

  proc onDataChanged(self: Bench, which: int, top: int, bottom: int) {.slot.} =
    if not self.monitoring: return
    self.dcRows[which] += (bottom - top + 1)
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

  proc spinFor(self: Bench, ms: float) =
    let deadline = self.nowMs() + ms
    while self.nowMs() < deadline:
      QCoreApplication.processEvents()

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\twall_ms\tmax_stall_ms\tresetsG\tresetsF\tinsG\tinsF\tdcRowsG\tdcRowsF\tdelCreG\tdelDelG\tdelCreF\tdelDelF\tcountFlat\tcountGrouped\terror\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.wallMs:.4f}\t{r.maxStallMs:.4f}\t{r.resetsG}\t{r.resetsF}\t{r.insertsG}\t{r.insertsF}\t{r.dcRowsG}\t{r.dcRowsF}\t{r.delCreatedG}\t{r.delDestroyedG}\t{r.delCreatedF}\t{r.delDestroyedF}\t{r.countFlat}\t{r.countGrouped}\t{r.error}\n")

const scenarioNames = ["build", "account_switch", "chain_filter", "append_50", "balance_update"]
let sizes = benchSizes([200, 1000, 3000], [3000])

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()
  bench_registerStatusQTypes()

  let bench = newBench()
  let engine = newQQmlApplicationEngine()
  let base = getCurrentDir()
  engine.addImportPath(base / "ui" / "StatusQ" / "src")
  engine.addImportPath(base / "ui" / "imports")
  engine.addImportPath(base / "ui" / "app")
  engine.setRootContextProperty("bench", newQVariant(bench))

  let sceneFile = base / "test" / "nim" / "benchmarks" / "collectibles_selector_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 500000:
    QCoreApplication.processEvents(); inc spins
  if not bench.ready:
    echo "SKIP: collectibles selector scene did not load"
    quit(0)

  var rows: seq[Row] = @[]

  # Drive one scenario: begin monitor, fire it, pump until the model row counts
  # stabilize (the proxy chain lands per-row/per-group submodels after the call
  # returns), force a layout so delegate churn is realized, record the window.
  proc runScenario(size, kind, arg: int): Row =
    bench.beginMonitor()
    bench.spinFor(24)
    let start = bench.nowMs()
    bench.requestScenario(kind, arg)
    # Settle: the proxy chain lands per-row/per-group submodels after the mutation
    # returns. Pump + relayout until the accumulated signal/delegate activity stops
    # changing for a stretch (quiescence), capped at 6s.
    var lastActivity = -1
    var stable = 0
    while stable < 12 and (bench.nowMs() - start) < 6000:
      QCoreApplication.processEvents()
      bench.requestRelayout()
      QCoreApplication.processEvents()
      let activity = bench.dcRows[0] + bench.dcRows[1] + bench.inserts[0] +
        bench.inserts[1] + bench.removes[0] + bench.removes[1] +
        bench.delCreated[0] + bench.delCreated[1]
      if activity == lastActivity: inc stable
      else: (lastActivity = activity; stable = 0)
    bench.spinFor(48)
    bench.requestRelayout()
    bench.spinFor(24)
    bench.endMonitor()
    result = Row(size: size, scenario: scenarioNames[kind],
      wallMs: bench.nowMs() - start, maxStallMs: bench.maxStallMs,
      resetsG: bench.resets[0], resetsF: bench.resets[1],
      insertsG: bench.inserts[0], insertsF: bench.inserts[1],
      dcRowsG: bench.dcRows[0], dcRowsF: bench.dcRows[1],
      delCreatedG: bench.delCreated[0], delDestroyedG: bench.delDestroyed[0],
      delCreatedF: bench.delCreated[1], delDestroyedF: bench.delDestroyed[1],
      countFlat: bench.lastCountFlat, countGrouped: bench.lastCountGrouped)

  for size in sizes:
    # build first (fills the source with `size` rows on the fresh adaptor)
    var r = runScenario(size, 0, size)
    rows.add(r)
    stderr.writeLine(&"[bench] size={size} build wall={r.wallMs:.1f}ms stall={r.maxStallMs:.1f} resetsF={r.resetsF} dcRowsF={r.dcRowsF} delCreF={r.delCreatedF}")
    for kind in 1 .. 4:
      r = runScenario(size, kind, 0)
      rows.add(r)
      stderr.writeLine(&"[bench] size={size} {scenarioNames[kind]} wall={r.wallMs:.1f}ms stall={r.maxStallMs:.1f} resetsF={r.resetsF} dcRowsF={r.dcRowsF} delCreF={r.delCreatedF} delDelF={r.delDestroyedF}")
    stderr.flushFile()

  let table = formatTable(rows)
  echo "\n===== CollectiblesSelectionAdaptor proxy-chain cost (host, offscreen, RED) ====="
  echo table

  let resultsDir = base / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("collectibles_selector_red_" & stamp & ".tsv"), table)

  # The bench must actually exercise the chain: the build at the largest size must
  # have created flat delegates and the scenarios must have run without error.
  proc rowFor(size: int, scenario: string): Row =
    for r in rows:
      if r.size == size and r.scenario == scenario: return r
    doAssert false, &"missing {scenario}@{size}"
  let build3k = rowFor(3000, "build")
  doAssert build3k.delCreatedF > 0, "no flat delegates realized on build"
  echo "RED bench ran"
