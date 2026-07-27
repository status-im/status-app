## Unit tests for buildTokenSelectorItems — the pure aggregation core that turns
## the raw token groups (+ per-(account, chain) balances) and the picker's
## account/chain/visibility params into the flat seq[TokenSelectorItem] consumed
## by TokenSelectorModel. Mirrors TokenSelectorViewAdaptor's per-group
## ObjectProxyModel subgraph (balance filter + SumAggregator + network join).
##
## Qt-free: run with `nim c -r test/nim/token_selector_builder_test.nim`.

import unittest, sequtils, algorithm
import stint

import app/modules/shared_models/token_selector_builder
import app/modules/shared_models/assets_aggregator

proc bal(account: string, chainId: int, wei: string, loading = false): AggBalance =
  AggBalance(account: account, chainId: chainId, balance: parse(wei, UInt256), loading: loading)

proc group(key: string, symbol = "", decimals = 18, visible = true,
    communityId = "", price = 0.0, logoUri = "", name = "",
    balances: seq[AggBalance] = @[]): AggTokenGroup =
  AggTokenGroup(
    key: key, name: if name.len > 0: name else: key,
    symbol: if symbol.len > 0: symbol else: key,
    logoUri: logoUri, decimals: decimals, communityId: communityId,
    marketPrice: price, marketChangePct24hour: 0.0,
    marketDetailsLoading: false, visible: visible, position: 0,
    balances: balances)

let networks = @[
  NetworkInfo(chainId: 1, chainName: "Ethereum", iconUrl: "network/ethereum"),
  NetworkInfo(chainId: 10, chainName: "Optimism", iconUrl: "network/optimism"),
  NetworkInfo(chainId: 42161, chainName: "Arbitrum", iconUrl: "network/arbitrum"),
]

proc noFilterParams(): TokenSelectorParams =
  TokenSelectorParams(accountAddress: "", enabledChainIds: @[],
    showZeroBalanceForDefaultTokens: false, showCommunityAssets: false)

proc findItem(items: seq[TokenSelectorItem], key: string): TokenSelectorItem =
  for it in items:
    if it.key == key: return it
  raise newException(KeyError, "no item " & key)

suite "buildTokenSelectorItems — aggregation":
  test "sums filtered balances across chains and converts by decimals":
    let g = group("ETH", price = 2.0, balances = @[
      bal("0xA", 1, "1000000000000000000"),   # 1.0
      bal("0xA", 10, "500000000000000000"),   # 0.5
    ])
    let items = buildTokenSelectorItems(@[g], networks, noFilterParams())
    check items.len == 1
    let it = items.findItem("ETH")
    check it.currentBalance == 1.5
    check it.currencyBalance == 3.0        # 1.5 * 2.0
    check it.hasBalance

  test "account filter excludes other accounts' balances":
    let g = group("ETH", balances = @[
      bal("0xA", 1, "1000000000000000000"),
      bal("0xB", 1, "9000000000000000000"),
    ])
    var p = noFilterParams()
    p.accountAddress = "0xa"                # case-insensitive
    let items = buildTokenSelectorItems(@[g], networks, p)
    check items.findItem("ETH").currentBalance == 1.0
    check items.findItem("ETH").chips.len == 1

  test "chain filter excludes non-enabled chains":
    let g = group("ETH", balances = @[
      bal("0xA", 1, "1000000000000000000"),
      bal("0xA", 10, "2000000000000000000"),
    ])
    var p = noFilterParams()
    p.enabledChainIds = @[1]
    let items = buildTokenSelectorItems(@[g], networks, p)
    check items.findItem("ETH").currentBalance == 1.0
    check items.findItem("ETH").chips.mapIt(it.chainId) == @[1]

  test "zero-balance chip dropped by default":
    let g = group("SNT", balances = @[
      bal("0xA", 1, "0"),
      bal("0xA", 10, "3000000000000000000"),
    ])
    let items = buildTokenSelectorItems(@[g], networks, noFilterParams())
    check items.findItem("SNT").chips.len == 1
    check items.findItem("SNT").currentBalance == 3.0

  test "zero-balance chip kept when showZeroBalanceForDefaultTokens":
    let g = group("SNT", balances = @[
      bal("0xA", 1, "0"),
      bal("0xA", 10, "0"),
    ])
    var p = noFilterParams()
    p.showZeroBalanceForDefaultTokens = true
    let items = buildTokenSelectorItems(@[g], networks, p)
    let it = items.findItem("SNT")
    check it.chips.len == 2
    check it.currentBalance == 0.0
    check not it.hasBalance                # currentBalance 0 -> popular section

  test "group with no surviving balances is dropped":
    let g = group("ZERO", balances = @[bal("0xA", 1, "0")])
    let items = buildTokenSelectorItems(@[g], networks, noFilterParams())
    check items.len == 0

  test "group with no balances at all is dropped":
    let g = group("EMPTY")
    let items = buildTokenSelectorItems(@[g], networks, noFilterParams())
    check items.len == 0

