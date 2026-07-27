## Structural + value tests for TokenSelectorModel (the terminal picker model).
## Compile -d:QT_MODEL_SPY.
##
## Acceptance gate: a stable-set single-cell change emits exactly one dataChanged
## over one row and NO layoutChanged / NO reset; add/remove emit a single
## insert/remove; a reorder degrades to remove+insert (no reset). The nested
## balances submodel keeps its identity across refreshes and carries chip changes
## through its own signals.

import unittest, sequtils
import stint
import nimqml

import app/modules/shared_models/token_selector_model
import app/modules/shared_models/assets_aggregator
import app/modules/shared/qt_model_spy

proc dataChangedRows(spy: QtModelSpy): int =
  for c in spy.calls:
    if c.kind == DataChanged:
      result += (c.bottomRight - c.topLeft + 1)

proc layoutChanges(spy: QtModelSpy): int =
  spy.calls.filterIt(it.kind == BeginMoveRows).len

proc chip(chainId: int, balance: float, iconUrl = "", chainName = "",
    rawBalance = ""): TokenSelectorChip =
  TokenSelectorChip(chainId: chainId, balance: balance, iconUrl: iconUrl,
    chainName: chainName, rawBalance: rawBalance)

proc mkItem(key: string, name = "", symbol = "", currencyBalance = 0.0,
    currentBalance = 0.0, hasBalance = true, logoUri = "",
    chips: seq[TokenSelectorChip] = @[]): TokenSelectorItem =
  TokenSelectorItem(
    key: key,
    name: if name.len > 0: name else: key,
    symbol: if symbol.len > 0: symbol else: key,
    logoUri: logoUri,
    currentBalance: currentBalance,
    currencyBalance: currencyBalance,
    hasBalance: hasBalance,
    chips: chips)

suite "TokenSelectorModel - sort and sections":

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "owned tokens first, then currencyBalance descending":
    let m = newTokenSelectorModel()
    m.setSectionNames("Your assets on Ethereum", "Popular assets")
    m.setSourceItems(@[
      mkItem("pop1", currencyBalance = 0.0, hasBalance = false),
      mkItem("own1", currencyBalance = 5.0, hasBalance = true),
      mkItem("pop2", currencyBalance = 0.0, hasBalance = false),
      mkItem("own2", currencyBalance = 50.0, hasBalance = true),
    ])
    check m.keysInOrder() == @["own2", "own1", "pop1", "pop2"]
    check m.sectionNameAtForTest(0) == "Your assets on Ethereum"
    check m.sectionNameAtForTest(2) == "Popular assets"

  test "ties preserve source order (no key tiebreak)":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[
      mkItem("z", currencyBalance = 5.0),
      mkItem("a", currencyBalance = 5.0),
    ])
    check m.keysInOrder() == @["z", "a"]

  test "stable-set currencyBalance change: exactly one dataChanged over one row, no reset/move/insert/remove":
    let m = newTokenSelectorModel()
    let chips = @[chip(1, 1.0)]
    m.setSourceItems(@[
      mkItem("a", currencyBalance = 30.0, currentBalance = 10.0, chips = chips),
      mkItem("b", currencyBalance = 20.0, currentBalance = 10.0, chips = chips),
    ])
    spy.clear()

    # b's price rose but it stays second (still below a); chips unchanged.
    m.setSourceItems(@[
      mkItem("a", currencyBalance = 30.0, currentBalance = 10.0, chips = chips),
      mkItem("b", currencyBalance = 25.0, currentBalance = 10.0, chips = chips),
    ])
    check m.keysInOrder() == @["a", "b"]
    check spy.countResets() == 0
    check spy.layoutChanges() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 1
    check spy.dataChangedRows() == 1

  test "currencyBalance change that reorders: remove+insert, no reset/layoutChanged":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[
      mkItem("a", currencyBalance = 3.0),
      mkItem("b", currencyBalance = 2.0),
      mkItem("c", currencyBalance = 1.0),
    ])
    check m.keysInOrder() == @["a", "b", "c"]
    spy.clear()

    m.setSourceItems(@[
      mkItem("a", currencyBalance = 3.0),
      mkItem("b", currencyBalance = 2.0),
      mkItem("c", currencyBalance = 10.0), # jumps to top
    ])
    check m.keysInOrder() == @["c", "a", "b"]
    check spy.countResets() == 0
    check spy.layoutChanges() == 0
    check spy.countInserts() == 1
    check spy.countRemoves() == 1

  test "hasBalance flip moves a row from owned to popular section":
    let m = newTokenSelectorModel()
    m.setSectionNames("Owned", "Popular")
    m.setSourceItems(@[
      mkItem("a", currencyBalance = 5.0, hasBalance = true),
      mkItem("b", currencyBalance = 0.0, hasBalance = false),
    ])
    check m.keysInOrder() == @["a", "b"]
    spy.clear()

    m.setSourceItems(@[
      mkItem("a", currencyBalance = 0.0, hasBalance = false), # loses balance
      mkItem("b", currencyBalance = 0.0, hasBalance = false),
    ])
    check m.sectionNameAtForTest(0) == "Popular"
    check m.sectionNameAtForTest(1) == "Popular"
    check spy.countResets() == 0

  test "add token: single insert, no reset":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[mkItem("a", currencyBalance = 3.0), mkItem("c", currencyBalance = 1.0)])
    spy.clear()
    m.setSourceItems(@[mkItem("a", currencyBalance = 3.0), mkItem("b", currencyBalance = 2.0),
                       mkItem("c", currencyBalance = 1.0)])
    check m.keysInOrder() == @["a", "b", "c"]
    check spy.countInserts() == 1
    check spy.countRemoves() == 0
    check spy.countResets() == 0

  test "remove token: single remove, no reset":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[mkItem("a", currencyBalance = 3.0), mkItem("b", currencyBalance = 2.0),
                       mkItem("c", currencyBalance = 1.0)])
    spy.clear()
    m.setSourceItems(@[mkItem("a", currencyBalance = 3.0), mkItem("c", currencyBalance = 1.0)])
    check m.keysInOrder() == @["a", "c"]
    check spy.countRemoves() == 1
    check spy.countInserts() == 0
    check spy.countResets() == 0

  test "setSectionNames re-emits sectionName for all rows without a reset":
    let m = newTokenSelectorModel()
    m.setSectionNames("Owned", "Popular")
    m.setSourceItems(@[mkItem("a", currencyBalance = 3.0), mkItem("b", currencyBalance = 2.0)])
    spy.clear()
    m.setSectionNames("Your assets on Optimism", "Popular")
    check m.sectionNameAtForTest(0) == "Your assets on Optimism"
    check spy.countDataChanged() == 1
    check spy.dataChangedRows() == 2 # one ranged dataChanged over both rows
    check spy.countResets() == 0

