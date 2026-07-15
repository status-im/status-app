## Real-instantiation benchmark for the SWAP modal: loads the ACTUAL SwapModal
## QML tree + its real SwapModalAdaptor under an offscreen engine with StatusQ
## linked + the app import paths, and times, per synthetic catalog size
## (100 / 1k / 5k / 10k terminal token-selector rows per picker):
##
##   create           createObject(SwapModal) wall ms + max 16ms-tick stall.
##                    Includes creating the 3 terminal picker models in `d`
##                    (2x kind 1 + 1x kind 3 KIND_SWAP_TO).
##   create_no_swapto same, but the KIND_SWAP_TO (kind 3) picker is suppressed
##                    (scene-level toggle) -> attribution for the eager 3rd
##                    picker on plain swaps.
##   open             create then open() -> time to reach `opened` (or a drained
##                    proxy if the offscreen enter transition can't complete),
##                    wall ms + max stall + frames>32ms.
##   configure        the deferred handler setup() block (form-property writes
##                    run via Qt.callLater after onOpened) execution cost.
##   second_open      close + reopen cost (handler reuse, no rebuild).
##
## Why the size sweep matters here: the SwapModal QML tree itself is
## size-independent (delegates realize lazily), so the only size-dependent term
## in `create` is the per-row seed of the picker models. The bench isolates that
## and the KIND_SWAP_TO share.
##
## OFFSCREEN CAVEAT (see scene header): the terminal picker model is a JS
## ListModel proxy for the real Nim producer; its per-row seed is a faithful
## shape/size proxy, not the Nim producer's exact cost. The QML-tree structural
## cost is real. Absolute host numbers are far below a device's; the ATTRIBUTION
## RANKING (create vs open vs configure vs KIND_SWAP_TO share) is what transfers.
##
## Links StatusQ (registerStatusQTypes) like send_modal_instantiation_bench.

import os, times, strformat
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

{.compile: "bench_statusq_register.cpp".}
proc bench_registerStatusQTypes() {.importc.}

type Row = object
  size: int
  scenario: string
  wallMs: float       # createObject wall time, or open/configure wall time
  openMs: float       # time create->opened (open scenarios only), -1 if n/a
  opened: int         # 1 if the modal reached `opened`, else 0
  models: int         # distinct picker models created (kind1 + kind3)
  kind3: int          # of those, the eager KIND_SWAP_TO (kind 3) picker(s)
  maxStallMs: float
  over32: int
  error: string

