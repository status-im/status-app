## Structural + value tests for AssetsAdaptorModel (the terminal AssetsView model).
## Compile -d:QT_MODEL_SPY.
##
## Acceptance gate: a stable-set single-cell change emits exactly one dataChanged
## over one row and NO layoutChanged / NO reset; add/remove emit a single
## insert/remove; a sort flip re-sorts without a reset. Role values are checked
## against a brute-force reference.

import unittest, sequtils, algorithm, math
import nimqml

import app/modules/shared_models/assets_adaptor_model
import app/modules/shared/qt_model_spy

proc dataChangedRows(spy: QtModelSpy): int =
  for c in spy.calls:
    if c.kind == DataChanged:
      result += (c.bottomRight - c.topLeft + 1)

proc layoutChanges(spy: QtModelSpy): int =
  # model_sync never emits layoutChanged; a non-zero count would mean a proxy
  # slipped back in. BeginMoveRows stands in for "row reshuffle" churn.
  spy.calls.filterIt(it.kind == BeginMoveRows).len

# Brute-force reference, constructed INDEPENDENTLY of the model's comparator:
# filter visible, sort (isCommunity asc, then role/order) and break ties on
# SOURCE ORDER — not key. Production's SFPM has no tiebreak and is stable, so
# source order is the correct expectation; a comparator that broke ties on key
# would diverge from this reference, which is what makes the value-fidelity
# check below a real guard against re-introducing a key tiebreak.
proc refMarketBalance(it: AssetItem): float = it.balance * it.marketPrice
proc refChange1Day(it: AssetItem): float =
  let denom = it.marketChangePct24hour / 100.0 + 1.0
  if denom == 0.0: return 0.0
  refMarketBalance(it) * (1.0 - (1.0 / denom))
proc refIsCommunity(it: AssetItem): string =
  if it.communityId.len > 0: "community" else: ""

proc reference(items: seq[AssetItem], roleName: string, order: int): seq[AssetItem] =
  # Decorate each visible item with its source index so ties resolve to source
  # order explicitly, independent of the model (which relies on stable-sort).
  var decorated: seq[(int, AssetItem)] = @[]
  for i, it in items:
    if it.visible: decorated.add((i, it))
  decorated.sort(proc(x, y: (int, AssetItem)): int =
    let a = x[1]
    let b = y[1]
    let ca = refIsCommunity(a)
    let cb = refIsCommunity(b)
    if ca != cb: return cmp(ca, cb)
    var r = 0
    case roleName:
    of "name": r = cmp(a.name, b.name)
    of "balance": r = cmp(a.balance, b.balance)
    of "marketPrice": r = cmp(a.marketPrice, b.marketPrice)
    of "marketBalance": r = cmp(refMarketBalance(a), refMarketBalance(b))
    of "change1DayFiat": r = cmp(refChange1Day(a), refChange1Day(b))
    of "position": r = cmp(a.position, b.position)
    else: r = 0
    if order == 1: r = -r
    if r != 0: return r
    return cmp(x[0], y[0])) # source-order tiebreak, NOT key
  result = decorated.mapIt(it[1])

proc mkItem(key: string, name = "", balance = 0.0, marketPrice = 0.0,
    marketChangePct24hour = 0.0, communityId = "", visible = true): AssetItem =
  AssetItem(
    key: key,
    name: if name.len > 0: name else: key,
    symbol: key,
    balance: balance,
    marketPrice: marketPrice,
    marketChangePct24hour: marketChangePct24hour,
    marketDetailsAvailable: communityId.len == 0,
    communityId: communityId,
    canBeHidden: true,
    visible: visible,
  )

