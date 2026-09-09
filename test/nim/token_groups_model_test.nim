## Conversion tests for token_groups_model (setItemsWithSync + Table-keyed
## market details). Compile with -d:QT_MODEL_SPY.
##
## Covers the acceptance gate: identity preservation of MarketDetailsItem across
## insert+remove+reorder; reorder read-back (remove+insert, no moves) + no reset;
## stable-set refresh emits no reset / no move / no spurious churn.

import unittest, tables, sequtils, strutils
import nimqml

import app/modules/main/wallet_section/all_tokens/token_groups_model
import app/modules/main/wallet_section/all_tokens/tokens_model
import app/modules/main/wallet_section/all_tokens/io_interface
import app/modules/main/wallet_section/all_tokens/market_details_item
import app/modules/shared/qt_model_spy
import app_service/service/token/items/token_group

var gGroups: seq[TokenGroupItem] = @[]

proc groupsDataSource(): TokenGroupsModelDataSource =
  (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = gGroups,
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

proc mkGroup(key: string, name: string = ""): TokenGroupItem =
  let tok = createTokenItem(TokenDto(
    chainId: 1, address: "0x" & key, crossChainId: key,
    name: (if name.len > 0: name else: key), symbol: key, decimals: 18))
  TokenGroupItem(
    key: key, name: (if name.len > 0: name else: key), symbol: key,
    decimals: 18, logoUri: "", tokens: @[tok])

proc newModel(): TokenGroupsModel =
  newTokenGroupsModel(groupsDataSource(), marketValuesDataSource())

proc moves(spy: QtModelSpy): int = spy.calls.filterIt(it.kind == BeginMoveRows).len

proc mkGroup2(key: string): TokenGroupItem =
  ## Group with TWO tokens, distinguishable from mkGroup's one via rowCount.
  result = mkGroup(key)
  result.tokens.add(createTokenItem(TokenDto(
    chainId: 10, address: "0x2" & key, crossChainId: key,
    name: key, symbol: key, decimals: 18)))

proc tokensRole(m: TokenGroupsModel): int =
  for k, v in m.roleNames():
    if v == "tokens": return k
  doAssert false, "tokens role not found"

proc readTokensRole(m: TokenGroupsModel, row: int) =
  ## Read the tokens role through data(), the way the Qt view layer does.
  let idx = m.createIndex(row, 0, nil)
  defer: idx.delete
  let v = m.data(idx, m.tokensRole())
  if not v.isNil: v.delete

suite "token_groups_model - identity, reorder, stable-set":

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "MarketDetailsItem identity preserved across insert+remove+reorder":
    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c")]
    let m = newModel()
    m.modelsUpdated()
    let mdA = m.marketDetailsItemForKey("a")
    let mdB = m.marketDetailsItemForKey("b")
    check not mdA.isNil
    check not mdB.isNil

    # remove c, insert x, reorder survivors -> [b, x, a]
    gGroups = @[mkGroup("b"), mkGroup("x"), mkGroup("a")]
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["b", "x", "a"]     # order matches target
    check m.marketDetailsItemForKey("a") == mdA        # SAME instance (identity)
    check m.marketDetailsItemForKey("b") == mdB        # SAME instance
    check m.marketDetailsItemForKey("c").isNil         # removed key dropped
    check not m.marketDetailsItemForKey("x").isNil     # new key -> new object
    check m.marketDetailsItemForKey("x") != mdA        # not an aliased survivor

    # market-values signal path must still find/update objects by key post-reorder
    m.tokensMarketValuesUpdated()
    check m.marketDetailsItemForKey("a") == mdA

  test "surviving group whose representative token changes updates MarketDetailsItem.tokenKey":
    # priceForTokenGroup picks the FIRST token with price>0 as the group's market
    # representative. reconcileByKey keeps a survivor's MarketDetailsItem instance;
    # if it does not refresh the stored representative tokenKey, tokensMarketValuesUpdated
    # later fetches price/values for the STALE representative -> wrong market data on a
    # surviving row. The tokenKey must follow the new representative.
    let t1 = createTokenItem(TokenDto(chainId: 1, address: "0xt1", crossChainId: "g",
      name: "g", symbol: "g", decimals: 18))
    let t2 = createTokenItem(TokenDto(chainId: 1, address: "0xt2", crossChainId: "g",
      name: "g", symbol: "g", decimals: 18))
    proc mkTwoTokenGroup(): TokenGroupItem =
      TokenGroupItem(key: "g", name: "g", symbol: "g", decimals: 18, logoUri: "",
        tokens: @[t1, t2])

    var prices = initTable[string, float64]()
    prices[t1.key] = 0.0      # t1 unpriced -> representative is t2
    prices[t2.key] = 5.0
    proc mvSource(): TokenMarketValuesDataSource =
      (
        getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem = default(TokenMarketValuesItem),
        getPriceForToken: proc(tokenKey: string): float64 = prices.getOrDefault(tokenKey, 0.0),
        getCurrentCurrencyFormat: proc(): CurrencyFormatDto = default(CurrencyFormatDto),
        getTokensMarketValuesLoading: proc(): bool = false,
      )

    gGroups = @[mkTwoTokenGroup()]
    let m = newTokenGroupsModel(groupsDataSource(), mvSource())
    m.modelsUpdated()
    check m.marketDetailsItemForKey("g").tokenKey == t2.key   # first priced = t2

    # t1 gains a price -> it becomes the representative for the SAME surviving key.
    prices[t1.key] = 10.0
    gGroups = @[mkTwoTokenGroup()]
    m.modelsUpdated()
    check m.marketDetailsItemForKey("g").tokenKey == t1.key   # rep must follow to t1

  test "reorder (hash-order change): reads back in target order, remove+insert, no move, no reset":
    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c"), mkGroup("d")]
    let m = newModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("d"), mkGroup("c"), mkGroup("b"), mkGroup("a")]
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["d", "c", "b", "a"]
    check spy.moves() == 0
    check spy.countResets() == 0
    check spy.countInserts() > 0
    check spy.countRemoves() > 0

  test "stable set, no metadata change: no reset, no move, no churn":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a"), mkGroup("b")]  # same keys, same order, same metadata
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["a", "b"]
    check spy.countResets() == 0
    check spy.moves() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 0  # TokenItem has no balance -> truly no-op

  test "metadata change on one group: dataChanged for that row only, no reset/move":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a", name = "Renamed"), mkGroup("b")]
    m.modelsUpdated()

    check spy.countDataChanged() > 0
    check spy.countResets() == 0
    check spy.moves() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0

  test "pure add and pure remove":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c")]  # add (sorted source order)
    m.modelsUpdated()
    check spy.countInserts() == 1
    check spy.moves() == 0     # deterministic source order -> survivors don't reshuffle
    check spy.countResets() == 0

    spy.clear()
    gGroups = @[mkGroup("a"), mkGroup("c")]  # remove b
    m.modelsUpdated()
    check spy.countRemoves() == 1
    check spy.moves() == 0     # pure remove, no reshuffle
    check spy.countResets() == 0
    check m.marketDetailsItemForKey("b").isNil

  test "F1: group-set grows -> every row incl the new ones has market details (no empty window)":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c"), mkGroup("d")]  # set grows
    m.modelsUpdated()

    check spy.countInserts() > 0
    check spy.countResets() == 0
    # Every displayed row — including the newly inserted c, d — must have its
    # market-details key present. F1 fix builds the keys BEFORE setItemsWithSync
    # announces the inserts, so data(MarketDetails) is populated for a new row
    # within this same modelsUpdated call rather than empty until a later signal.
    for key in m.groupKeysInOrder():
      check not m.marketDetailsItemForKey(key).isNil

