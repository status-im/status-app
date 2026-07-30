## SimpleSendModal-open integration benchmark: the real Nim send picker model
## (TokenSelectorModel, Owned mode) driven under a real offscreen
## QQmlApplicationEngine with an animating sheet + a Loader-gated dropdown ListView
## + a 16ms stall monitor (send_modal_open_scene.qml).
##
## What opening the send modal does today (the GUI-thread work this measures):
## SendModalHandler instantiates the modal tree and, as part of that, its handler
## QtObject synchronously creates the send picker model
## (`WalletStores.RootStore.tokensStore.createTokenSelectorModel(0)`), which on the
## Nim side runs `buildOwnedSource()` (walks the owned token groups + grouped
## assets) then `setOwnedSource(groups, networks)` -> `recompute` ->
## `buildDisplayItems` (filter owned + build per-chain chips) -> `setSourceItems`
## (sort + diff + reconcileByKey: one nested balances model + one nested tokens
## model PER group) -> row inserts; then `updateSendSectionNames()` -> a
## whole-list section-name dataChanged. All of that lands on the GUI thread while
## the sheet animates open.
##
## Two regimes are measured on the SAME real model + scene, per owned-set size
## (a heavy user's holdings are ~50-200; 500 / 1000 / 2000 are stress points that
## expose scaling of the reconcileByKey nested-QObject construction):
##
##   open_seed (the modal-open cost):  the dropdown is CLOSED (a real dropdown
##     realizes no delegates until opened), and mid-open-window the seed burst
##     (setOwnedSource + setSectionNames) runs. `compute_ms` isolates the pure
##     buildDisplayItems aggregation; `inject_ms` is the full on-GUI-thread burst
##     (aggregation + setSourceItems + nested-model construction + inserts +
##     section-name dataChanged).
##
##   dropdown_open (the next interaction):  the model is seeded BEFORE the window;
##     in the window the dropdown ListView is realized (outer owned rows + the
##     nested chip Repeaters), measuring the picker-open delegate churn.
##
## Attribution: `compute_ms` vs `inject_ms` splits pure aggregation from model
## machinery; `max_stall_ms` / `over32` are the frame-drop probe; delegates/chips
## count the realized view; resets/inserted/dataChanged are the model emissions.
##
## Compile -d:QT_MODEL_SPY (pure-Nim model hooks, like token_selector_model_test).

import os, times, strformat, strutils
import stint
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

import app/modules/shared_models/token_selector_model
import app/modules/shared_models/token_selector_builder
import app/modules/shared_models/assets_aggregator
import benchmarks/perf_gate

type Row = object
  size: int
  scenario: string
  computeMs: float      # pure buildDisplayItems aggregation (owned filter + chips)
  injectMs: float       # full synchronous GUI-thread seed burst
  maxStallMs: float     # largest 16ms-timer tick-to-tick delta during the window
  over32: int           # count of tick deltas > 32ms during the window
  resets: int
  inserted: int
  dataChanged: int
  delegatesCreated: int
  chipsCreated: int

# --- synthetic owned universe -------------------------------------------------
# The send picker's base list is the user's OWNED token groups (createTokenSelector
# model KIND_SEND, Owned mode). Each owned group carries per-chain balances that
# become the delegate's chip submodel. Mainnet-shaped fields (42-char address in
# the token key, full name, ~95-char logo URI) so the per-group build + marshal
# cost is realistic.

const chains = [1, 10, 42161, 8453, 11155111, 56, 137, 59144]

proc addressFor(i: int): string = "0x" & toHex(i, 40)

proc weiFor(i: int): UInt256 =
  parse($((i mod 1000) + 1) & "000000000000000000", UInt256)

proc ownedGroup(i: int): AggTokenGroup =
  let addr0 = addressFor(i)
  let addr1 = addressFor(i + 1_000_000)
  let c0 = chains[i mod chains.len]
  let c1 = chains[(i + 3) mod chains.len]
  # Two per-chain balances => a 2-chip nested balances submodel per row.
  AggTokenGroup(
    key: "grp_" & addr0,
    name: "Token Number " & $i & " Wrapped Staked Governance Asset",
    symbol: "TKN" & $i,
    logoUri: "https://raw.githubusercontent.com/status-im/assets/master/tokens/ethereum/" &
      addr0 & "/logo.png",
    decimals: 18,
    communityId: "",
    marketPrice: 1.0 + float(i mod 500) * 0.01,
    balances: @[
      AggBalance(account: "0xA", chainId: c0, balance: weiFor(i), loading: false),
      AggBalance(account: "0xA", chainId: c1, balance: weiFor(i + 7), loading: false),
    ],
    tokens: @[
      (key: "tok_" & addr0 & "_c" & $c0, chainId: c0),
      (key: "tok_" & addr1 & "_c" & $c1, chainId: c1),
    ])

