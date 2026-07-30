## Request-side harvest benchmark (companion to swap_modal_open_bench).
##
## SwapModal.rebuildGroupsForChain runs twice per open + on every in-modal network
## switch, each time calling
##   SQUtils.ModelUtils.joinModelEntries(groupedAccountAssetsModel, "key", "$$")
## to build the mandatory-keys string. groupedAccountAssetsModel has two roles:
## "key" and "balances" (a per-row submodel). The old modelToArray fetched EVERY
## role per row via QtMT.ModelQuery.get(model, i) and marshalled the whole map
## (incl. the balances submodel QObject) to JS, then read only "key" -> the
## user-profiled ~250ms `modelToArray` stall.
##
## This bench builds a synthetic owned model of the same shape (key + a 7-role
## balances submodel per row) and drives the REAL QtMT.ModelQuery through
## swap_key_harvest_scene.qml in both regimes over 500 / 2000 / 5000 owned rows:
##   all_roles   = old modelToArray(model, ["key"])
##   single_role = fixed modelToArray (per-role get)
## The scene reads the same "key" out of each; only the fetch strategy differs.
##
## RED: the all-roles harvest is many-fold slower than single-role and grows with
## the owned-row count. GREEN target the ModelUtils fix delivers: the single-role
## harvest is a small fraction of it (the balances submodel is never fetched).

import os, osproc, times, strformat, strutils, tables
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes
import benchmarks/perf_gate

{.compile: "bench_statusq_register.cpp".}
proc bench_registerStatusQTypes() {.importc.}

# --- synthetic owned model (shape of grouped_account_assets_model) ---
#
# The real groupedAccountAssetsModel exposes "key" plus a "balances" submodel whose
# per-row marshalling to JS is what the all-roles get pays for and single-role skips.
# An offscreen nimqml submodel can't be marshalled into ModelQuery.get's all-roles
# QVariantMap->JS here (harness limitation), so the balances payload is flattened
# into value roles led by a heavy "balances" blob (a serialized-balances proxy) plus
# the balances submodel's own fields (account/chainId/tokenAddress/balance/loading).
# The all-roles get fetches + marshals ALL of them per row; single-role fetches only
# "key" — the same O(N*allRoles) vs O(N) differential the ModelUtils fix removes.

const balancesBlob = "[" & repeat("""{"account":"0xACCOUNT000000000000000000000000000000000","chainId":1,"tokenAddress":"0xADDR00000000000000000000000000000000000000","balance":"123456789000000000000","loading":false},""", 6) & "]"

type OwnedRole {.pure.} = enum
  Key = UserRole + 1
  Balances
  Account
  ChainId
  TokenAddress
  Balance
  Loading

QtObject:
  type OwnedAssetsModel = ref object of QAbstractListModel
    keys: seq[string]

  proc delete(self: OwnedAssetsModel)
  proc setup(self: OwnedAssetsModel)
  proc newOwnedAssetsModel(n: int): OwnedAssetsModel =
    new(result, delete)
    result.setup
    result.keys = newSeqOfCap[string](n)
    for i in 0 ..< n:
      result.keys.add("grp_" & $i)

  proc delete(self: OwnedAssetsModel) = self.QAbstractListModel.delete
  proc setup(self: OwnedAssetsModel) = self.QAbstractListModel.setup

  method rowCount(self: OwnedAssetsModel, index: QModelIndex = nil): int = self.keys.len

  method roleNames(self: OwnedAssetsModel): Table[int, string] =
    {OwnedRole.Key.int: "key", OwnedRole.Balances.int: "balances",
     OwnedRole.Account.int: "account", OwnedRole.ChainId.int: "chainId",
     OwnedRole.TokenAddress.int: "tokenAddress", OwnedRole.Balance.int: "balance",
     OwnedRole.Loading.int: "loading"}.toTable

  method data(self: OwnedAssetsModel, index: QModelIndex, role: int): QVariant =
    if index.row < 0 or index.row >= self.keys.len: return
    case role.OwnedRole:
      of OwnedRole.Key: newQVariant(self.keys[index.row])
      of OwnedRole.Balances: newQVariant(balancesBlob)
      of OwnedRole.Account: newQVariant("0xACCOUNT000000000000000000000000000000000")
      of OwnedRole.ChainId: newQVariant(1)
      of OwnedRole.TokenAddress: newQVariant("0xADDR00000000000000000000000000000000000000")
      of OwnedRole.Balance: newQVariant("123456789000000000000")
      of OwnedRole.Loading: newQVariant(false)

# --- bench object driving the scene ---

type Row = object
  size: int
  scenario: string
  ms: float
  joinedLen: int