suite "token_groups_model - tokens submodel lifetime":
  ## QML consumers (ModelEntry item maps, delegates) cache the QObject pointer
  ## returned for the "tokens" role. Destroying a previously handed-out submodel
  ## on a later data() read leaves those consumers with a dangling pointer —
  ## the send-modal network-switch UAF crash (rowCount on freed Nim object).

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "re-reading the tokens role never destroys a previously handed-out submodel":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()

    let before = tokensModelDeleteCount
    m.readTokensRole(0)   # hand out row a's submodel (QML caches the pointer)
    m.readTokensRole(1)   # reading another row must not kill row a's submodel
    m.readTokensRole(0)   # re-reading the same row must not kill row b's either
    check tokensModelDeleteCount == before

  test "same submodel instance handed out for the same group across reads and refreshes":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()

    let subA = m.ensureTokensSubmodel("a")
    m.readTokensRole(0)                       # data() must reuse, not re-create
    check m.ensureTokensSubmodel("a") == subA

    gGroups = @[mkGroup("a"), mkGroup("b")]   # stable refresh
    m.modelsUpdated()
    check m.ensureTokensSubmodel("a") == subA

  test "submodel follows its group key when rows shift, not its creation index":
    gGroups = @[mkGroup("a"), mkGroup2("b")]
    let m = newModel()
    m.modelsUpdated()

    let subB = m.ensureTokensSubmodel("b")
    check subB.rowCount(nil) == 2

    gGroups = @[mkGroup2("b"), mkGroup("a")]  # b moves to row 0
    m.modelsUpdated()
    check subB.rowCount(nil) == 2
    check m.ensureTokensSubmodel("a").rowCount(nil) == 1

  test "removed group's submodel is deleted after the remove; a returning key gets a fresh one":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()

    discard m.ensureTokensSubmodel("a")
    let before = tokensModelDeleteCount

    gGroups = @[mkGroup("b")]
    m.modelsUpdated()
    # Row gone -> its submodel is dropped and destroyed (consumers were notified
    # by the remove signals and detach via destroyed()).
    check tokensModelDeleteCount == before + 1

    gGroups = @[mkGroup("b"), mkGroup("a")]
    m.modelsUpdated()
    check m.ensureTokensSubmodel("a").rowCount(nil) == 1   # fresh instance

  test "submodel resets only on content change, never on a stable refresh":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newModel()
    m.modelsUpdated()
    discard m.ensureTokensSubmodel("a")

    var before = tokensModelResetCount
    gGroups = @[mkGroup("a"), mkGroup("b")]   # stable
    m.modelsUpdated()
    check tokensModelResetCount == before

    before = tokensModelResetCount
    gGroups = @[mkGroup2("a"), mkGroup("b")]  # a's token set changes
    m.modelsUpdated()
    check tokensModelResetCount == before + 1 # exactly the submodel's own reset

