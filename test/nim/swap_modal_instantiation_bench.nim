## Real-instantiation benchmark for the SWAP modal: loads the ACTUAL SwapModal
## QML tree + its real SwapModalAdaptor under an offscreen engine with StatusQ
## linked + the app import paths, and times, per synthetic catalog size
## (100 / 1k / 5k / 10k terminal token-selector rows per picker):
##
##   create                 createObject(SwapModal) wall ms + max 16ms-tick stall.
##                          The picker models are NO LONGER built here: SwapModal
##                          defers createPickers to just after onOpened, so this
##                          is the picker-free structural tree cost (models=0).
##   time_to_pickers_ready  create then open()->opened (unmonitored), then measure
##                          ONLY the deferred picker build+seed stall — the cost
##                          that used to sit inside `create`. A plain same-chain
##                          swap builds the 2 source-chain pickers, no kind-3.
##   open                   create then open() -> time to reach `opened`; monitor
##                          ENDS at `opened`, before the deferred seed, so open
##                          stays clean. wall ms + max stall + frames>32ms.
##   configure              the deferred handler setup() block (form-property writes
##                          run via Qt.callLater after onOpened) execution cost.
##   second_open            close + reopen cost (handler + pickers reused, no rebuild).
##
## Why the size sweep matters here: the SwapModal QML tree itself is
## size-independent (delegates realize lazily), so the only size-dependent term is
## the per-row seed of the picker models. This bench isolates it and shows the
## deferral moves it OUT of `create` (create flat, cost lands in
## time_to_pickers_ready).
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
import std/strutils