QtObject:
  type Bench = ref object of QObject
    ready: bool
    msByMode: array[2, float]
    lenByMode: array[2, int]
    resultCount: int

  proc delete(self: Bench)
  proc newBench(): Bench =
    new(result, delete)
    result.QObject.setup

  proc delete(self: Bench) = self.QObject.delete

  proc requestHarvest(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true
  proc nowMs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0
  proc reportResult(self: Bench, mode: int, ms: float, joinedLen: int) {.slot.} =
    if mode in 0..1:
      self.msByMode[mode] = ms
      self.lenByMode[mode] = joinedLen
      inc self.resultCount

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\tms\tjoined_len\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.ms:.4f}\t{r.joinedLen}\n")

const sizes = [500, 2000, 5000]

when isMainModule:
  let modeEnv = getEnv("HARVEST_MODE")

  # A QApplication is needed in BOTH roles (the child measures; the parent still
  # links Qt). Kept at top scope so refc never collects it mid-run (a collected
  # QApplication silently un-instantiates qApp -> "instantiate QApplication first").
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app {.used.} = newQApplication()
  bench_registerStatusQTypes()

  if modeEnv.len > 0:
    # Child: measure one regime over all sizes, write RESULT lines to HARVEST_OUT.
    let mode = parseInt(modeEnv)
    let outPath = getEnv("HARVEST_OUT")
    let bench = newBench()
    let engine = newQQmlApplicationEngine()
    engine.setRootContextProperty("bench", newQVariant(bench))
    engine.setRootContextProperty("harvestMode", newQVariant(mode))

    var outLines: seq[string] = @[]
    for size in sizes:
      let model = newOwnedAssetsModel(size)
      engine.setRootContextProperty("ownedModel", newQVariant(model))
      bench.ready = false
      let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "swap_key_harvest_scene.qml"
      engine.loadData(readFile(sceneFile))
      var spins = 0
      while not bench.ready and spins < 500000:
        QCoreApplication.processEvents(); inc spins
      if not bench.ready:
        writeFile(outPath, "SKIP\n"); quit(0)
      bench.resultCount = 0
      bench.requestHarvest()
      var s = 0
      while bench.resultCount < 1 and s < 500000:
        QCoreApplication.processEvents(); inc s
      outLines.add(&"RESULT\t{size}\t{mode}\t{bench.msByMode[mode]:.4f}\t{bench.lenByMode[mode]}")
    writeFile(outPath, outLines.join("\n") & "\n")
    quit(0)

  # Parent: run each regime in its own child process (direct exec, no shell, so the
  # child inherits DYLD_*); each child writes its RESULT lines to a temp file.
  var rows: seq[Row] = @[]
  let self = getAppFilename()
  for mode in 0 .. 1:
    let outPath = getTempDir() / ("swap_key_harvest_" & $mode & "_" & $getCurrentProcessId() & ".tsv")
    putEnv("HARVEST_MODE", $mode)
    putEnv("HARVEST_OUT", outPath)
    let p = startProcess(self, options = {poParentStreams})  # direct exec keeps DYLD_*
    let code = p.waitForExit()
    p.close()
    doAssert code == 0, &"harvest child (mode {mode}) failed (exit {code})"
    for line in readFile(outPath).splitLines():
      if not line.startsWith("RESULT\t"): continue
      let f = line.split('\t')
      let scenario = if f[2] == "0": "all_roles" else: "single_role"
      rows.add(Row(size: parseInt(f[1]), scenario: scenario,
        ms: parseFloat(f[3]), joinedLen: parseInt(f[4])))
      stderr.writeLine(&"[bench] size={f[1]} {scenario} {f[3]}ms joinedLen={f[4]}")
    removeFile(outPath)

  let table = formatTable(rows)
  echo "\n===== SwapModal request-side key harvest: all-roles vs single-role ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("swap_key_harvest_" & stamp & ".tsv"), table)

  proc rowFor(scenario: string, size: int): Row =
    for r in rows:
      if r.scenario == scenario and r.size == size: return r
    doAssert false, "missing row " & scenario & " @" & $size

  # Correctness: both regimes harvest the same "key" join (same string length).
  for size in sizes:
    doAssert rowFor("all_roles", size).joinedLen == rowFor("single_role", size).joinedLen,
      &"harvest regimes disagree on the joined keys at size {size}"

  # RED/GREEN: the all-roles harvest (old modelToArray) is materially slower than the
  # single-role harvest (fixed modelToArray) at the largest owned-row count, because
  # it fetches + marshals every role per row (in production the balances submodel) for
  # nothing.
  let redBig = rowFor("all_roles", 5000)
  let greenBig = rowFor("single_role", 5000)
  perfAssert greenBig.ms < redBig.ms * 0.7,
    &"expected single-role harvest materially faster @5000 (all_roles {redBig.ms:.2f}ms, single_role {greenBig.ms:.2f}ms)"

  echo "assertions passed"
  echo &"@5000: all-roles {redBig.ms:.1f}ms -> single-role {greenBig.ms:.1f}ms " &
    &"({redBig.ms / greenBig.ms:.1f}x). NOTE: synthetic flattens the balances submodel " &
    "into value roles; production's submodel marshalling makes the real gap larger."
