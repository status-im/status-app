## Handler-lookup benchmark: the SQUtils.ModelUtils lookups SendModalHandler /
## SimpleSendModal run over the wallet tokenGroups model around open, driven on the
## REAL ModelUtils / ModelQuery (registerStatusQTypes, like swap_key_harvest_bench)
## against a tokenGroups-shaped Nim model at 500 / 2000 / 5000 groups.
##
## The tokenGroups model carries per-row `marketDetails` + `tokens` submodels; the
## all-roles get marshals both to JS, the single-role/index paths do not. This
## attributes the handler-JS term of the send-modal open against the picker seed
## (send_modal_open_bench) and the tree instantiation (send_modal_instantiation_bench):
##   getByKey_norole      getByKey(m,"key",v)          -- indexOf + 1 all-roles get
##   getByKey_role        getByKey(m,"key",v,"symbol")  -- indexOf + 1 single-role get
##   get_loop_allroles    for i { get(m,i) } to a miss  -- N all-roles gets (O(N*roles))
##   getFirstModelEntryIf full scan + predicate/row      -- N all-roles gets
##   modelToFlatArray     modelToFlatArray(m,"chainId")  -- role-restricted, O(N*1)
##
## An offscreen nimqml submodel can't be marshalled through ModelQuery.get's
## all-roles QVariantMap->JS here (same harness limitation as swap_key_harvest),
## so the marketDetails/tokens submodels are represented by heavy string value roles
## (a serialized proxy). The all-roles fetch pays for them; the index/single-role
## paths skip them -- the same differential the real submodel marshalling shows,
## understated in absolute terms.

import os, times, strformat, strutils, tables
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes
import benchmarks/perf_gate

{.compile: "bench_statusq_register.cpp".}
proc bench_registerStatusQTypes() {.importc.}

# Heavy per-row proxies for the marketDetails + tokens submodels the all-roles get
# marshals (a real tokenGroups row carries both).
const marketDetailsBlob = """{"currencyPrice":{"amount":1234.56,"symbol":"USD"},"changePct24hour":-2.3,"marketCap":"12345678901","totalCoins":"210000000"}"""
const tokensBlob = "[" & repeat("""{"key":"0xADDR00000000000000000000000000000000000000_1","chainId":1,"address":"0xADDR00000000000000000000000000000000000000","name":"Token","symbol":"TKN","decimals":18},""", 3) & "]"

type GroupRole {.pure.} = enum
  Key = UserRole + 1
  Name
  Symbol
  LogoUri
  Decimals
  CommunityId
  ChainId
  MarketDetails
  Tokens

QtObject:
  type TokenGroupsModel = ref object of QAbstractListModel
    n: int

  proc delete(self: TokenGroupsModel)
  proc setup(self: TokenGroupsModel)
  proc newTokenGroupsModel(n: int): TokenGroupsModel =
    new(result, delete)
    result.setup
    result.n = n

  proc delete(self: TokenGroupsModel) = self.QAbstractListModel.delete
  proc setup(self: TokenGroupsModel) = self.QAbstractListModel.setup

  method rowCount(self: TokenGroupsModel, index: QModelIndex = nil): int = self.n

  method roleNames(self: TokenGroupsModel): Table[int, string] =
    {GroupRole.Key.int: "key", GroupRole.Name.int: "name", GroupRole.Symbol.int: "symbol",
     GroupRole.LogoUri.int: "logoUri", GroupRole.Decimals.int: "decimals",
     GroupRole.CommunityId.int: "communityId", GroupRole.ChainId.int: "chainId",
     GroupRole.MarketDetails.int: "marketDetails", GroupRole.Tokens.int: "tokens"}.toTable

  method data(self: TokenGroupsModel, index: QModelIndex, role: int): QVariant =
    if index.row < 0 or index.row >= self.n: return
    case role.GroupRole:
      of GroupRole.Key: newQVariant("grp_" & $index.row)
      of GroupRole.Name: newQVariant("Token Number " & $index.row & " Wrapped Staked Asset")
      of GroupRole.Symbol: newQVariant("TKN" & $index.row)
      of GroupRole.LogoUri: newQVariant("https://raw.githubusercontent.com/status-im/assets/master/tokens/ethereum/0xADDR/logo.png")
      of GroupRole.Decimals: newQVariant(18)
      of GroupRole.CommunityId: newQVariant("")
      of GroupRole.ChainId: newQVariant(1)
      of GroupRole.MarketDetails: newQVariant(marketDetailsBlob)
      of GroupRole.Tokens: newQVariant(tokensBlob)

