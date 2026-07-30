## Token-picker propagation benchmark: terminal TokenSelectorModel vs the retired
## TokenSelectorViewAdaptor proxy graph.
##
## The pickers (send / swap / buy) used to render off a QML proxy chain
## (TokenSelectorViewAdaptor: a LeftJoin of the grouped-owned assets with the
## all-tokens/search lists feeding a SortFilterProxyModel). A single owned-balance
## or market-price tick entered that chain through the right-joined groups model,
## so the outer LeftJoinModel emitted a WHOLE-model dataChanged and the SFPM
## re-sorted the whole set — the ×N amplification measured by
## asset_proxy_chain_bench.nim (the picker's owned source is the SAME grouped
## aggregator graph, so that file is the RED baseline for the owned scenarios).
##
## This file measures the GREEN terminal model directly (no proxies above it):
## it context-drives a real TokenSelectorModel the way the producer does
## (setOwnedSource + lazy popular/search closures + param setters) and applies the
## five picker update classes — owned-balance update, market-price update,
## search-results apply, chain-filter flip, page append — over 100 / 1k / 5k token
## universes. For each it records wall time and the model's granular signal counts
## (dataChanged / summed dataChanged row-span / resets / inserts / removes) via the
## in-process QtModelSpy, prints a machine-readable table, and saves it (gitignored)
## under test/nim/benchmarks/results/.
##
## GREEN structural gate (flips the proxy baseline's RED): a stable-set single-cell
## change (owned balance / market price that keeps its rank) propagates as O(1)
## work — the summed dataChanged row-span is a small constant, not the universe
## size — and NO scenario resets the model. Page append is a bounded insert. The
## set-swapping scenarios (search apply, chain-filter flip) are inherent
## whole-list changes and are measured (not O(1)-asserted); they still never reset.
##
## Compile -d:QT_MODEL_SPY (pure-Nim model hooks, like token_selector_model_test).

import os, times, strformat, strutils, tables
import stint
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents
import std/monotimes

import app/modules/shared_models/token_selector_model
import app/modules/shared_models/token_selector_builder
import app/modules/shared_models/assets_aggregator
import app/modules/shared/qt_model_spy
import benchmarks/perf_gate

type Row = object
  size: int
  scenario: string
  wallMs: float
  dataChanged: int
  dataChangedRows: int
  resets: int
  inserted: int
  removed: int

proc dataChangedRows(spy: QtModelSpy): int =
  for c in spy.calls:
    if c.kind == DataChanged:
      result += (c.bottomRight - c.topLeft + 1)

proc dataChangedCount(spy: QtModelSpy): int =
  for c in spy.calls:
    if c.kind == DataChanged:
      inc result

# --- synthetic universe -------------------------------------------------------
# Owned groups spread over `chains` chains, each with one per-chain balance, so
# chain-filter and per-chip paths are exercised. Popular groups back the
# AllTokens merge + page append; search returns a filtered slice of them.

const chains = [1, 10, 42161, 8453, 11155111]

proc weiFor(i: int): UInt256 =
  # non-zero, varied; keeps every owned group with a balance
  parse($((i mod 1000) + 1) & "000000000000000000", UInt256)

proc ownedGroup(i: int): AggTokenGroup =
  let chain = chains[i mod chains.len]
  AggTokenGroup(
    key: "tok_" & $i,
    name: "Token " & $i,
    symbol: "T" & $i,
    logoUri: "",
    decimals: 18,
    communityId: "",
    marketPrice: 1.0 + float(i mod 500) * 0.01,
    balances: @[AggBalance(account: "0xA", chainId: chain, balance: weiFor(i), loading: false)],
    tokens: @[(key: "tok_" & $i & "_c" & $chain, chainId: chain)])

proc buildOwned(n: int): seq[AggTokenGroup] =
  result = newSeqOfCap[AggTokenGroup](n)
  for i in 0 ..< n:
    result.add(ownedGroup(i))

proc popularGroup(i: int): PopularGroup =
  # Shares the owned key space (tok_i) so the all-tokens merge attaches owned
  # balances to the displayed popular rows — an owned-cell edit then lands on a
  # visible row (the O(1) propagation the benchmark measures).
  let chain = chains[i mod chains.len]
  PopularGroup(key: "tok_" & $i, name: "Token " & $i, symbol: "T" & $i,
    logoUri: "", communityId: "", marketPrice: 1.0 + float(i mod 500) * 0.01,
    tokens: @[(key: "tok_" & $i & "_c" & $chain, chainId: chain)])

proc formatTable(rows: seq[Row]): string =
  result = "size\tscenario\twall_ms\tdataChanged\tdataChangedRows\tresets\tinserted\tremoved\n"
  for r in rows:
    result.add(&"{r.size}\t{r.scenario}\t{r.wallMs:.4f}\t{r.dataChanged}\t{r.dataChangedRows}\t{r.resets}\t{r.inserted}\t{r.removed}\n")