# Optional QML profiling: build with `-d:qmldebug` (port via -d:qmlDebugPort:NNNNN)
# to start the TCP debug/profiler server and BLOCK until `qmlprofiler --attach`
# connects, so a trace of the create window can be captured. Mirrors the desktop
# app's enabler in nim_status_client.nim. Test-only; off by default.
when defined(qmldebug):
  # `from ... import nil` keeps every symbol qualified so its transitive QVariant
  # doesn't clash with nimqml.QVariant in the QtObject macro below.
  from seaqt/qqmldebuggingenabler import nil

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
    # deferred picker-build handshake: the scene bumps these each time SwapModal's
    # post-open createPickers actually builds a picker model (kind 1 = the two
    # source-chain pickers, kind 3 = the bridge destination picker).
    builtKind1: int
    builtKind3: int

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

  proc onPickerBuilt(self: Bench, kind: int) {.slot.} =
    if kind == 3: inc self.builtKind3 else: inc self.builtKind1

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

  when defined(qmldebug):
    const qmlDebugPort {.intdefine: "qmlDebugPort".} = 49155
    # WaitForClient: block here until qmlprofiler attaches, so the create window
    # is inside the recorded window. Must run before the QML engine is created.
    # mode 1 = WaitForClient (block until qmlprofiler attaches)
    discard qqmldebuggingenabler.startTcpDebugServer(
      qqmldebuggingenabler.QQmlDebuggingEnabler, qmlDebugPort.cint, 1.cint)
    stderr.writeLine("[bench] qml debug/profiler server waiting on port " & $qmlDebugPort)
    stderr.flushFile()

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
  # Default sweep; override with SWAP_BENCH_SIZES=10000 (comma-separated) to pin a
  # single size for a profiled run. Not a committed hardcode — env-driven.
  var sizes = @[100, 1000, 5000, 10000]
  let sizesEnv = getEnv("SWAP_BENCH_SIZES", "")
  if sizesEnv.len > 0:
    sizes = @[]
    for s in sizesEnv.split(','):
      let entry = s.strip()
      if entry.len == 0: continue
      try:
        sizes.add(parseInt(entry))
      except ValueError:
        echo &"ERROR: SWAP_BENCH_SIZES entry is not an integer: '{entry}'"
        quit(1)
    if sizes.len == 0:
      echo "ERROR: SWAP_BENCH_SIZES is set but contains no size"
      quit(1)
  const openTimeoutMs = 2500.0

  # Opens the modal and waits for `opened` (or drains to timeout), returning the
  # elapsed ms. The 16ms-tick monitor must be running around this call.
  proc openAndWait(): float =
    let t0 = bench.nowMs()
    bench.requestOpen()
    while (not bench.modalOpen) and (bench.nowMs() - t0) < openTimeoutMs:
      QCoreApplication.processEvents()
    return bench.nowMs() - t0

  # A scenario runs create (+optional open/configure/reopen), returning one Row.
  proc runScenario(size: int, scenario: string): Row =
    # ---- create ----
    # The pickers are no longer built here (SwapModal defers createPickers to just
    # after onOpened), so `create` now measures the picker-free structural tree
    # cost only; models=0. The moved seed cost is measured by the
    # `time_to_pickers_ready` scenario below.
    bench.gotCreate = false
    bench.modalOpen = false
    bench.beginMonitor()
    bench.spinFor(32)
    bench.requestCreate(size, false)
    var s = 0
    while not bench.gotCreate and s < 500000:
      QCoreApplication.processEvents(); inc s
    bench.spinFor(120)  # let the post-create tick delta register
    bench.endMonitor()

    result = Row(size: size, scenario: scenario, wallMs: bench.lastCreateMs,
      openMs: -1.0, opened: 0, models: bench.lastKind1 + bench.lastKind3,
      kind3: bench.lastKind3,
      maxStallMs: bench.maxStallMs, over32: bench.over32, error: bench.lastError)

    if bench.lastError.len == 0 and
        scenario in ["time_to_pickers_ready", "open", "configure", "second_open"]:

      if scenario == "time_to_pickers_ready":
        # Reach `opened` UNMONITORED, then monitor only the deferred picker
        # build+seed (the cost that used to live in `create`). Success = the two
        # source-chain pickers built; a plain same-chain swap builds no kind-3.
        bench.builtKind1 = 0
        bench.builtKind3 = 0
        result.openMs = openAndWait()
        result.opened = if bench.modalOpen: 1 else: 0
        bench.beginMonitor()
        let tp = bench.nowMs()
        while bench.builtKind1 < 2 and (bench.nowMs() - tp) < openTimeoutMs:
          QCoreApplication.processEvents()
        bench.spinFor(80)  # let the seed's post-build tick delta register
        bench.endMonitor()
        result.models = bench.builtKind1 + bench.builtKind3
        result.kind3 = bench.builtKind3
        result.maxStallMs = bench.maxStallMs
        result.over32 = bench.over32
      else:
        # ---- open: measure create->opened only. endMonitor AT `opened`, before
        # the deferred createPickers seed runs, so the seed does not pollute the
        # open stall (its cost is the `time_to_pickers_ready` scenario). ----
        bench.beginMonitor()
        result.openMs = openAndWait()
        bench.endMonitor()
        result.opened = if bench.modalOpen: 1 else: 0
        result.maxStallMs = bench.maxStallMs
        result.over32 = bench.over32
        bench.spinFor(120)  # unmonitored: let the deferred pickers build before next step

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
        result.openMs = openAndWait()
        bench.endMonitor()
        result.opened = if bench.modalOpen: 1 else: 0
        bench.spinFor(80)
        result.maxStallMs = bench.maxStallMs
        result.over32 = bench.over32

    bench.requestDestroy()
    bench.spinFor(150)  # let the (possibly opened) modal fully destroy before the
                        # next scenario's monitored create window, so a lingering
                        # modal can't seed a picker into it

  for size in sizes:
    for scenario in ["create", "time_to_pickers_ready", "open", "configure", "second_open"]:
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

  # Assert on the largest size actually swept (the sweep is env-overridable).
  let biggest = sizes[^1]

  # The full modal must actually instantiate (the whole point of this bench).
  let full = rowFor(biggest, "create")
  doAssert full.error.len == 0,
    &"SwapModal failed to instantiate offscreen: {full.error}"
  doAssert full.wallMs > 0.0,
    &"SwapModal createMs was not measured: {full.wallMs}"
  # createObject no longer builds any picker: they are deferred to post-open
  # createPickers. This is the whole point of the optimization.
  doAssert full.models == 0,
    &"expected 0 pickers built during create (deferred), got models={full.models}"
  # A plain (same-chain) swap open builds exactly the two source-chain pickers and
  # NO bridge (kind 3) picker — the eager 3rd picker on plain swaps is gone.
  let ready = rowFor(biggest, "time_to_pickers_ready")
  doAssert ready.models == 2 and ready.kind3 == 0,
    &"expected 2 pickers built post-open incl 0 kind3, got models={ready.models} kind3={ready.kind3}"

  echo "assertions passed"
  stdout.flushFile()
  stderr.flushFile()
  # SwapModal instantiates QQuickTextField context menus (QQuickMenu/QQuickAction)
  # whose static teardown at QApplication destruction SIGSEGVs offscreen. The
  # measurement + TSV are already done, so hard-exit via _exit(2) BYPASSING C++
  # static destructors (Nim's `quit`/`exit` would run them and crash). Using
  # _exit avoids that unrelated shutdown-ordering bug.
  proc c_exit(code: cint) {.importc: "_exit", header: "<unistd.h>".}
  when defined(qmldebug):
    # Under profiling, hold the app + debug connection open so qmlprofiler can
    # flush a CLEAN trace: an immediate _exit drops the TCP socket mid-stream and
    # the profiler reports "connection dropped ... damaged". Spin processing events
    # (keeps the debug thread serviced); the harness stops the profiler + kills us.
    stderr.writeLine("[bench] measurement done; holding open 300s for qmlprofiler flush")
    stderr.flushFile()
    bench.spinFor(300000.0)
  c_exit(0)