type Row = object
  size: int
  scenario: string
  ms: float

QtObject:
  type Bench = ref object of QObject
    ready: bool
    done: bool
    results: Table[string, float]

  proc newBench(): Bench =
    new(result)
    result.QObject.setup
    result.results = initTable[string, float]()

  proc requestLookups(self: Bench) {.signal.}
  proc onSceneReady(self: Bench) {.slot.} = self.ready = true
  proc nowMs(self: Bench): float {.slot.} =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0
  proc reportLookup(self: Bench, name: string, ms: float) {.slot.} =
    self.results[name] = ms
  proc lookupsDone(self: Bench) {.slot.} = self.done = true

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\tms\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.ms:.4f}\n")

const sizes = [500, 2000, 5000]
const lookups = ["getByKey_norole", "getByKey_role", "get_loop_allroles",
  "getFirstModelEntryIf", "modelToFlatArray"]

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()
  bench_registerStatusQTypes()

  let bench = newBench()
  let engine = newQQmlApplicationEngine()
  # ModelUtils is a StatusQ QML singleton -> needs the StatusQ source on the import
  # path (QtModelsToolkit's ModelQuery is C++, registered by registerStatusQTypes).
  engine.addImportPath(getCurrentDir() / "ui" / "StatusQ" / "src")
  engine.setRootContextProperty("bench", newQVariant(bench))

  var rows: seq[Row] = @[]
  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "send_handler_lookup_scene.qml"

  for size in sizes:
    let model = newTokenGroupsModel(size)
    engine.setRootContextProperty("lookupModel", newQVariant(model))
    bench.ready = false
    bench.done = false
    bench.results.clear()
    engine.loadData(readFile(sceneFile))
    var spins = 0
    while not bench.ready and spins < 500000:
      QCoreApplication.processEvents(); inc spins
    if not bench.ready:
      echo "SKIP: send handler-lookup scene did not load"; quit(0)
    bench.requestLookups()
    var s = 0
    while not bench.done and s < 2000000:
      QCoreApplication.processEvents(); inc s
    for name in lookups:
      let ms = bench.results.getOrDefault(name, -1.0)
      rows.add(Row(size: size, scenario: name, ms: ms))
      stderr.writeLine(&"[bench] size={size} {name} {ms:.4f}ms")
      stderr.flushFile()

  let table = formatTable(rows)
  echo "\n===== SendModalHandler open-path ModelUtils lookups (real ModelQuery) ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("send_handler_lookup_" & stamp & ".tsv"), table)

  proc rowFor(scenario: string, size: int): Row =
    for r in rows:
      if r.scenario == scenario and r.size == size: return r
    doAssert false, "missing row " & scenario & " @" & $size

  # The all-roles walks (get-loop / getFirstModelEntryIf) marshal every row's
  # submodel proxies and grow with N; the role-restricted / single-row paths do
  # not. Gate that the all-roles per-row scan is materially heavier than the
  # role-restricted flat scan at the largest size.
  let loopBig = rowFor("get_loop_allroles", 5000)
  let flatBig = rowFor("modelToFlatArray", 5000)
  perfAssert loopBig.ms > flatBig.ms,
    &"expected the all-roles get-loop to exceed the role-restricted scan @5000 " &
    &"(get_loop {loopBig.ms:.2f}ms, modelToFlatArray {flatBig.ms:.2f}ms)"

  echo "assertions passed"