suite "token_groups_model - lazy pagination with pinned rows":

  proc newLazyModel(batch = 10, initial = 10): TokenGroupsModel =
    newTokenGroupsModel(groupsDataSource(), marketValuesDataSource(),
      modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading],
      lazyLoadingBatchSize = batch, lazyLoadingInitialCount = initial)

  proc seedSource(count: int) =
    gGroups = @[]
    for i in 0 ..< count:
      gGroups.add(mkGroup("k" & $(100 + i)))  # k100.. keeps keys same-width

  proc paginateToExhaustion(m: TokenGroupsModel): int =
    ## Fetches until the model reports no more items; returns the number of
    ## fetch rounds. Bounded and break-on-stall (unittest's `check` records a
    ## failure but keeps executing, so it must never be the loop's only exit):
    ## a regression fails the callers' `not hasMoreItemsForSource()` assertion
    ## promptly instead of hanging the test run.
    const maxRounds = 20
    while m.hasMoreItemsForSource() and result < maxRounds:
      let before = m.getLoadedGroups().len
      m.fetchMore()
      result.inc
      let progressed = m.getLoadedGroups().len > before
      check progressed                      # a stalled round is a regression
      if not progressed:
        break
    check result < maxRounds                # and so is never finishing

  test "pinning a row beyond page one doesn't skip or duplicate source rows":
    seedSource(25)
    let m = newLazyModel()
    m.modelsUpdated(resetModelSize = true)
    check m.getLoadedGroups().len == 10

    # pin a row from the third page (ensureKeyLoaded path)
    check m.ensureKeyLoaded("k122")
    check m.getLoadedGroups().len == 11

    discard m.paginateToExhaustion()

    let keys = m.getLoadedGroups().mapIt(it.key)
    check keys.len == 25                       # nothing skipped
    check keys.deduplicate().len == 25         # nothing inserted twice
    check not m.hasMoreItemsForSource()        # and it terminates for good

  test "mandatory keys beyond page one paginate to full coverage too":
    seedSource(25)
    let m = newLazyModel()
    m.modelsUpdated(resetModelSize = true, mandatoryKeys = @["k123", "k110"])

    discard m.paginateToExhaustion()

    let keys = m.getLoadedGroups().mapIt(it.key)
    check keys.len == 25
    check keys.deduplicate().len == 25
    check not m.hasMoreItemsForSource()

  test "a pinned last row still lets pagination finish exactly once":
    seedSource(11)
    let m = newLazyModel()
    m.modelsUpdated(resetModelSize = true)
    check m.ensureKeyLoaded("k110")            # the single row of page two
    check not m.hasMoreItemsForSource()        # everything is loaded already
    m.fetchMore()                              # must be a clean no-op
    check m.getLoadedGroups().len == 11