QtObject:
  type Bench = ref object of QObject
    ready: bool
    monitoring: bool
    lastTickNs: float
    maxStallMs: float
    over32: int
    # create handshake
    gotCreate: bool
    lastCreateMs: float
    lastKind1: int
    lastKind3: int
    lastError: string
    # open handshake
    modalOpen: bool
    # configure handshake
    gotConfigure: bool
    lastConfigureMs: float

  proc newBench(): Bench =
    new(result)
    result.QObject.setup

  proc requestCreate(self: Bench, size: int, suppress: bool) {.signal.}
  proc requestOpen(self: Bench) {.signal.}
  proc requestClose(self: Bench) {.signal.}
  proc requestConfigure(self: Bench) {.signal.}
  proc requestDestroy(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true

  proc nowMs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0

  proc reportCreate(self: Bench, createMs: float, kind1: int, kind3: int, error: string) {.slot.} =
    self.lastCreateMs = createMs
    self.lastKind1 = kind1
    self.lastKind3 = kind3
    self.lastError = error
    self.gotCreate = true

  proc onModalOpened(self: Bench) {.slot.} = self.modalOpen = true
  proc onModalClosed(self: Bench) {.slot.} = self.modalOpen = false

  proc reportConfigure(self: Bench, ms: float) {.slot.} =
    self.lastConfigureMs = ms
    self.gotConfigure = true

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
  result = "size\tscenario\twall_ms\topen_ms\topened\tmodels\tkind3\tmax_stall_ms\tover32\terror\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.wallMs:.4f}\t{r.openMs:.4f}\t{r.opened}\t{r.models}\t{r.kind3}\t{r.maxStallMs:.4f}\t{r.over32}\t{r.error}\n")

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()
  bench_registerStatusQTypes()

  let bench = newBench()
  let engine = newQQmlApplicationEngine()
  let cwd = getCurrentDir()
  engine.addImportPath(cwd / "ui" / "StatusQ" / "src")
  engine.addImportPath(cwd / "ui" / "imports")
  engine.addImportPath(cwd / "ui" / "app")
  engine.setRootContextProperty("bench", newQVariant(bench))

  let sceneFile = cwd / "test" / "nim" / "benchmarks" / "swap_modal_instantiation_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 500000:
    QCoreApplication.processEvents(); inc spins
  if not bench.ready:
    echo "SKIP: swap-modal instantiation scene did not load"
    quit(0)

  var rows: seq[Row] = @[]
  const sizes = [100, 1000, 5000, 10000]
  const openTimeoutMs = 2500.0

  # A scenario runs create (+optional open/configure/reopen), returning one Row.
  proc runScenario(size: int, scenario: string): Row =
    let suppress = scenario == "create_no_swapto"

    # ---- create ----
    bench.gotCreate = false
    bench.modalOpen = false
    bench.beginMonitor()
    bench.spinFor(32)
    bench.requestCreate(size, suppress)
    var s = 0
    while not bench.gotCreate and s < 500000:
      QCoreApplication.processEvents(); inc s
    bench.spinFor(120)  # let the post-create tick delta register
    bench.endMonitor()

    result = Row(size: size, scenario: scenario, wallMs: bench.lastCreateMs,
      openMs: -1.0, opened: 0, models: bench.lastKind1 + bench.lastKind3,
      kind3: bench.lastKind3,
      maxStallMs: bench.maxStallMs, over32: bench.over32, error: bench.lastError)

    if bench.lastError.len == 0 and scenario in ["open", "configure", "second_open"]:
      # ---- open: measure create->opened (drain to timeout if never opened) ----
      bench.beginMonitor()
      let t0 = bench.nowMs()
      bench.requestOpen()
      while (not bench.modalOpen) and (bench.nowMs() - t0) < openTimeoutMs:
        QCoreApplication.processEvents()
      let openMs = bench.nowMs() - t0
      bench.spinFor(80)
      bench.endMonitor()
      result.openMs = openMs
      result.opened = if bench.modalOpen: 1 else: 0
      result.maxStallMs = bench.maxStallMs
      result.over32 = bench.over32

      if scenario == "configure":
        bench.gotConfigure = false
        bench.requestConfigure()
        var c = 0
        while not bench.gotConfigure and c < 500000:
          QCoreApplication.processEvents(); inc c
        result.wallMs = bench.lastConfigureMs   # report the configure block time

      if scenario == "second_open":
        bench.requestClose()
        bench.spinFor(120)
        bench.beginMonitor()
        let t1 = bench.nowMs()
        bench.requestOpen()
        while (not bench.modalOpen) and (bench.nowMs() - t1) < openTimeoutMs:
          QCoreApplication.processEvents()
        result.openMs = bench.nowMs() - t1
        result.opened = if bench.modalOpen: 1 else: 0
        bench.spinFor(80)
        bench.endMonitor()
        result.maxStallMs = bench.maxStallMs
        result.over32 = bench.over32

    bench.requestDestroy()
    bench.spinFor(60)

  for size in sizes:
    for scenario in ["create", "create_no_swapto", "open", "configure", "second_open"]:
      # Warm the QML caches once at the first (size, scenario), then measure.
      if size == sizes[0] and scenario == "create":
        discard runScenario(size, scenario)
      let r = runScenario(size, scenario)
      rows.add(r)
      stderr.writeLine(&"[bench] size={size} {scenario} wall={r.wallMs:.2f}ms open={r.openMs:.2f}ms opened={r.opened} models={r.models} kind3={r.kind3} maxStall={r.maxStallMs:.2f}ms over32={r.over32} err={r.error}")
      stderr.flushFile()

  let table = formatTable(rows)
  echo "\n===== SwapModal real instantiation cost (host, offscreen) ====="
  echo table

  let resultsDir = cwd / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("swap_modal_instantiation_" & stamp & ".tsv"), table)

  proc rowFor(size: int, scenario: string): Row =
    for r in rows:
      if r.size == size and r.scenario == scenario: return r
    doAssert false, &"missing row {scenario} @{size}"

  # The full modal must actually instantiate (the whole point of this bench).
  let full = rowFor(10000, "create")
  doAssert full.error.len == 0,
    &"SwapModal failed to instantiate offscreen: {full.error}"
  doAssert full.wallMs > 0.0,
    &"SwapModal createMs was not measured: {full.wallMs}"
  # The full create must make all 3 pickers (2 kind1 + 1 kind3); suppressing
  # kind 3 makes 2 (0 kind3). This is the KIND_SWAP_TO attribution.
  doAssert full.models == 3 and full.kind3 == 1,
    &"expected 3 pickers incl 1 kind3, got models={full.models} kind3={full.kind3}"
  let noSwapTo = rowFor(10000, "create_no_swapto")
  doAssert noSwapTo.models == 2 and noSwapTo.kind3 == 0,
    &"expected 2 pickers with swapto suppressed, got models={noSwapTo.models} kind3={noSwapTo.kind3}"

  echo "assertions passed"
  stdout.flushFile()
  stderr.flushFile()
  # SwapModal instantiates QQuickTextField context menus (QQuickMenu/QQuickAction)
  # whose static teardown at QApplication destruction SIGSEGVs offscreen. The
  # measurement + TSV are already done, so hard-exit via _exit(2) BYPASSING C++
  # static destructors (Nim's `quit`/`exit` would run them and crash). Using
  # _exit avoids that unrelated shutdown-ordering bug.
  proc c_exit(code: cint) {.importc: "_exit", header: "<unistd.h>".}
  c_exit(0)
