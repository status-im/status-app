import unittest
import app_service/service/market/service_items

proc token(key: string, price: float64 = 1.0): MarketItem =
  MarketItem(key: key, name: key & " coin", symbol: key, image: key & ".png",
             currentPrice: price, marketCap: 10.0, totalVolume: 5.0,
             priceChangePercentage24h: 0.5)

suite "applyPageDiff":
  test "empty local page is replaced by incoming rows":
    var current: seq[MarketItem] = @[]
    let incoming = @[token("btc", 100.0), token("eth", 10.0)]
    let diff = applyPageDiff(current, incoming)
    check diff.reloaded
    check diff.updates.len == 0
    check current.len == 2
    check current[1].key == "eth"

  test "different row count replaces the page":
    var current = @[token("btc", 100.0), token("eth", 10.0), token("sol", 1.0)]
    let incoming = @[token("btc", 110.0), token("eth", 10.0)]
    let diff = applyPageDiff(current, incoming)
    check diff.reloaded
    check current.len == 2
    check current[0].currentPrice == 110.0

  test "same row count reports changed fields and updates rows in place":
    var current = @[token("btc", 100.0), token("eth", 10.0)]
    let incoming = @[token("btc", 100.0), token("eth", 11.0)]
    let diff = applyPageDiff(current, incoming)
    check not diff.reloaded
    check diff.updates.len == 1
    check diff.updates[0].index == 1
    check diff.updates[0].changedFields == @["currentPrice"]
    check current[1].currentPrice == 11.0

  test "identical page produces no updates":
    var current = @[token("btc", 100.0)]
    let diff = applyPageDiff(current, @[token("btc", 100.0)])
    check not diff.reloaded
    check diff.updates.len == 0