suite "buildTokenSelectorItems — chips join with networks":
  test "each surviving balance becomes a chip with network icon and name":
    let g = group("ETH", balances = @[
      bal("0xA", 10, "500000000000000000"),   # 0.5 Optimism
      bal("0xA", 1, "1000000000000000000"),   # 1.0 Ethereum
    ])
    let chips = buildTokenSelectorItems(@[g], networks, noFilterParams()).findItem("ETH").chips
    check chips.len == 2
    # chips sorted by balance descending (biggest sub-balance first, as in QML)
    check chips[0].chainId == 1
    check chips[0].balance == 1.0
    check chips[0].iconUrl == "network/ethereum"
    check chips[0].chainName == "Ethereum"
    check chips[1].chainId == 10
    check chips[1].balance == 0.5

  test "chip carries the raw wei balance string and the item carries decimals":
    # send reads the picker chip's raw wei (AmountsArithmetic.fromString) together
    # with the item's decimals to reconstruct the on-chain max.
    let g = group("USDC", decimals = 6, balances = @[bal("0xA", 1, "1500000")]) # 1.5 USDC
    let it = buildTokenSelectorItems(@[g], networks, noFilterParams()).findItem("USDC")
    check it.decimals == 6
    check it.chips.len == 1
    check it.chips[0].rawBalance == "1500000"
    check it.chips[0].balance == 1.5

  test "chip for an unknown network has empty icon/name but keeps the balance":
    let g = group("ETH", balances = @[bal("0xA", 999, "1000000000000000000")])
    let chips = buildTokenSelectorItems(@[g], networks, noFilterParams()).findItem("ETH").chips
    check chips.len == 1
    check chips[0].chainId == 999
    check chips[0].iconUrl == ""
    check chips[0].chainName == ""
    check chips[0].balance == 1.0

suite "buildTokenSelectorItems — community and passthrough":
  test "community group dropped unless showCommunityAssets":
    let g = group("CT", communityId = "comm1", balances = @[bal("0xA", 1, "1000000000000000000")])
    check buildTokenSelectorItems(@[g], networks, noFilterParams()).len == 0
    var p = noFilterParams()
    p.showCommunityAssets = true
    check buildTokenSelectorItems(@[g], networks, p).len == 1

  test "carries name/symbol/logoUri/communityId through":
    let g = group("ETH", symbol = "ETH", name = "Ethereum", logoUri = "logo/eth",
      balances = @[bal("0xA", 1, "1000000000000000000")])
    let it = buildTokenSelectorItems(@[g], networks, noFilterParams()).findItem("ETH")
    check it.name == "Ethereum"
    check it.symbol == "ETH"
    check it.logoUri == "logo/eth"
    check it.communityId == ""

  test "carries per-chain token refs through (buy provider filter input)":
    var g = group("ETH", balances = @[bal("0xA", 1, "1000000000000000000")])
    g.tokens = @[(key: "eth:1", chainId: 1), (key: "eth:10", chainId: 10)]
    let it = buildTokenSelectorItems(@[g], networks, noFilterParams()).findItem("ETH")
    check it.tokens == @[TokenSelectorTokenRef(key: "eth:1", chainId: 1),
                         TokenSelectorTokenRef(key: "eth:10", chainId: 10)]

  test "merge path takes token refs from the popular side":
    let merged = mergePopularWithOwned(
      @[PopularGroup(key: "DAI", name: "DAI", symbol: "DAI",
        tokens: @[(key: "dai:1", chainId: 1)])],
      @[], showCommunityAssets = false)
    check merged.findItem("DAI").tokens == @[TokenSelectorTokenRef(key: "dai:1", chainId: 1)]

proc popular(key: string, name = "", symbol = "", logoUri = "", communityId = ""): PopularGroup =
  PopularGroup(key: key, name: if name.len > 0: name else: key,
    symbol: if symbol.len > 0: symbol else: key, logoUri: logoUri, communityId: communityId)

