## Conversion tests for token_groups_model (setItemsWithSync + Table-keyed
## market details). Compile with -d:QT_MODEL_SPY.
##
## Covers the acceptance gate: identity preservation of MarketDetailsItem across
## insert+remove+reorder; reorder read-back (remove+insert, no moves) + no reset;
## stable-set refresh emits no reset / no move / no spurious churn.

import unittest, tables, sequtils
import nimqml

import app/modules/main/wallet_section/all_tokens/token_groups_model
import app/modules/main/wallet_section/all_tokens/io_interface
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