suite "token_groups_model - search by contract address":

  # Cross-chain group: the group key ("usd-coin") does NOT embed the contract
  # address, so these only pass when the search matches the per-token
  # address fields, not just key/name/symbol.
  const usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # mixed case on purpose
  # the group's chain-10 deployment: a DIFFERENT contract under the same group
  const usdcOptimismAddress = "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"

  proc mkGroupAt(key, address, name, symbol: string): TokenGroupItem =
    let tok = createTokenItem(TokenDto(
      chainId: 1, address: address, crossChainId: key,
      name: name, symbol: symbol, decimals: 18))
    TokenGroupItem(key: key, name: name, symbol: symbol,
      decimals: 18, logoUri: "", tokens: @[tok])

  proc withDeployment(group: TokenGroupItem, chainId: int,
      address: string): TokenGroupItem =
    group.tokens.add(createTokenItem(TokenDto(
      chainId: chainId, address: address, crossChainId: group.key,
      name: group.name, symbol: group.symbol, decimals: 18)))
    group

  proc newSearchModel(): TokenGroupsModel =
    gGroups = @[
      mkGroupAt("usd-coin", usdcAddress, "USD Coin", "USDC")
        .withDeployment(10, usdcOptimismAddress),
      mkGroupAt("dai", "0x6B175474E89094C44Da98b954EedeAC495271d0F", "Dai", "DAI"),
    ]
    newTokenGroupsModel(groupsDataSource(), marketValuesDataSource(),
      modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading, ModelMode.IsSearchResult],
      lazyLoadingBatchSize = 10, lazyLoadingInitialCount = 10)

  proc resultKeys(m: TokenGroupsModel): seq[string] =
    m.getLoadedGroups().mapIt(it.key)

  test "a full address matches regardless of case and 0x prefix":
    let m = newSearchModel()
    m.search(usdcAddress)                          # as pasted (mixed case)
    check m.resultKeys() == @["usd-coin"]
    m.search(usdcAddress.toUpperAscii())           # 0X + uppercase
    check m.resultKeys() == @["usd-coin"]
    m.search(usdcAddress[2 .. ^1].toLowerAscii())  # no prefix, lowercase
    check m.resultKeys() == @["usd-coin"]

  test "a partial address matches, prefixed or bare":
    let m = newSearchModel()
    m.search("0xa0b86991")     # address prefix, 0x kept
    check m.resultKeys() == @["usd-coin"]
    m.search("eb0ce36")        # a slice from the middle, no 0x
    check m.resultKeys() == @["usd-coin"]
    m.search("0xa0b")          # explicit 0x allows even a short needle
    check m.resultKeys() == @["usd-coin"]

  test "short or non-hex keywords never match through the address":
    let m = newSearchModel()
    m.search("a0b")            # 3 bare hex digits: too ambiguous
    check m.resultKeys().len == 0
    m.search("0xnothex")
    check m.resultKeys().len == 0

  test "an address hit doesn't shadow ordinary text matches":
    let m = newSearchModel()
    m.search("dai")            # plain symbol/name search still works
    check m.resultKeys() == @["dai"]

  test "an address match narrows the result to the matched deployment":
    # the usd-coin group holds DIFFERENT contracts on chain 1 and chain 10 —
    # a searched address identifies one deployment, not the whole group,
    # so a chain-scoped consumer can never resolve it to the other contract
    let m = newSearchModel()
    m.search(usdcAddress)
    check m.resultKeys() == @["usd-coin"]
    var tokens = m.getLoadedGroups()[0].tokens
    check tokens.len == 1
    check tokens[0].chainId == 1
    check tokens[0].address == usdcAddress

    m.search(usdcOptimismAddress)
    check m.resultKeys() == @["usd-coin"]
    tokens = m.getLoadedGroups()[0].tokens
    check tokens.len == 1
    check tokens[0].chainId == 10
    check tokens[0].address == usdcOptimismAddress

    # and the narrowing never touches the catalog's own group
    check gGroups[0].tokens.len == 2

  test "a text match keeps every deployment of the group":
    let m = newSearchModel()
    m.search("usd coin")
    check m.resultKeys() == @["usd-coin"]
    check m.getLoadedGroups()[0].tokens.len == 2
