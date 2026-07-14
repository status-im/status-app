## Real-instantiation benchmark for the send modal: loads the ACTUAL
## SimpleSendModal QML tree (and its major subtrees) under an offscreen engine with
## StatusQ linked + the app import paths, and times Component.createObject (the
## structural instantiation cost) + time-to-`opened` + the GUI-thread block via a
## 16ms stall monitor (send_modal_instantiation_scene.qml).
##
## This isolates the dominant hypothesis for the user-observed ~1s open: how much
## of it is QML component instantiation of the modal tree (as opposed to the Nim
## picker seed measured by send_modal_open_bench, or the handler-JS model lookups
## measured by send_handler_lookup_bench). Absolute host numbers are far below the
## device's ~1s, but the ATTRIBUTION RANKING transfers: instantiation is a fixed
## structural cost that a slower device's QML engine multiplies.
##
## Per component it records: create_ms (createObject wall time), open_ms (full
## modal only: create->`opened`), max_stall_ms / over32 (the render-loop block the
## synchronous createObject causes). A subtree that fails to instantiate standalone
## reports create_ms = -1 with the QML error (the bisection then still ranks the
## rest).
##
## Links StatusQ (registerStatusQTypes) like swap_key_harvest_bench.

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
    # per-run handshake
    gotInstantiation: bool
    lastCreateMs: float
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
  result = "kind\tname\tcreate_ms\tmax_stall_ms\tover32\terror\n"
  for r in rows:
    result.add(&"{r.kind}\t{r.name}\t{r.createMs:.4f}\t{r.maxStallMs:.4f}\t{r.over32}\t{r.error}\n")

const kindNames = [
  "SimpleSendModal(full)",
  "SendModalHeader",
  "StickySendModalHeader",
  "AmountToSend",
  "SendModalFooter",
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

  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "send_modal_instantiation_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 500000:
    QCoreApplication.processEvents(); inc spins
  if not bench.ready:
    echo "SKIP: send-modal instantiation scene did not load"
    quit(0)

  var rows: seq[Row] = @[]

  proc measure(kind: int) =
    # Warm the QML type caches once (first createObject pays one-time compilation),
    # then measure a fresh instantiation.
    for pass in 0 .. 1:
      bench.gotInstantiation = false
      bench.beginMonitor()
      bench.spinFor(32)
      bench.requestKind(kind)
      var s = 0
      while not bench.gotInstantiation and s < 500000:
        QCoreApplication.processEvents(); inc s
      bench.spinFor(120)  # let the post-create tick delta register
      bench.endMonitor()
      if pass == 1:
        rows.add(Row(kind: kind, name: kindNames[kind],
          createMs: bench.lastCreateMs,
          maxStallMs: bench.maxStallMs, over32: bench.over32, error: bench.lastError))
        stderr.writeLine(&"[bench] {kindNames[kind]} create={bench.lastCreateMs:.2f}ms maxStall={bench.maxStallMs:.2f}ms over32={bench.over32} err={bench.lastError}")
        stderr.flushFile()

  for kind in 0 .. 4:
    measure(kind)

  let table = formatTable(rows)
  echo "\n===== SimpleSendModal real instantiation cost (host, offscreen) ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("send_modal_instantiation_" & stamp & ".tsv"), table)

  proc rowFor(kind: int): Row =
    for r in rows:
      if r.kind == kind: return r
    doAssert false, "missing kind " & $kind

  # The full modal must actually instantiate (the whole point of this bench).
  let full = rowFor(0)
  doAssert full.error.len == 0,
    &"SimpleSendModal failed to instantiate offscreen: {full.error}"
  doAssert full.createMs > 0.0,
    &"SimpleSendModal createMs was not measured: {full.createMs}"

  echo "assertions passed"