suite "TokenSelectorModel - nested balances submodel":

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "balances submodel exposes the chips joined per chain":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[
      mkItem("eth", chips = @[chip(1, 1.0, "network/ethereum", "Ethereum"),
                              chip(10, 0.5, "network/optimism", "Optimism")]),
    ])
    let bm = m.balancesModelForKey("eth")
    check bm != nil
    check bm.chainIdsInOrder() == @[1, 10]

  test "surviving row keeps the same balances model instance across refresh":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[mkItem("eth", chips = @[chip(1, 1.0)])])
    let bm1 = m.balancesModelForKey("eth")
    m.setSourceItems(@[mkItem("eth", currencyBalance = 9.0, chips = @[chip(1, 1.0)])])
    let bm2 = m.balancesModelForKey("eth")
    check bm1 == bm2 # identity preserved -> QML binding stays alive

  test "removed row drops its nested balances + tokens models (no double-free on teardown)":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[mkItem("a", chips = @[chip(1, 1.0)]),
                       mkItem("b", chips = @[chip(1, 2.0)])])
    check m.balancesModelForKey("b") != nil
    check m.tokensModelForKey("b") != nil
    m.setSourceItems(@[mkItem("a", chips = @[chip(1, 1.0)])]) # b removed
    check m.balancesModelForKey("a") != nil
    check m.balancesModelForKey("b") == nil # dropped from the table -> ORC frees it
    check m.tokensModelForKey("b") == nil

  test "repeated disjoint refreshes free dropped submodels via ORC without a crash":
    # Regression for the delete()-double-free: the nested models are new(_, delete),
    # so dropping them from the tables must let ORC run their finalizers exactly
    # once. Churn fully-disjoint key sets so every refresh frees the previous
    # submodels mid-life, then confirm the survivors are intact.
    let m = newTokenSelectorModel()
    for i in 0 ..< 20:
      m.setSourceItems(@[
        mkItem("k" & $i & "a", chips = @[chip(1, 1.0)]),
        mkItem("k" & $i & "b", chips = @[chip(10, 2.0)]),
      ])
      check m.balancesModelForKey("k" & $i & "a") != nil
      if i > 0:
        check m.balancesModelForKey("k" & $(i-1) & "a") == nil
    check m.keysInOrder().len == 2

  test "removed row's balances submodel outlives the parent remove signal (no UAF)":
    # balancesByKey is the dropped child's SOLE ORC owner, and a nimqml QVariant of
    # a QObject keeps only the raw C++ pointer. If reconcileByKey frees the child
    # before modelSync emits beginRemoveRows, the delegate's inner ListView derefs
    # freed memory while tearing its own row down. Assert the child is destroyed
    # only AFTER the remove signal fired.
    # ORC-gated: free order is deterministic only under --mm:orc (the production
    # mm). Run via `make nim-test-run-orc/test/nim/token_selector_model_test.nim`;
    # the refc suite reports this as skipped.
    when defined(gcOrc):
      let m = newTokenSelectorModel()
      # b's chip carries a sentinel raw balance so the delete hook recognises it by
      # VALUE — capturing a ref (even via cast[int]) would keep it ORC-alive and
      # mask the very free we want to observe.
      m.setSourceItems(@[mkItem("a", chips = @[chip(1, 1.0, rawBalance = "1")]),
                         mkItem("b", chips = @[chip(1, 2.0, rawBalance = "777")])])

      var removesWhenBFreed = -1
      onTokenSelectorBalancesModelDeleted = proc(bm: TokenSelectorBalancesModel) =
        if bm.rawBalancesInOrder() == @["777"]:
          removesWhenBFreed = spy.countRemoves()

      spy.clear()
      m.setSourceItems(@[mkItem("a", chips = @[chip(1, 1.0, rawBalance = "1")])])
      onTokenSelectorBalancesModelDeleted = nil

      check spy.countRemoves() == 1
      check removesWhenBFreed == 1  # freed after the remove, never at 0
    else:
      skip()

  test "chip balance change travels through the nested model as a dataChanged":
    let m = newTokenSelectorModel()
    m.setSourceItems(@[mkItem("eth", currentBalance = 1.0, currencyBalance = 1.0,
                              chips = @[chip(1, 1.0)])])
    let bm = m.balancesModelForKey("eth")
    spy.clear()
    m.setSourceItems(@[mkItem("eth", currentBalance = 2.0, currencyBalance = 2.0,
                              chips = @[chip(1, 2.0)])])
    check bm.chainIdsInOrder() == @[1]
    check spy.countResets() == 0
    check spy.countDataChanged() >= 1 # nested chip dataChanged (+ parent balance roles)

