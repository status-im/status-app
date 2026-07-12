## Structural + value tests for TokenSelectorModel (the terminal picker model).
## Compile -d:QT_MODEL_SPY.
##
## Acceptance gate: a stable-set single-cell change emits exactly one dataChanged
## over one row and NO layoutChanged / NO reset; add/remove emit a single
## insert/remove; a reorder degrades to remove+insert (no reset). The nested
## balances submodel keeps its identity across refreshes and carries chip changes
## through its own signals.

import unittest, sequtils
import nimqml

import app/modules/shared_models/token_selector_model
import app/modules/shared/qt_model_spy

proc dataChangedRows(spy: QtModelSpy): int =
  for c in spy.calls:
    if c.kind == DataChanged:
      result += (c.bottomRight - c.topLeft + 1)

proc layoutChanges(spy: QtModelSpy): int =
  spy.calls.filterIt(it.kind == BeginMoveRows).len

proc chip(chainId: int, balance: float, iconUrl = "", chainName = ""): TokenSelectorChip =
  TokenSelectorChip(chainId: chainId, balance: balance, iconUrl: iconUrl, chainName: chainName)

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
