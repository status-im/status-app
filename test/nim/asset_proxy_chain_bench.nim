## Proxy-chain propagation benchmark (RED baseline).
##
## Boots an offscreen QQmlApplicationEngine, registers the real StatusQ / SFPM /
## QtModelsToolkit types, and loads asset_proxy_chain_scene.qml — which stands up
## the full WalletAssetsStore graph: two chained LeftJoinModels (tokenGroups ⋈
## communities, then grouped-assets ⋈ that) feeding AssetsView's terminal chain
## (a visible-filter SortFilterProxyModel plus the terminal SortFilterProxyModel
## carrying AssetsView's 3 FastExpressionRoles + 2 RoleSorters with
## dynamicSortFilter), driving a ListView with a counting delegate.
##
## For each token-universe size (100 / 1k / 5k, multi-chain) and update class
## (single market-detail change, single balance update, add token, remove token,
## source reorder, sort flip, full refresh) the scene records: wall time,
## terminal-model signal counts (dataChanged / summed dataChanged row-span /
## layoutChanged / modelReset / rowsInserted / rowsRemoved) and delegate
## create/destroy counts. Results print as a machine-readable table and are saved
## (gitignored) under test/nim/benchmarks/results/.
##
## The join layers are real (not pre-joined): a right-model cell change makes
## LeftJoinModel emit a WHOLE-model dataChanged (leftjoinmodel.cpp:285), so the
## market-detail / balance edits — driven through the right-joined tokenGroups
## model — reproduce the ×N amplification the terminal model removes.
##
## Faithful reduction (stated for honesty):
##   - ManageTokensController's ObjectProxyModel + settings persistence is the
##     visible-filter SortFilterProxyModel (same propagation depth, no Global
##     singletons / settings I/O offscreen).
##
## The committed structural assertions gate the invariants that hold today,
## including the RED baseline that market-detail / balance edits amplify into a
## whole-model dataChanged; the terminal model flips those.

import os, times, strformat
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

{.compile: "bench_statusq_register.cpp".}
proc bench_registerStatusQTypes() {.importc.}

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
    finished: bool

  proc delete(self: Bench)

  proc newBench(): Bench =
    new(result, delete)
    result.QObject.setup

  proc delete(self: Bench) =
    self.QObject.delete

  proc nowNs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float

  proc record(self: Bench, size: int, scenario: string, wallMs: float,
      dataChanged: int, dataChangedRows: int, layoutChanged: int, resets: int,
      inserted: int, removed: int,
      delegatesCreated: int, delegatesDestroyed: int) {.slot.} =
    self.rows.add(Row(size: size, scenario: scenario, wallMs: wallMs,
      dataChanged: dataChanged, dataChangedRows: dataChangedRows,
      layoutChanged: layoutChanged, resets: resets,
      inserted: inserted, removed: removed,
      delegatesCreated: delegatesCreated, delegatesDestroyed: delegatesDestroyed))
    stderr.writeLine(&"[bench] size={size} {scenario} {wallMs:.2f}ms dataChangedRows={dataChangedRows}")
    stderr.flushFile()

  proc pump(self: Bench) {.slot.} =
    ## Flush queued work (SFPM deferred invalidation, ListView delegate
    ## realization) so a synchronous measurement observes the settled state.
    for _ in 0 ..< 8:
      QCoreApplication.processEvents()

  proc done(self: Bench) {.slot.} =
    self.finished = true

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\twall_ms\tdataChanged\tdataChangedRows\tlayoutChanged\tresets\tinserted\tremoved\tdelegatesCreated\tdelegatesDestroyed\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.wallMs:.4f}\t{r.dataChanged}\t{r.dataChangedRows}\t{r.layoutChanged}\t{r.resets}\t{r.inserted}\t{r.removed}\t{r.delegatesCreated}\t{r.delegatesDestroyed}\n")

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")

  let app = newQApplication()
  bench_registerStatusQTypes()

  let bench = newBench()
  let benchVariant = newQVariant(bench)

  let engine = newQQmlApplicationEngine()
  engine.addImportPath(getCurrentDir() / "ui" / "StatusQ" / "src")
  engine.setRootContextProperty("bench", benchVariant)

  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "asset_proxy_chain_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.finished and spins < 100000:
    QCoreApplication.processEvents()
    inc spins

  if bench.rows.len == 0:
    # The StatusQ / SFPM QML modules could not be resolved in this environment
    # (needs a `make statusq` install tree on the import path). Skip rather than
    # fail the unit-test sweep; the baseline is produced on the macOS host.
    echo "SKIP: proxy-chain scene did not load (StatusQ QML modules unavailable)"
    quit(0)

  let table = formatTable(bench.rows)
  echo "\n===== proxy-chain propagation baseline ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  let outFile = resultsDir / ("proxy_chain_baseline_" & stamp & ".tsv")
  writeFile(outFile, table)
  echo "saved: ", outFile

  # Structural gate. Invariants that hold TODAY:
  #   - no scenario except full_refresh resets the terminal model (rows survive);
  #   - a stable-set single-cell change (market detail / balance) adds/removes no
  #     rows.
  # RED baseline (the terminal model flips these): a single-cell
  # market-detail / balance edit fans out through the outer LeftJoinModel into a
  # WHOLE-model dataChanged — the terminal re-touches ~every row, so the summed
  # dataChanged row-span is on the order of the universe size, not O(1).
  for r in bench.rows:
    if r.scenario != "full_refresh":
      doAssert r.resets == 0,
        &"unexpected model reset in scenario '{r.scenario}' at size {r.size}"
    if r.scenario in ["market_detail_change", "balance_update"]:
      doAssert r.inserted == 0 and r.removed == 0,
        &"stable-set scenario '{r.scenario}' changed the row set at size {r.size}"
      # RED: whole-model amplification (to be flipped green by the terminal model).
      doAssert r.dataChangedRows >= r.size,
        &"expected whole-model dataChanged amplification for '{r.scenario}' at size {r.size} (got {r.dataChangedRows} rows)"

  echo "structural assertions passed"
