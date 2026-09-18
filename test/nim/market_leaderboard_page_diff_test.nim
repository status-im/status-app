import unittest
import app_service/service/market/service_items

proc token(key: string, price: float64 = 1.0): MarketItem =
  MarketItem(key: key, name: key & " coin", symbol: key, image: key & ".png",
             currentPrice: price, marketCap: 10.0, totalVolume: 5.0,
             priceChangePercentage24h: 0.5)

proc page(tokens: seq[MarketItem], totalCount = 100): LeaderboardPage =
  LeaderboardPage(totalCount: totalCount, data: tokens)

proc loadingState(tokens: seq[MarketItem] = @[]): LeaderboardPageState =
  LeaderboardPageState(tokens: tokens, totalCount: 0, loading: true)

suite "applyLoadedPage":
  test "loaded page sets rows, total count and clears loading":
    var state = loadingState()
    state.applyLoadedPage(page(@[token("btc")], totalCount = 42))
    check state.tokens.len == 1
    check state.totalCount == 42
    check not state.loading

suite "applyPageUpdate":
  test "update before the page loaded applies it as a loaded page":
    var state = loadingState()
    let diff = state.applyPageUpdate(page(@[token("btc", 100.0), token("eth", 10.0)], totalCount = 42))
    check diff.reloaded
    check diff.updates.len == 0
    check state.tokens.len == 2
    check state.tokens[1].key == "eth"
    check state.totalCount == 42
    check not state.loading

  test "different row count replaces the page":
    var state = loadingState(@[token("btc", 100.0), token("eth", 10.0), token("sol", 1.0)])
    let diff = state.applyPageUpdate(page(@[token("btc", 110.0), token("eth", 10.0)]))
    check diff.reloaded
    check state.tokens.len == 2
    check state.tokens[0].currentPrice == 110.0

  test "same row count reports changed fields and updates rows in place":
    var state = loadingState(@[token("btc", 100.0), token("eth", 10.0)])
    let diff = state.applyPageUpdate(page(@[token("btc", 100.0), token("eth", 11.0)]))
    check not diff.reloaded
    check diff.updates.len == 1
    check diff.updates[0].index == 1
    check diff.updates[0].changedFields == @["currentPrice"]
    check state.tokens[1].currentPrice == 11.0

  test "identical page produces no updates":
    var state = loadingState(@[token("btc", 100.0)])
    let diff = state.applyPageUpdate(page(@[token("btc", 100.0)]))
    check not diff.reloaded
    check diff.updates.len == 0
