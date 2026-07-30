## SwapModal-open integration benchmark: the real Nim `tokenGroupsForChainModel`
## (lazy, NoMarketDetails) driven under a real offscreen QQmlApplicationEngine with
## an animating "modal" panel + ListView + 16ms stall monitor
## (swap_modal_open_scene.qml).
##
## What opening the swap token selector does today: SwapModal.onCompleted ->
## TokensStore.buildGroupsForChain -> token service `buildGroupsForChain` fires
## `asyncBuildGroupsForChainTask`, which ships the chain's tokens back as a RAW JSON
## STRING envelope. The completion slot `onAsyncBuildGroupsForChainDone` then runs
## ON THE GUI THREAD: Json.decode of the whole chain token list + createTokenItem
## per token + group build + sort, and in the same tick emits
## SIGNAL_GROUPS_FOR_CHAIN_LOADED -> view.onGroupsForChainLoaded ->
## tokenGroupsForChainModel.modelsUpdated(resetModelSize = true, mandatoryKeys).
## All of that lands mid-open-animation -> a visible freeze.
##
## This bench measures both regimes on the SAME real model + scene, per chain-token
## universe size (2k / 5k / 10k):
##
##   open_string_envelope (today):  in the measured open window, decode the JSON
##     envelope + build the groups + modelsUpdated. This is the GUI-thread work the
##     string-envelope path performs.
##
##   open_typed_handoff (target):   the worker-built groups seq is prepared BEFORE
##     the window (simulating the threadpool build); in the window only the seq swap
##     + modelsUpdated runs — the residual GUI-thread fan-out the typed-handoff
##     migration leaves behind.
##
## The model reset + mandatory-keys expansion (modelsUpdated) is the REAL production
## code in both regimes, so open_typed_handoff also measures whether that residual
## fan-out alone stalls (the O(K*N) mandatory-keys scan the migration does not
## touch).
##
## RED  (documents the problem): open_string_envelope @10k blocks the GUI thread
##      > 32ms (one dropped frame).
## GREEN (the target to hold): open_typed_handoff @10k <= 32ms.
##
## Compile -d:QT_MODEL_SPY (pure-Nim model hooks, like token_groups_model_test).

import os, times, strformat, strutils, tables, sequtils, sugar, algorithm, json
import nimqml
import json_serialization
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

import app/modules/main/wallet_section/all_tokens/token_groups_model
import app/modules/main/wallet_section/all_tokens/io_interface
import app_service/service/token/items/token_group
import app_service/service/token/items/token
import app_service/service/token/dto/token as token_dto
import benchmarks/perf_gate

# Faithful replica of the string-envelope decode the production slot performed
# before the typed handoff: same DTO seq, same decode cost.
type BenchGroupsForChainResponse = object
  chainId: int
  tokens: seq[TokenDto]
  error: string

type Row = object
  size: int
  scenario: string
  injectMs: float       # wall time of the synchronous GUI-thread injection
  maxStallMs: float     # largest 16ms-timer tick-to-tick delta during the window
  over32: int           # count of tick deltas > 32ms during the window
  resets: int
  inserted: int
  dataChanged: int
  delegatesCreated: int
  delegatesDestroyed: int

# --- synthetic chain-token universe -------------------------------------------
# getTokensByChain returns every token on one chain; on mainnet most tokens are a
# distinct group (unique crossChainId), so N tokens -> N groups. The owned assets
# SwapModal passes as mandatory keys are a bounded subset (a heavy user's holdings).

const ownedCap = 250  # mandatory (owned) group keys SwapModal forces to the top

# Mainnet-shaped token fields: a real getTokensByChain row carries a 42-char
# checksummed address, a full asset name, and a ~95-char raw.githubusercontent
# logo URI, so a chain's token list is ~250-300 bytes/token (~2.5-3MB @10k). The
# synthetic payload matches that so the GUI-thread decode+build cost is realistic.
proc addressFor(i: int): string = "0x" & toHex(i, 40)
proc groupKeyFor(i: int): string = "grp_" & $i

proc tokenDtoFor(i: int): TokenDto =
  let tokenAddress = addressFor(i)
  TokenDto(
    crossChainId: groupKeyFor(i),
    address: tokenAddress,
    name: "Token Number " & $i & " Wrapped Staked Governance Asset",
    symbol: "TKN" & $i,
    decimals: 18,
    chainId: 1,
    logoUri: "https://raw.githubusercontent.com/status-im/assets/master/tokens/ethereum/" &
      tokenAddress & "/logo.png",
    customToken: false,
  )

proc buildEnvelopeJson(n: int): string =
  ## The raw worker RPC output the string-envelope path ships to the GUI thread.
  var arr = newJArray()
  for i in 0 ..< n:
    let d = tokenDtoFor(i)
    arr.add(%*{
      "crossChainId": d.crossChainId, "address": d.address, "name": d.name,
      "symbol": d.symbol, "decimals": d.decimals, "chainId": d.chainId,
      "logoUri": d.logoUri, "custom": d.customToken,
      "communityData": {"id": "", "name": "", "color": "", "image": ""}})
  $(%*{"chainId": 1, "tokens": arr, "error": ""})

