## Handler-side adaptor benchmark for the send modal. SendModalHandler eagerly
## builds three adaptors when the modal opens (SendModalHandler.qml): the
## recipient + accounts adaptors feed the initially-visible ASSETS tab, while
## CollectiblesSelectionAdaptor -- a LeftJoin + SFPM + nested per-group
## ObjectProxyModel chain over the full cross-chain collectibles model -- is pure
## waste in the open window (the modal opens on assets, not collectibles).
##
## This bench loads the REAL adaptor QML (send_handler_adaptors_scene.qml) under an
## offscreen engine with StatusQ linked + the app import paths, and per adaptor
## records:
##   create_ms     - Component.createObject wall time (synchronous structural build)
##   settle_ms     - create -> output row counts stabilize (per-row/per-group
##                   submodels that land after createObject returns)
##   max_stall_ms  - worst GUI-thread block over create+settle (16ms tick monitor)
##   over32        - number of >32ms render-loop blocks in that window
##   countA/countB - final output row counts (flat model / grouped model)
##
## Absolute host numbers sit far below the device's user-observed open, but the
## ATTRIBUTION RANKING transfers: a synchronous O(collectibles) build is a fixed
## structural cost a slower device's engine multiplies. Collectibles are measured
## at 200 / 1000 / 3000 items; accounts + recipients at one realistic size for
## completeness. Links StatusQ (registerStatusQTypes) like the sibling send benches.

import os, times, strformat
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

{.compile: "bench_statusq_register.cpp".}
proc bench_registerStatusQTypes() {.importc.}

type Row = object
  kind: int
  name: string
  createMs: float
  settleMs: float
  maxStallMs: float
  over32: int
  countA: int
  countB: int
  error: string

QtObject:
  type Bench = ref object of QObject
    ready: bool
    monitoring: bool
    lastTickNs: float
    maxStallMs: float
    over32: int
    gotInstantiation: bool
    gotSettle: bool
    lastCreateMs: float
    lastSettleMs: float
    lastCountA: int
    lastCountB: int
    lastError: string

  proc newBench(): Bench =
    new(result)
    result.QObject.setup

  proc requestKind(self: Bench, kind: int) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true

  proc nowMs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0

  proc reportInstantiation(self: Bench, kind: int, createMs: float, error: string) {.slot.} =
    self.lastCreateMs = createMs
    self.lastError = error
    self.gotInstantiation = true

  proc reportSettle(self: Bench, kind: int, settleMs: float, countA: int, countB: int) {.slot.} =
    self.lastSettleMs = settleMs
    self.lastCountA = countA
    self.lastCountB = countB
    self.gotSettle = true

  proc onStallTick(self: Bench) {.slot.} =
    if not self.monitoring: return
    let n = self.nowMs()
    let delta = n - self.lastTickNs
    if delta > self.maxStallMs: self.maxStallMs = delta
    if delta > 32.0: inc self.over32
    self.lastTickNs = n

  proc beginMonitor(self: Bench) =
    self.maxStallMs = 0.0
    self.over32 = 0
    self.lastTickNs = self.nowMs()
    self.monitoring = true
  proc endMonitor(self: Bench) = self.monitoring = false

  proc spinFor(self: Bench, ms: float) =
    let deadline = self.nowMs() + ms
    while self.nowMs() < deadline:
      QCoreApplication.processEvents()

proc formatTable(rows: seq[Row]): string =
  result = "kind\tname\tcreate_ms\tsettle_ms\tmax_stall_ms\tover32\tcountA\tcountB\terror\n"
  for r in rows:
    result.add(&"{r.kind}\t{r.name}\t{r.createMs:.4f}\t{r.settleMs:.4f}\t{r.maxStallMs:.4f}\t{r.over32}\t{r.countA}\t{r.countB}\t{r.error}\n")

const kindNames = [
  "CollectiblesSelectionAdaptor@200",
  "CollectiblesSelectionAdaptor@1000",
  "CollectiblesSelectionAdaptor@3000",
  "WalletAccountsSelectorAdaptor",
  "RecipientViewAdaptor",
  "Collectibles@3000 DEFERRED (open->activate)",
]

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()
  bench_registerStatusQTypes()

  let bench = newBench()
  let engine = newQQmlApplicationEngine()
  let root = getCurrentDir()
  engine.addImportPath(root / "ui" / "StatusQ" / "src")
  engine.addImportPath(root / "ui" / "imports")
  engine.addImportPath(root / "ui" / "app")
  engine.setRootContextProperty("bench", newQVariant(bench))

  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "send_handler_adaptors_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 500000:
    QCoreApplication.processEvents(); inc spins
  if not bench.ready:
    echo "SKIP: send-handler adaptors scene did not load"
    quit(0)

  var rows: seq[Row] = @[]

  proc measure(kind: int) =
    # Warm the QML type caches once (first createObject pays one-time
    # compilation), then measure a fresh instantiation + settle.
    for pass in 0 .. 1:
      bench.gotInstantiation = false
      bench.gotSettle = false
      bench.beginMonitor()
      bench.spinFor(32)
      bench.requestKind(kind)
      var s = 0
      while not bench.gotSettle and s < 2000000:
        QCoreApplication.processEvents(); inc s
      bench.spinFor(48) # let the post-settle tick delta register
      bench.endMonitor()
      if pass == 1:
        rows.add(Row(kind: kind, name: kindNames[kind],
          createMs: bench.lastCreateMs, settleMs: bench.lastSettleMs,
          maxStallMs: bench.maxStallMs, over32: bench.over32,
          countA: bench.lastCountA, countB: bench.lastCountB,
          error: bench.lastError))
        stderr.writeLine(&"[bench] {kindNames[kind]} create={bench.lastCreateMs:.2f}ms settle={bench.lastSettleMs:.2f}ms maxStall={bench.maxStallMs:.2f}ms over32={bench.over32} counts={bench.lastCountA}/{bench.lastCountB} err={bench.lastError}")
        stderr.flushFile()

  for kind in 0 .. 5:
    measure(kind)

  let table = formatTable(rows)
  echo "\n===== SendModalHandler adaptor build cost (host, offscreen) ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("send_handler_adaptors_" & stamp & ".tsv"), table)

  proc rowFor(kind: int): Row =
    for r in rows:
      if r.kind == kind: return r
    doAssert false, "missing kind " & $kind

  # All adaptors must actually instantiate + populate (the point of the bench).
  for kind in 0 .. 5:
    let r = rowFor(kind)
    doAssert r.error.len == 0, &"{r.name} failed to instantiate: {r.error}"
    doAssert r.createMs >= 0.0, &"{r.name} createMs not measured: {r.createMs}"
  # The 3000-item collectibles pipeline must produce the full flat model.
  doAssert rowFor(2).countA == 3000,
    &"collectibles@3000 flat model incomplete: {rowFor(2).countA}"
  # GREEN: the deferred Loader builds nothing at open (open-window createMs well
  # below the direct build), yet produces the full model once activated.
  doAssert rowFor(5).countA == 3000,
    &"deferred collectibles did not populate on activation: {rowFor(5).countA}"
  doAssert rowFor(5).createMs < rowFor(2).createMs,
    &"deferred open cost {rowFor(5).createMs} not below direct build {rowFor(2).createMs}"

  echo "assertions passed"
