## Signal-level tests for MarketLeaderboardModel. Compile -d:QT_MODEL_SPY.
##
## Acceptance gate: a price tick on a page emits one dataChanged carrying only
## the changed roles; switching to a page with other tokens emits granular
## insert/remove and NO reset; a token that only moves keeps its row alive.
## Only the first load (empty -> N) is allowed to reset.

import unittest, tables
import nimqml

import app/modules/main/market_section/market_leaderboard_model
import app/modules/main/market_section/io_interface
import app_service/service/market/service_items
import app/modules/shared/qt_model_spy

proc token(key: string, price: float64 = 1.0): MarketItem =
  MarketItem(key: key, name: key & " coin", symbol: key, image: key & ".png",
             currentPrice: price, marketCap: 10.0, totalVolume: 5.0,
             priceChangePercentage24h: 0.5)

suite "MarketLeaderboardModel":
  var page: seq[MarketItem]
  let source: MarketLeaderboardDataSource = (
    getMarketLeaderboardList: proc(): var seq[MarketItem] = page
  )

  setup:
    page = @[token("btc", 100.0), token("eth", 10.0), token("sol", 1.0)]

  test "first load resets once and exposes the page":
    let model = newMarketLeaderboardModel(source)
    let spy = newQtModelSpy()
    spy.enable()
    model.modelsUpdated()
    spy.disable()

    check spy.countResets() == 1
    check model.keysInOrder() == @["btc", "eth", "sol"]

  test "a price tick emits one dataChanged with only the changed roles":
    let model = newMarketLeaderboardModel(source)
    model.modelsUpdated()
    var priceRole = -1
    for role, name in model.roleNames():
      if name == "currentPrice": priceRole = role

    # the service mutates the same item in place before notifying
    page[1].currentPrice = 11.0
    let spy = newQtModelSpy()
    spy.enable()
    model.pageUpdated(@[])
    spy.disable()

    check spy.countResets() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    require spy.countDataChanged() == 1
    let change = spy.getDataChanged()[0]
    check change.topLeft == 1
    check change.bottomRight == 1
    check change.roles == @[priceRole]

  test "switching page does not reset the model":
    let model = newMarketLeaderboardModel(source)
    model.modelsUpdated()

    page = @[token("sol", 1.0), token("ada"), token("dot")]
    let spy = newQtModelSpy()
    spy.enable()
    model.modelsUpdated()
    spy.disable()

    check spy.countResets() == 0
    check spy.countInserts() > 0
    check spy.countRemoves() > 0
    check model.keysInOrder() == @["sol", "ada", "dot"]

  test "an unchanged page is silent":
    let model = newMarketLeaderboardModel(source)
    model.modelsUpdated()

    let spy = newQtModelSpy()
    spy.enable()
    model.modelsUpdated()
    spy.disable()

    check spy.countResets() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 0