# Byte-identical replicas of the private service_main helpers the slot runs inline.
proc benchCreateGroups(tokens: seq[TokenItem]): seq[TokenGroupItem] =
  var groupsByKey = initTable[string, TokenGroupItem](tokens.len)
  for token in tokens:
    let groupKey = token.groupKey
    if not groupsByKey.hasKey(groupKey):
      groupsByKey[groupKey] = TokenGroupItem(key: groupKey, name: token.name,
        symbol: token.symbol, decimals: token.decimals, logoUri: token.logoUri)
    groupsByKey[groupKey].addToken(token)
  result = toSeq(groupsByKey.values)
  result.sort(proc(a, b: TokenGroupItem): int = a.name.cmp(b.name))

proc buildGroupsFromEnvelope(envelope: string): seq[TokenGroupItem] =
  ## Exactly what onAsyncBuildGroupsForChainDone does on the GUI thread today.
  let env = Json.decode(envelope, BenchGroupsForChainResponse, allowUnknownFields = true)
  let tokens = env.tokens.map(t => createTokenItem(t))
  benchCreateGroups(tokens)

# The model reads its source through this global (mirrors the service's
# groupsForChain seq the view delegate returns).
var gGroupsForChain: seq[TokenGroupItem] = @[]

proc groupsForChainDataSource(): TokenGroupsModelDataSource =
  (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = gGroupsForChain,
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem = default(TokenDetailsItem),
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem = default(TokenPreferencesItem),
    getCommunityTokenDescription: proc(chainId: int, address: string): string = "",
    getTokensDetailsLoading: proc(): bool = false,
    getTokensMarketValuesLoading: proc(): bool = false,
  )

proc marketValuesDataSource(): TokenMarketValuesDataSource =
  (
    getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem = default(TokenMarketValuesItem),
    getPriceForToken: proc(tokenKey: string): float64 = 0.0,
    getCurrentCurrencyFormat: proc(): CurrencyFormatDto = default(CurrencyFormatDto),
    getTokensMarketValuesLoading: proc(): bool = false,
  )

const
  LAZY_BATCH = 100
  LAZY_INITIAL = 100