suite "AssetsAdaptorModel - terminal filter/sort/derive":

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "setSourceItems keeps only visible rows, sorted by name ascending":
    let m = newAssetsAdaptorModel()
    m.sortBy("name", 0) # Qt.AscendingOrder
    m.setSourceItems(@[
      mkItem("c", name = "Cardano"),
      mkItem("a", name = "Aave"),
      mkItem("h", name = "Hidden", visible = false),
      mkItem("b", name = "Bitcoin"),
    ])
    check m.getCount() == 3
    check m.keysInOrder() == @["a", "b", "c"]

  test "stable-set market-detail change: exactly one dataChanged over one row, no reset/move/insert/remove":
    let m = newAssetsAdaptorModel()
    m.sortBy("name", 0)
    m.setSourceItems(@[
      mkItem("a", name = "Aave", balance = 2.0, marketPrice = 3.0),
      mkItem("b", name = "Bitcoin", balance = 1.0, marketPrice = 5.0),
    ])
    spy.clear()

    m.setSourceItems(@[
      mkItem("a", name = "Aave", balance = 2.0, marketPrice = 3.0),
      mkItem("b", name = "Bitcoin", balance = 1.0, marketPrice = 9.0), # price change
    ])

    check spy.countResets() == 0
    check spy.layoutChanges() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 1
    check spy.dataChangedRows() == 1
    check m.marketBalanceAtForTest(1) == 9.0 # b: 1.0 * 9.0

  test "market change under marketBalance sort that moves a row: remove+insert, no reset/layoutChanged":
    let m = newAssetsAdaptorModel()
    m.sortBy("marketBalance", 1) # descending
    m.setSourceItems(@[
      mkItem("a", balance = 1.0, marketPrice = 1.0),  # mb 1
      mkItem("b", balance = 1.0, marketPrice = 2.0),  # mb 2
      mkItem("c", balance = 1.0, marketPrice = 3.0),  # mb 3
    ])
    check m.keysInOrder() == @["c", "b", "a"]
    spy.clear()

    m.setSourceItems(@[
      mkItem("a", balance = 1.0, marketPrice = 10.0), # mb 10 -> jumps to top
      mkItem("b", balance = 1.0, marketPrice = 2.0),
      mkItem("c", balance = 1.0, marketPrice = 3.0),
    ])

    check m.keysInOrder() == @["a", "c", "b"]
    check spy.countResets() == 0
    check spy.layoutChanges() == 0
    check spy.countInserts() == 1
    check spy.countRemoves() == 1

  test "add token: single insert, no reset":
    let m = newAssetsAdaptorModel()
    m.sortBy("name", 0)
    m.setSourceItems(@[mkItem("a", name = "Aave"), mkItem("c", name = "Cardano")])
    spy.clear()

    m.setSourceItems(@[mkItem("a", name = "Aave"), mkItem("b", name = "Bitcoin"),
                       mkItem("c", name = "Cardano")])
    check m.keysInOrder() == @["a", "b", "c"]
    check spy.countInserts() == 1
    check spy.countRemoves() == 0
    check spy.countResets() == 0

  test "remove token: single remove, no reset":
    let m = newAssetsAdaptorModel()
    m.sortBy("name", 0)
    m.setSourceItems(@[mkItem("a", name = "Aave"), mkItem("b", name = "Bitcoin"),
                       mkItem("c", name = "Cardano")])
    spy.clear()

    m.setSourceItems(@[mkItem("a", name = "Aave"), mkItem("c", name = "Cardano")])
    check m.keysInOrder() == @["a", "c"]
    check spy.countRemoves() == 1
    check spy.countInserts() == 0
    check spy.countResets() == 0

  test "visibility flip removes/adds a single row, no reset":
    let m = newAssetsAdaptorModel()
    m.sortBy("name", 0)
    m.setSourceItems(@[mkItem("a", name = "Aave"), mkItem("b", name = "Bitcoin")])
    spy.clear()

    m.setSourceItems(@[mkItem("a", name = "Aave"),
                       mkItem("b", name = "Bitcoin", visible = false)])
    check m.keysInOrder() == @["a"]
    check spy.countRemoves() == 1
    check spy.countResets() == 0

  test "sort flip re-sorts without a reset":
    let m = newAssetsAdaptorModel()
    m.sortBy("name", 0)
    m.setSourceItems(@[mkItem("a", name = "Aave"), mkItem("b", name = "Bitcoin"),
                       mkItem("c", name = "Cardano")])
    check m.keysInOrder() == @["a", "b", "c"]
    spy.clear()

    m.sortBy("name", 1) # descending
    check m.keysInOrder() == @["c", "b", "a"]
    check spy.countResets() == 0
    check spy.layoutChanges() == 0

  test "community tokens sort after regular tokens regardless of secondary role":
    let m = newAssetsAdaptorModel()
    m.sortBy("marketBalance", 1)
    m.setSourceItems(@[
      mkItem("reg1", balance = 1.0, marketPrice = 1.0),               # mb 1, regular
      mkItem("com1", balance = 1.0, marketPrice = 100.0, communityId = "x"), # mb 100, community
      mkItem("reg2", balance = 1.0, marketPrice = 2.0),               # mb 2, regular
    ])
    # regular first (desc by mb): reg2, reg1; then community: com1
    check m.keysInOrder() == @["reg2", "reg1", "com1"]
    check m.isCommunityAtForTest(2) == "community"

  test "ties preserve source order (no key tiebreak)":
    # Two rows with an identical sort key, keys in reverse of source order. A
    # stable, tiebreak-free sort keeps source order; a key tiebreak would flip
    # them to ["a", "z"].
    let m = newAssetsAdaptorModel()
    m.sortBy("marketBalance", 1) # descending
    m.setSourceItems(@[
      mkItem("z", balance = 1.0, marketPrice = 5.0), # mb 5, source idx 0
      mkItem("a", balance = 1.0, marketPrice = 5.0), # mb 5, source idx 1
    ])
    check m.keysInOrder() == @["z", "a"]

  test "change1DayFiat guards -100% (finite, sorts as zero, no NaN)":
    let m = newAssetsAdaptorModel()
    m.sortBy("change1DayFiat", 1) # descending
    m.setSourceItems(@[
      mkItem("gain", balance = 1.0, marketPrice = 1.0, marketChangePct24hour = 100.0),  # +0.5
      mkItem("wiped", balance = 1.0, marketPrice = 1.0, marketChangePct24hour = -100.0), # guarded -> 0
      mkItem("loss", balance = 1.0, marketPrice = 1.0, marketChangePct24hour = -50.0),   # -1.0
    ])
    # -100% collapses to 0 fiat change (not NaN/Inf), sorting between the gain
    # and the loss; a NaN here would break comparator antisymmetry.
    check m.keysInOrder() == @["gain", "wiped", "loss"]
    for i in 0 ..< m.getCount():
      if m.itemAtForTest(i).key == "wiped":
        check m.change1DayFiatAtForTest(i) == 0.0

  test "role values match a brute-force reference across the universe":
    var src: seq[AssetItem] = @[]
    for i in 0 ..< 200:
      src.add(mkItem(
        "tok" & $i,
        name = "Token " & $i,
        balance = float(i mod 50) + 1.5,
        marketPrice = 1.0 + float(i mod 30) * 0.1,
        marketChangePct24hour = float((i mod 40) - 20) * 0.5,
        communityId = (if i mod 7 == 0: "c" & $(i mod 3) else: ""),
        visible = (i mod 11 != 0),
      ))
    let m = newAssetsAdaptorModel()
    m.sortBy("marketBalance", 1)
    m.setSourceItems(src)

    let want = reference(src, "marketBalance", 1)
    check m.getCount() == want.len
    for i in 0 ..< want.len:
      check m.itemAtForTest(i).key == want[i].key
      check m.itemAtForTest(i).balanceText == want[i].balanceText
      check almostEqual(m.marketBalanceAtForTest(i), refMarketBalance(want[i]))
      check almostEqual(m.change1DayFiatAtForTest(i), refChange1Day(want[i]))
      check m.isCommunityAtForTest(i) == refIsCommunity(want[i])
