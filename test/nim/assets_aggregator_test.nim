## Unit tests for buildAssetItems — the pure aggregation core that turns the raw
## Nim token data (token groups + per-account/chain balances + community info)
## plus the dynamic filters (accounts, chains, threshold) into the flat
## seq[AssetItem] consumed by AssetsAdaptorModel. Mirrors what the QML proxy
## chain (AssetsViewAdaptor's ObjectProxyModel + aggregators) computed.
##
## Qt-free: run with `nim c -r test/nim/assets_aggregator_test.nim`.

import unittest, sequtils, tables
import stint

import app/modules/shared_models/assets_aggregator

proc bal(account: string, chainId: int, wei: string, loading = false): AggBalance =
  AggBalance(account: account, chainId: chainId, balance: parse(wei, UInt256), loading: loading)

proc group(key: string, symbol = "", decimals = 18, visible = true,
    communityId = "", price = 0.0, change = 0.0, detailsLoading = false,
    position = 0, balances: seq[AggBalance] = @[]): AggTokenGroup =
  AggTokenGroup(
    key: key, name: key, symbol: if symbol.len > 0: symbol else: key,
    logoUri: "", decimals: decimals, communityId: communityId,
    marketPrice: price, marketChangePct24hour: change,
    marketDetailsLoading: detailsLoading, visible: visible, position: position,
    balances: balances)

proc filters(accounts: seq[string] = @["acc1"], chains: seq[int] = @[1],
    threshold = 0.0, nativeSymbols: seq[string] = @[]): AggFilters =
  AggFilters(accounts: accounts, chains: chains, marketValueThreshold: threshold,
    nativeSymbols: nativeSymbols)

proc byKey(items: seq[AssetItem], key: string): AssetItem =
  for it in items:
    if it.key == key: return it
  raise newException(KeyError, "no item " & key)

suite "buildAssetItems — aggregation":

  test "sums balances across accounts and chains, converts by decimals":
    let g = group("ETH", decimals = 18, balances = @[
      bal("acc1", 1, "1000000000000000000"),   # 1.0
      bal("acc1", 10, "500000000000000000"),   # 0.5
      bal("acc2", 1, "2000000000000000000"),   # 2.0 (filtered out: acc2)
    ])
    let items = buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters(accounts = @["acc1"], chains = @[1, 10]))
    check items.byKey("ETH").balance == 1.5

  test "6-decimals token converts correctly":
    let g = group("USDC", decimals = 6, price = 1.0, balances = @[
      bal("acc1", 1, "2500000"),               # 2.5
    ])
    let it = buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters()).byKey("USDC")
    check it.balance == 2.5

  test "chains filter excludes non-selected chain balances":
    let g = group("ETH", balances = @[
      bal("acc1", 1, "1000000000000000000"),
      bal("acc1", 999, "3000000000000000000"),  # chain not selected
    ])
    let it = buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters(chains = @[1])).byKey("ETH")
    check it.balance == 1.0
    check it.chainIds == @[1]

  test "balanceLoading true when any filtered balance is loading":
    let g = group("ETH", balances = @[
      bal("acc1", 1, "0", loading = true),
    ])
    let it = buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters()).byKey("ETH")
    check it.balanceLoading

suite "buildAssetItems — visibility":

  test "hidden token (visible=false) is not visible":
    let g = group("ETH", visible = false, price = 10.0, balances = @[
      bal("acc1", 1, "1000000000000000000")])
    check (not buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters()).byKey("ETH").visible)

  test "no matching balances -> not visible":
    let g = group("ETH", price = 10.0, balances = @[
      bal("acc2", 1, "1000000000000000000")])   # acc2 filtered out
    check (not buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters(accounts = @["acc1"])).byKey("ETH").visible)

  test "below threshold -> not visible; at/above -> visible":
    let below = group("A", price = 1.0, balances = @[bal("acc1", 1, "1000000000000000000")]) # 1.0*1=1
    let above = group("B", price = 5.0, balances = @[bal("acc1", 1, "1000000000000000000")]) # 1.0*5=5
    let items = buildAssetItems(@[below, above], initTable[string, AggCommunity](),
      filters(threshold = 2.0))
    check (not items.byKey("A").visible)
    check items.byKey("B").visible

  test "loading token stays visible even below threshold":
    let g = group("ETH", price = 0.0, balances = @[
      bal("acc1", 1, "0", loading = true)])
    check buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters(threshold = 100.0)).byKey("ETH").visible

  test "community token always visible regardless of threshold":
    let g = group("CT", communityId = "comm1", price = 0.0, balances = @[
      bal("acc1", 1, "1000000000000000000")])
    let it = buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters(threshold = 1000.0)).byKey("CT")
    check it.visible
    check (not it.marketDetailsAvailable)

suite "buildAssetItems — joins and flags":

  test "community info joined by communityId":
    var comms = initTable[string, AggCommunity]()
    comms["comm1"] = AggCommunity(name: "Kitties", image: "img://k")
    let g = group("CT", communityId = "comm1", balances = @[
      bal("acc1", 1, "1000000000000000000")])
    let it = buildAssetItems(@[g], comms, filters()).byKey("CT")
    check it.communityName == "Kitties"
    check it.communityImage == "img://k"

  test "marketDetailsAvailable true for non-community token":
    let g = group("ETH", balances = @[bal("acc1", 1, "1000000000000000000")])
    check buildAssetItems(@[g], initTable[string, AggCommunity](),
      filters()).byKey("ETH").marketDetailsAvailable

  test "canBeHidden false for a native token symbol of an enabled chain":
    let eth = group("ETH", symbol = "ETH", balances = @[bal("acc1", 1, "1000000000000000000")])
    let snt = group("SNT", symbol = "SNT", balances = @[bal("acc1", 1, "1000000000000000000")])
    let items = buildAssetItems(@[eth, snt], initTable[string, AggCommunity](),
      filters(nativeSymbols = @["ETH"]))
    check (not items.byKey("ETH").canBeHidden)
    check items.byKey("SNT").canBeHidden

  test "carries name/symbol/logoUri/position/marketPrice/change through":
    let g = AggTokenGroup(key: "ETH", name: "Ether", symbol: "ETH",
      logoUri: "logo://eth", decimals: 18, marketPrice: 1234.5,
      marketChangePct24hour: 2.5, marketDetailsLoading: false, visible: true, position: 7,
      balances: @[bal("acc1", 1, "1000000000000000000")])
    let it = buildAssetItems(@[g], initTable[string, AggCommunity](), filters()).byKey("ETH")
    check it.name == "Ether"
    check it.symbol == "ETH"
    check it.logoUri == "logo://eth"
    check it.position == 7
    check it.marketPrice == 1234.5
    check it.marketChangePct24hour == 2.5
    check it.marketDetailsLoading == false