suite "mergePopularWithOwned — all-tokens / search path":
  test "popular token the user owns is enriched with the owned balance data":
    let owned = buildTokenSelectorItems(@[
      group("ETH", price = 2.0, balances = @[bal("0xA", 1, "1000000000000000000")]) # 1.0, fiat 2.0
    ], networks, noFilterParams())
    let merged = mergePopularWithOwned(
      @[popular("ETH", name = "Ethereum", logoUri = "logo/eth"), popular("DAI")],
      owned, showCommunityAssets = false)
    check merged.mapIt(it.key) == @["ETH", "DAI"]
    let eth = merged.findItem("ETH")
    check eth.currentBalance == 1.0
    check eth.currencyBalance == 2.0
    check eth.hasBalance
    check eth.chips.len == 1
    check eth.decimals == 18               # decimals come from the owned side
    check eth.marketPrice == 2.0           # price from the owned side
    check eth.name == "Ethereum"          # popular's metadata wins
    check eth.logoUri == "logo/eth"

  test "popular token the user does not own becomes a zero-balance popular item":
    let merged = mergePopularWithOwned(@[popular("DAI", name = "Dai")], @[], showCommunityAssets = false)
    let dai = merged.findItem("DAI")
    check dai.currentBalance == 0.0
    check not dai.hasBalance
    check dai.chips.len == 0
    check dai.name == "Dai"

  test "row set follows the popular list, not the owned list":
    # an owned token absent from the popular list does not appear (search filters it out)
    let owned = buildTokenSelectorItems(@[
      group("ETH", balances = @[bal("0xA", 1, "1000000000000000000")])
    ], networks, noFilterParams())
    let merged = mergePopularWithOwned(@[popular("DAI")], owned, showCommunityAssets = false)
    check merged.mapIt(it.key) == @["DAI"]

  test "non-owned popular token carries its own market price":
    let merged = mergePopularWithOwned(
      @[PopularGroup(key: "DAI", name: "DAI", symbol: "DAI", marketPrice: 0.99)],
      @[], showCommunityAssets = false)
    check merged.findItem("DAI").marketPrice == 0.99

  test "non-owned popular token carries its own decimals":
    # The amount input reads `decimals` to scale what the user types; a 6-decimal
    # token defaulting to 0 (and then to QML's 18 fallback) sends a wrong magnitude.
    let merged = mergePopularWithOwned(
      @[PopularGroup(key: "USDC", name: "USDC", symbol: "USDC", decimals: 6)],
      @[], showCommunityAssets = false)
    check merged.findItem("USDC").decimals == 6

  test "community popular token dropped unless showCommunityAssets":
    let p = @[popular("CT", communityId = "comm1")]
    check mergePopularWithOwned(p, @[], showCommunityAssets = false).len == 0
    check mergePopularWithOwned(p, @[], showCommunityAssets = true).len == 1

suite "buildDisplayItems — path selection":
  let ownedGroups = @[
    group("ETH", price = 2.0, balances = @[bal("0xA", 1, "1000000000000000000")]), # owned 1.0 -> fiat 2.0
    group("SNT", price = 1.0, balances = @[bal("0xA", 1, "5000000000000000000")]), # owned 5.0
  ]

  test "Owned mode, no search: exactly the owned tokens":
    let items = buildDisplayItems(ownedGroups, networks, noFilterParams(),
      TokenSelectorMode.Owned, searchActive = false, popularGroups = @[], searchGroups = @[])
    check items.mapIt(it.key).sorted == @["ETH", "SNT"]
    check items.findItem("ETH").currencyBalance == 2.0

  test "Owned mode ignores popularGroups (send never shows the all-tokens list)":
    let items = buildDisplayItems(ownedGroups, networks, noFilterParams(),
      TokenSelectorMode.Owned, searchActive = false,
      popularGroups = @[popular("DAI")], searchGroups = @[])
    check items.mapIt(it.key).sorted == @["ETH", "SNT"]

  test "AllTokens mode: popular list merged with owned balances":
    let items = buildDisplayItems(ownedGroups, networks, noFilterParams(),
      TokenSelectorMode.AllTokens, searchActive = false,
      popularGroups = @[popular("ETH"), popular("DAI")], searchGroups = @[])
    check items.mapIt(it.key) == @["ETH", "DAI"]      # row set follows popular
    check items.findItem("ETH").hasBalance            # enriched from owned
    check not items.findItem("DAI").hasBalance

  test "Owned mode + search: results filtered to owned only":
    let items = buildDisplayItems(ownedGroups, networks, noFilterParams(),
      TokenSelectorMode.Owned, searchActive = true, popularGroups = @[],
      searchGroups = @[popular("ETH"), popular("DAI")])   # DAI not owned -> dropped
    check items.mapIt(it.key) == @["ETH"]

  test "AllTokens mode + search: results shown even when not owned":
    let items = buildDisplayItems(ownedGroups, networks, noFilterParams(),
      TokenSelectorMode.AllTokens, searchActive = true, popularGroups = @[],
      searchGroups = @[popular("ETH"), popular("DAI")])
    check items.mapIt(it.key) == @["ETH", "DAI"]
    check items.findItem("ETH").hasBalance
    check not items.findItem("DAI").hasBalance