suite "TokenSelectorModel - producer-driven recompute":

  let networks = @[NetworkInfo(chainId: 1, chainName: "Ethereum", iconUrl: "net/eth")]

  proc ownedGroup(key: string, account: string, chainId: int, wei: string,
      price = 0.0): AggTokenGroup =
    AggTokenGroup(key: key, name: key, symbol: key, decimals: 18, marketPrice: price,
      balances: @[AggBalance(account: account, chainId: chainId, balance: parse(wei, UInt256))])

  test "Owned mode: setOwnedSource derives owned rows through the builder":
    let m = newTokenSelectorModel(TokenSelectorMode.Owned)
    m.setOwnedSource(@[
      ownedGroup("ETH", "0xA", 1, "1000000000000000000", price = 2.0),
      ownedGroup("SNT", "0xA", 1, "5000000000000000000", price = 1.0),
    ], networks)
    check m.keysInOrder() == @["SNT", "ETH"] # SNT fiat 5 > ETH fiat 2

  test "setAccountAddress recomputes and filters other accounts out":
    let m = newTokenSelectorModel(TokenSelectorMode.Owned)
    m.setOwnedSource(@[
      ownedGroup("ETH", "0xB", 1, "1000000000000000000", price = 2.0),
    ], networks)
    check m.keysInOrder() == @["ETH"]
    m.setAccountAddress("0xA") # 0xB balance now excluded -> ETH drops out
    check m.keysInOrder().len == 0

  test "AllTokens mode: popular source merged with owned on recompute":
    let m = newTokenSelectorModel(TokenSelectorMode.AllTokens)
    var source: TokenSelectorSource
    source.getPopular = proc(): seq[PopularGroup] =
      @[PopularGroup(key: "ETH", name: "ETH", symbol: "ETH"),
        PopularGroup(key: "DAI", name: "DAI", symbol: "DAI")]
    m.setSource(source)
    m.setOwnedSource(@[ownedGroup("ETH", "0xA", 1, "1000000000000000000", price = 2.0)], networks)
    check m.keysInOrder() == @["ETH", "DAI"] # owned ETH first, popular DAI after
    check m.balancesModelForKey("ETH") != nil

  test "search routes through the search source; clearing restores the list":
    let m = newTokenSelectorModel(TokenSelectorMode.AllTokens)
    var source: TokenSelectorSource
    source.getPopular = proc(): seq[PopularGroup] =
      @[PopularGroup(key: "ETH", name: "ETH", symbol: "ETH")]
    source.getSearch = proc(): seq[PopularGroup] =
      @[PopularGroup(key: "DAI", name: "DAI", symbol: "DAI")]
    m.setSource(source)
    m.setOwnedSource(@[], networks)
    check m.keysInOrder() == @["ETH"]
    m.search("da")
    check m.keysInOrder() == @["DAI"]
    m.search("")
    check m.keysInOrder() == @["ETH"]

  test "tokens submodel exposes per-chain token refs for a row":
    let m = newTokenSelectorModel(TokenSelectorMode.Owned)
    var g = AggTokenGroup(key: "ETH", name: "ETH", symbol: "ETH", decimals: 18,
      marketPrice: 1.0,
      balances: @[AggBalance(account: "0xA", chainId: 1, balance: parse("1000000000000000000", UInt256))])
    g.tokens = @[(key: "eth:1", chainId: 1), (key: "eth:10", chainId: 10)]
    m.setOwnedSource(@[g], networks)
    let tm = m.tokensModelForKey("ETH")
    check tm != nil
    check tm.tokenRefs() == @[TokenSelectorTokenRef(key: "eth:1", chainId: 1),
                              TokenSelectorTokenRef(key: "eth:10", chainId: 10)]

  test "item decimals and chip rawBalance surface through the producer path (send needs)":
    let m = newTokenSelectorModel(TokenSelectorMode.Owned)
    let g = AggTokenGroup(key: "USDC", name: "USDC", symbol: "USDC", decimals: 6,
      marketPrice: 1.0,
      balances: @[AggBalance(account: "0xA", chainId: 1, balance: parse("1500000", UInt256))])
    m.setOwnedSource(@[g], networks)
    check m.decimalsAtForTest(0) == 6
    let bm = m.balancesModelForKey("USDC")
    check bm != nil
    check bm.rawBalancesInOrder() == @["1500000"]

  test "cryptoPrice role surfaces the per-token market price (swap needs)":
    let m = newTokenSelectorModel(TokenSelectorMode.Owned)
    let g = AggTokenGroup(key: "ETH", name: "ETH", symbol: "ETH", decimals: 18,
      marketPrice: 3500.0,
      balances: @[AggBalance(account: "0xA", chainId: 1, balance: parse("1000000000000000000", UInt256))])
    m.setOwnedSource(@[g], networks)
    check m.cryptoPriceAtForTest(0) == 3500.0

  test "swap chain-scoped popular yields one token per group (SwapInputPanel count==1)":
    # swap's popular list is tokenGroupsForChModel built for the selected chain, so
    # each merged row's tokens submodel must carry exactly one token ref.
    let m = newTokenSelectorModel(TokenSelectorMode.AllTokens)
    var source: TokenSelectorSource
    source.getPopular = proc(): seq[PopularGroup] =
      @[PopularGroup(key: "ETH", name: "ETH", symbol: "ETH",
          tokens: @[(key: "eth:1", chainId: 1)])]
    m.setSource(source)
    m.setEnabledChainId(1)
    m.setOwnedSource(@[], networks)
    let tm = m.tokensModelForKey("ETH")
    check tm != nil
    check tm.tokenRefs().len == 1

  test "hasMoreItems / isLoadingMore passthrough to the active lazy source":
    let m = newTokenSelectorModel(TokenSelectorMode.AllTokens)
    var source: TokenSelectorSource
    source.hasMore = proc(searching: bool): bool = not searching
    source.isLoadingMore = proc(searching: bool): bool = searching
    source.getSearch = proc(): seq[PopularGroup] = @[]
    m.setSource(source)
    m.setOwnedSource(@[], networks)
    check m.getHasMoreItems()      # not searching -> hasMore true
    check not m.getIsLoadingMore()
    m.search("x")
    check not m.getHasMoreItems()  # searching -> hasMore false
    check m.getIsLoadingMore()