proc buildOwned(n: int): seq[AggTokenGroup] =
  result = newSeqOfCap[AggTokenGroup](n)
  for i in 0 ..< n:
    result.add(ownedGroup(i))

# Send picker params: a real account is selected, zero-balance default tokens
# shown, community assets hidden, no chain filter (whole owned set).
proc sendParams(): TokenSelectorParams =
  TokenSelectorParams(
    accountAddress: "0xA",
    enabledChainIds: @[],
    showZeroBalanceForDefaultTokens: true,
    showCommunityAssets: false)

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
    cChipsCreated: int

  proc newBench(): Bench =
    # Run-once bench: no finalizer (the deprecated new(obj, finalizer) conflicts
    # with the lifted =destroy under the default mm); the QObject lives for the
    # whole process and is reclaimed at exit.
    new(result)
    result.QObject.setup

  proc requestOpen(self: Bench) {.signal.}
  proc requestDropdownOpen(self: Bench) {.signal.}
  proc requestDropdownClose(self: Bench) {.signal.}
  proc requestRelayout(self: Bench) {.signal.}

  proc onSceneReady(self: Bench) {.slot.} = self.ready = true
  proc onDelegateCreated(self: Bench) {.slot.} = inc self.cDelegatesCreated
  proc onDelegateDestroyed(self: Bench) {.slot.} = inc self.cDelegatesDestroyed
  proc onChipCreated(self: Bench) {.slot.} = inc self.cChipsCreated
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
    self.cDelegatesCreated = 0; self.cDelegatesDestroyed = 0; self.cChipsCreated = 0

  proc spinFor(self: Bench, ms: float) =
    ## Busy-drive the event loop for `ms` wall time so the 16ms stall timer fires.
    let deadline = self.nowMs() + ms
    while self.nowMs() < deadline:
      QCoreApplication.processEvents()

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\tcompute_ms\tinject_ms\tmax_stall_ms\tover32\tresets\tinserted\tdataChanged\tdelegatesCreated\tchipsCreated\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.computeMs:.4f}\t{r.injectMs:.4f}\t{r.maxStallMs:.4f}\t{r.over32}\t{r.resets}\t{r.inserted}\t{r.dataChanged}\t{r.delegatesCreated}\t{r.chipsCreated}\n")

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()

  let networks = @[
    NetworkInfo(chainId: 1, chainName: "Mainnet", iconUrl: "network/Network=Ethereum"),
    NetworkInfo(chainId: 10, chainName: "Optimism", iconUrl: "network/Network=Optimism"),
    NetworkInfo(chainId: 42161, chainName: "Arbitrum", iconUrl: "network/Network=Arbitrum"),
    NetworkInfo(chainId: 8453, chainName: "Base", iconUrl: "network/Network=Base"),
    NetworkInfo(chainId: 11155111, chainName: "Sepolia", iconUrl: "network/Network=Sepolia"),
    NetworkInfo(chainId: 56, chainName: "BSC", iconUrl: "network/Network=BSC"),
    NetworkInfo(chainId: 137, chainName: "Polygon", iconUrl: "network/Network=Polygon"),
    NetworkInfo(chainId: 59144, chainName: "Linea", iconUrl: "network/Network=Linea"),
  ]

  let model = newTokenSelectorModel(TokenSelectorMode.Owned)
  var source: TokenSelectorSource  # send: no popular list; search/lazy unused at open
  model.setSource(source)
  let modelVariant = newQVariant(model)

  let bench = newBench()
  let benchVariant = newQVariant(bench)

  let engine = newQQmlApplicationEngine()
  engine.setRootContextProperty("sendPickerModel", modelVariant)
  engine.setRootContextProperty("bench", benchVariant)

  let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" / "send_modal_open_scene.qml"
  engine.loadData(readFile(sceneFile))

  var spins = 0
  while not bench.ready and spins < 500000:
    QCoreApplication.processEvents()
    inc spins
  if not bench.ready:
    echo "SKIP: send-modal-open scene did not load"
    quit(0)

  var rows: seq[Row] = @[]

  proc runSize(size: int) =
    let owned = buildOwned(size)
    let params = sendParams()

    # --- open_seed: the modal-open model-seed burst, dropdown CLOSED ----------
    block:
      bench.requestDropdownClose()
      # Fresh empty model + closed sheet.
      model.setOwnedSource(@[], networks)
      model.setSectionNames("", "")
      bench.resetCounters()

      # Pure aggregation cost, isolated (no model emissions / nested construction).
      let c0 = bench.nowMs()
      let items = buildDisplayItems(owned, networks, params,
        TokenSelectorMode.Owned, false, @[], @[])
      let c1 = bench.nowMs()
      doAssert items.len == size  # every owned group survives (non-zero balances)

      # Open the sheet and let the enter animation get going.
      bench.requestOpen()
      bench.spinFor(120)

      bench.beginMonitor()
      bench.spinFor(48)  # a few baseline frames before the seed burst

      let t0 = bench.nowMs()
      model.setOwnedSource(owned, networks)
      model.setSectionNames("Your assets on Mainnet", "Popular assets")
      let t1 = bench.nowMs()

      bench.spinFor(200)  # capture the post-seed tick delta
      bench.endMonitor()

      rows.add(Row(size: size, scenario: "open_seed",
        computeMs: c1 - c0, injectMs: t1 - t0,
        maxStallMs: bench.maxStallMs, over32: bench.over32,
        resets: bench.cReset, inserted: bench.cInserted, dataChanged: bench.cDataChanged,
        delegatesCreated: bench.cDelegatesCreated, chipsCreated: bench.cChipsCreated))
      stderr.writeLine(&"[bench] size={size} open_seed compute={rows[^1].computeMs:.2f}ms inject={rows[^1].injectMs:.2f}ms maxStall={rows[^1].maxStallMs:.2f}ms over32={rows[^1].over32}")
      stderr.flushFile()

    # --- dropdown_open: realize the picker list (next interaction) ------------
    block:
      # Model already seeded above; sheet open, dropdown closed. Seed is off-window.
      bench.requestDropdownClose()
      bench.spinFor(48)
      bench.resetCounters()

      bench.beginMonitor()
      bench.spinFor(16)
      bench.requestDropdownOpen()   # Loader builds the ListView
      bench.spinFor(48)
      # forceLayout realizes the visible delegates + their chip Repeaters
      # synchronously in one call -- time that, not the observation window.
      let t0 = bench.nowMs()
      bench.requestRelayout()
      let t1 = bench.nowMs()
      bench.spinFor(200)  # capture any post-realization tick delta
      bench.endMonitor()

      rows.add(Row(size: size, scenario: "dropdown_open",
        computeMs: 0.0, injectMs: t1 - t0,
        maxStallMs: bench.maxStallMs, over32: bench.over32,
        resets: bench.cReset, inserted: bench.cInserted, dataChanged: bench.cDataChanged,
        delegatesCreated: bench.cDelegatesCreated, chipsCreated: bench.cChipsCreated))
      stderr.writeLine(&"[bench] size={size} dropdown_open maxStall={rows[^1].maxStallMs:.2f}ms over32={rows[^1].over32} delegates={rows[^1].delegatesCreated} chips={rows[^1].chipsCreated}")
      stderr.flushFile()

  for size in benchSizes([50, 200, 500, 1000, 2000], [200]):
    runSize(size)

  let table = formatTable(rows)
  echo "\n===== SimpleSendModal open: GUI-thread cost of the send picker seed ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("send_modal_open_" & stamp & ".tsv"), table)

  proc rowFor(scenario: string, size: int): Row =
    for r in rows:
      if r.scenario == scenario and r.size == size: return r
    doAssert false, "missing row " & scenario & " @" & $size

  # At a realistic heavy-user owned set (~200) the on-open seed burst must not drop
  # a frame -- the picker seed is NOT the source of the ~1s open at real sizes.
  let seed200 = rowFor("open_seed", 200)
  perfAssert seed200.over32 == 0 and seed200.maxStallMs <= 32.0,
    &"send picker open_seed dropped a frame @200 owned " &
    &"(compute {seed200.computeMs:.2f}ms, inject {seed200.injectMs:.2f}ms, " &
    &"maxStall {seed200.maxStallMs:.2f}ms, over32 {seed200.over32})"

  echo "assertions passed"