when isMainModule:
  putEnv("QT_QPA_PLATFORM", "offscreen")
  let app = newQApplication()

  let networks = @[
    NetworkInfo(chainId: 1, chainName: "Mainnet", iconUrl: ""),
    NetworkInfo(chainId: 10, chainName: "Optimism", iconUrl: ""),
    NetworkInfo(chainId: 42161, chainName: "Arbitrum", iconUrl: ""),
    NetworkInfo(chainId: 8453, chainName: "Base", iconUrl: ""),
    NetworkInfo(chainId: 11155111, chainName: "Sepolia", iconUrl: ""),
  ]

  let spy = newQtModelSpy()
  spy.enable()

  var rows: seq[Row] = @[]

  proc pump() =
    for _ in 0 ..< 4:
      QCoreApplication.processEvents()

  proc runSize(size: int) =
    # Popular list grows in place on fetchMore; start with one page loaded.
    let popularPage = 25
    var popularLoaded = popularPage
    let popularTotal = size

    var source: TokenSelectorSource
    source.getPopular = proc(): seq[PopularGroup] =
      result = newSeqOfCap[PopularGroup](popularLoaded)
      for i in 0 ..< min(popularLoaded, popularTotal): result.add(popularGroup(i))
    source.getSearch = proc(): seq[PopularGroup] =
      # a filtered slice of the popular universe
      result = @[]
      for i in 0 ..< popularTotal:
        if (i mod 7) == 0: result.add(popularGroup(i))
    source.doSearch = proc(keyword: string) = discard
    source.fetchMore = proc(searching: bool) =
      if not searching: popularLoaded = min(popularLoaded + popularPage, popularTotal)
    source.hasMore = proc(searching: bool): bool =
      (not searching) and popularLoaded < popularTotal
    source.isLoadingMore = proc(searching: bool): bool = false

    let m = newTokenSelectorModel(TokenSelectorMode.AllTokens)
    m.setSectionNames("Your assets", "Popular assets")
    m.setSource(source)
    var owned = buildOwned(size)
    m.setOwnedSource(owned, networks)
    pump()

    proc measure(scenario: string, mutate: proc()) =
      spy.clear()
      let t0 = getMonoTime()
      mutate()
      pump()
      let t1 = getMonoTime()
      rows.add(Row(size: size, scenario: scenario,
        wallMs: (t1 - t0).inNanoseconds.float / 1_000_000.0,
        dataChanged: spy.dataChangedCount(), dataChangedRows: spy.dataChangedRows(),
        resets: spy.countResets(), inserted: spy.countInserts(), removed: spy.countRemoves()))
      stderr.writeLine(&"[bench] size={size} {scenario} {rows[^1].wallMs:.2f}ms dataChangedRows={rows[^1].dataChangedRows} resets={rows[^1].resets}")
      stderr.flushFile()

    # 1) owned-balance update: nudge one displayed group's balance by 1 wei so it
    # keeps its rank — the change should touch exactly that one row.
    measure("owned_balance_update", proc() =
      let i = 5  # a displayed row (within the initially loaded popular window)
      owned[i].balances[0].balance = owned[i].balances[0].balance + parse("1", UInt256)
      m.setOwnedSource(owned, networks))

    # 2) market-price update: bump one group's price a little (keeps its rank).
    measure("market_price_update", proc() =
      let i = 5  # a displayed row (within the initially loaded popular window)
      owned[i].marketPrice = owned[i].marketPrice + 0.001
      m.setOwnedSource(owned, networks))

    # 3) search-results apply: swap the list to the search slice (inherent).
    measure("search_apply", proc() = m.search("pop"))

    # restore the non-search list before the next measurement
    m.search("")
    pump()

    # 4) chain-filter flip: scope to a single chain (inherent big filter).
    measure("chain_filter_flip", proc() = m.setEnabledChainId(1))
    m.setEnabledChainId(-1)
    pump()

    # 5) page append: grow the popular list by one page (bounded insert).
    measure("page_append", proc() = m.fetchMore())

  for size in benchSizes([100, 1000, 5000], [100]):
    runSize(size)

  let table = formatTable(rows)
  echo "\n===== token-picker terminal-model propagation (GREEN) ====="
  echo table

  let resultsDir = getCurrentDir() / "test" / "nim" / "benchmarks" / "results"
  createDir(resultsDir)
  let stamp = now().format("yyyyMMdd'T'HHmmss")
  writeFile(resultsDir / ("token_selector_model_" & stamp & ".tsv"), table)

  # GREEN structural gate. The proxy baseline (asset_proxy_chain_bench) fanned a
  # single owned-cell edit into a whole-model dataChanged (dataChangedRows >= N)
  # and re-sorted the whole set; here a stable-set single-cell change is O(1) and
  # neither the terminal model nor its preserved submodels reset. The set-swapping
  # scenarios (search apply, chain-filter flip) are inherent whole-list changes —
  # their nested submodels legitimately tear down, so they are measured, not gated.
  for r in rows:
    if r.scenario in ["owned_balance_update", "market_price_update"]:
      doAssert r.dataChangedRows <= 8,
        &"expected O(1) propagation for '{r.scenario}' at size {r.size} (got {r.dataChangedRows} rows)"
      doAssert r.inserted == 0 and r.removed == 0,
        &"stable-set '{r.scenario}' changed the row set at size {r.size}"
      doAssert r.resets == 0,
        &"stable-set '{r.scenario}' reset a model at size {r.size}"
    if r.scenario == "page_append":
      doAssert r.inserted > 0 and r.removed == 0 and r.resets == 0,
        &"page_append should be a bounded insert (no removes/resets) at size {r.size}"

  echo "structural assertions passed"