QtObject:
  type Bench = ref object of QObject
    ready: bool
    monitoring: bool
    lastTickNs: float
    maxStallMs: float
    over32: int
    cReset: int
    cInserted: int
    cDataChanged: int
    cDelegatesCreated: int
    cDelegatesDestroyed: int

  proc newBench(): Bench =
    # Run-once bench: no finalizer (the deprecated new(obj, finalizer) conflicts
    # with the lifted =destroy under the default mm); the QObject lives for the
    # whole process and is reclaimed at exit.
    new(result)
    result.QObject.setup

  proc requestOpen(self: Bench) {.signal.}
  proc requestRelayout(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true
  proc onDelegateCreated(self: Bench) {.slot.} = inc self.cDelegatesCreated
  proc onDelegateDestroyed(self: Bench) {.slot.} = inc self.cDelegatesDestroyed
  proc onModelReset(self: Bench) {.slot.} = inc self.cReset
  proc onRowsInserted(self: Bench) {.slot.} = inc self.cInserted
  proc onDataChanged(self: Bench, first: int, last: int) {.slot.} = inc self.cDataChanged
  proc onRowsRemoved(self: Bench) {.slot.} = discard

  proc nowMs(self: Bench): float =
    (getMonoTime() - MonoTime()).inNanoseconds.float / 1_000_000.0

  proc onStallTick(self: Bench) {.slot.} =
    if not self.monitoring:
      return
    let n = self.nowMs()
    let delta = n - self.lastTickNs
    if delta > self.maxStallMs:
      self.maxStallMs = delta
    if delta > 32.0:
      inc self.over32
    self.lastTickNs = n

  proc beginMonitor(self: Bench) =
    self.maxStallMs = 0.0
    self.over32 = 0
    self.lastTickNs = self.nowMs()
    self.monitoring = true

  proc endMonitor(self: Bench) = self.monitoring = false

  proc resetCounters(self: Bench) =
    self.cReset = 0; self.cInserted = 0; self.cDataChanged = 0
    self.cDelegatesCreated = 0; self.cDelegatesDestroyed = 0

  proc spinFor(self: Bench, ms: float) =
    ## Busy-drive the event loop for `ms` wall time so the 16ms stall timer fires.
    let deadline = self.nowMs() + ms
    while self.nowMs() < deadline:
      QCoreApplication.processEvents()

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\tinject_ms\tmax_stall_ms\tover32\tresets\tinserted\tdataChanged\tdelegatesCreated\tdelegatesDestroyed\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.injectMs:.4f}\t{r.maxStallMs:.4f}\t{r.over32}\t{r.resets}\t{r.inserted}\t{r.dataChanged}\t{r.delegatesCreated}\t{r.delegatesDestroyed}\n")

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()

  let model = newTokenGroupsModel(
    groupsForChainDataSource(), marketValuesDataSource(),
    modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading],
    lazyLoadingBatchSize = LAZY_BATCH, lazyLoadingInitialCount = LAZY_INITIAL)
  let modelVariant = newQVariant(model)

  let bench = newBench()
  let benchVariant = newQVariant(bench)

  let engine = newQQmlApplicationEngine()
  engine.setRootContextProperty("groupsForChainModel", modelVariant)
  engine.setRootContextProperty("bench", benchVariant)

  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "swap_modal_open_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 500000:
    QCoreApplication.processEvents()
    inc spins
  if not bench.ready:
    echo "SKIP: swap-modal-open scene did not load"
    quit(0)

  var rows: seq[Row] = @[]

  proc runSize(size: int) =
    let mandatoryKeys = collect(newSeq):
      for i in 0 ..< min(size, ownedCap): groupKeyFor(i)

    # A completion always follows an open. Reset the model to empty, open the pane,
    # let the enter animation run, then inject the completion mid-window and measure.
    proc measure(scenario: string, buildOffWindow: bool) =
      # Fresh model + closed pane for each scenario.
      gGroupsForChain = @[]
      model.modelsUpdated(resetModelSize = true, @[])
      bench.resetCounters()

      # Pre-decode the raw worker output. In the typed-handoff regime the groups are
      # built here (off the measured window); in the string-envelope regime only the
      # raw JSON is prepared and the GUI thread decodes+builds inside the window.
      let envelope = buildEnvelopeJson(size)
      var prebuilt: seq[TokenGroupItem]
      if buildOffWindow:
        prebuilt = buildGroupsFromEnvelope(envelope)

      # Open the pane and let the enter animation get going.
      bench.requestOpen()
      bench.spinFor(120)

      bench.beginMonitor()
      bench.spinFor(48)  # a few baseline frames before the injection

      let t0 = bench.nowMs()
      if buildOffWindow:
        gGroupsForChain = move prebuilt
      else:
        gGroupsForChain = buildGroupsFromEnvelope(envelope)
      model.modelsUpdated(resetModelSize = true, mandatoryKeys)
      let t1 = bench.nowMs()

      bench.requestRelayout()
      bench.spinFor(200)  # capture the post-injection tick delta + delegate churn
      bench.endMonitor()

      rows.add(Row(size: size, scenario: scenario,
        injectMs: t1 - t0, maxStallMs: bench.maxStallMs, over32: bench.over32,
        resets: bench.cReset, inserted: bench.cInserted, dataChanged: bench.cDataChanged,
        delegatesCreated: bench.cDelegatesCreated,
        delegatesDestroyed: bench.cDelegatesDestroyed))
      stderr.writeLine(&"[bench] size={size} {scenario} inject={rows[^1].injectMs:.2f}ms maxStall={rows[^1].maxStallMs:.2f}ms over32={rows[^1].over32} resets={rows[^1].resets}")
      stderr.flushFile()

    measure("open_string_envelope", buildOffWindow = false)
    measure("open_typed_handoff", buildOffWindow = true)

  for size in benchSizes([2000, 5000, 10000], [10000]):
    runSize(size)

  let table = formatTable(rows)
  echo "\n===== SwapModal open: GUI-thread stall by completion regime ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("swap_modal_open_" & stamp & ".tsv"), table)

  proc rowFor(scenario: string, size: int): Row =
    for r in rows:
      if r.scenario == scenario and r.size == size: return r
    doAssert false, "missing row " & scenario & " @" & $size

  # RED: the string-envelope path drops at least one frame at the 10k universe -- the
  # render loop's 16ms tick opens a >32ms gap (the visible open freeze) because the
  # decode + build blocks the GUI thread (inject_ms) mid-open. Gated on the observed
  # frame gap (the brief's tick-to-tick metric); inject_ms is the pure-compute block.
  let redRow = rowFor("open_string_envelope", 10000)
  perfAssert redRow.over32 >= 1 and redRow.maxStallMs > 32.0,
    &"expected string-envelope open to drop a frame @10k " &
    &"(maxStall {redRow.maxStallMs:.2f}ms, over32 {redRow.over32}, inject {redRow.injectMs:.2f}ms)"

  # GREEN target the typed-handoff migration must hold: with the build moved off the
  # GUI thread, the residual on-window fan-out (seq swap + modelsUpdated reset +
  # mandatory-keys expansion) never blocks a frame -- no >32ms tick, and the pure
  # GUI-thread block stays well within one frame.
  let greenRow = rowFor("open_typed_handoff", 10000)
  perfAssert greenRow.over32 == 0 and greenRow.maxStallMs <= 32.0 and greenRow.injectMs <= 32.0,
    &"typed-handoff open should not drop a frame @10k " &
    &"(maxStall {greenRow.maxStallMs:.2f}ms, over32 {greenRow.over32}, inject {greenRow.injectMs:.2f}ms) -- " &
    "residual GUI-thread fan-out (modelsUpdated reset / mandatory-keys scan) too heavy"

  echo "assertions passed"
