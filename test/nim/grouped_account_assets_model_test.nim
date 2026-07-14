## Conversion tests for grouped_account_assets_model + balances_model
## (setItemsWithSync + self-updating nested BalancesModel). Compile -d:QT_MODEL_SPY.
##
## Acceptance gate coverage: a stable-set refresh emits NO reset / NO move / NO
## dataChanged; a per-token balance change emits a single BalancesModel dataChanged
## and NO parent reset; group add/remove emit minimal insert/remove; the service's
## Table-hash order churn is absorbed by the key-sort so survivors don't move.
##
## The QtModelSpy is global and records ops from BOTH the parent grouped model and
## the nested BalancesModels (both go through setItemsWithSync), so assertions are on
## aggregate op counts across the whole refresh.

import unittest, sequtils, stint
import nimqml

import app/modules/main/wallet_section/assets/grouped_account_assets_model
import app/modules/main/wallet_section/assets/balances_model
import app/modules/main/wallet_section/assets/io_interface
import app_service/service/wallet_account/dto/asset_group_item
import app/modules/shared/qt_model_spy

var gGroups: seq[AssetGroupItem] = @[]

proc dataSource(): GroupedAccountAssetsDataSource =
  (
    getGroupedAssetsList: proc(): var seq[AssetGroupItem] = gGroups,
  )

proc mkBalance(tokenKey, account: string, balance: int, loading = false): BalanceItem =
  BalanceItem(
    account: account, groupKey: "", tokenKey: tokenKey,
    chainId: 1, tokenAddress: tokenKey, balance: u256(balance), loading: loading)

proc mkGroup(key: string, balances: seq[BalanceItem] = @[]): AssetGroupItem =
  let bs = if balances.len > 0: balances else: @[mkBalance(key & "-t", "acc", 100)]
  AssetGroupItem(key: key, balancesPerAccount: bs)

proc newTestModel(): Model =
  newModel(dataSource())

proc moves(spy: QtModelSpy): int = spy.calls.filterIt(it.kind == BeginMoveRows).len

suite "grouped_account_assets_model - granular refresh, no reset":

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "stable set, same balances: no reset, no move, no dataChanged":
    gGroups = @[mkGroup("a"), mkGroup("b")]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a"), mkGroup("b")]
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["a", "b"]
    check spy.countResets() == 0
    check spy.moves() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 0

  test "balance change on one token: child dataChanged only, no reset/move/insert/remove":
    gGroups = @[mkGroup("a", @[mkBalance("a-t", "acc", 100)]),
                mkGroup("b", @[mkBalance("b-t", "acc", 100)])]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a", @[mkBalance("a-t", "acc", 250)]),  # a's balance changed
                mkGroup("b", @[mkBalance("b-t", "acc", 100)])]
    m.modelsUpdated()

    check spy.countResets() == 0
    check spy.moves() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 1   # only a's BalancesModel row
    check m.balancesModelForKey("a").balanceAtForTest(0) == "250"
    check m.balancesModelForKey("b").balanceAtForTest(0) == "100"

  test "loading flip: child dataChanged, no reset":
    gGroups = @[mkGroup("a", @[mkBalance("a-t", "acc", 100, loading = true)])]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a", @[mkBalance("a-t", "acc", 100, loading = false)])]
    m.modelsUpdated()

    check spy.countDataChanged() == 1
    check spy.countResets() == 0

  test "group added: parent insert (sorted), no reset, new group has its balances":
    gGroups = @[mkGroup("a"), mkGroup("c")]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c")]  # b inserted in the middle
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["a", "b", "c"]
    check spy.countInserts() == 1
    check spy.moves() == 0     # sorted-by-key: survivors don't reshuffle
    check spy.countResets() == 0
    check not m.balancesModelForKey("b").isNil
    check m.balancesModelForKey("b").balanceCountForTest() == 1

  test "group removed: parent remove, no reset, key dropped":
    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c")]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a"), mkGroup("c")]  # remove b
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["a", "c"]
    check spy.countRemoves() == 1
    check spy.moves() == 0
    check spy.countResets() == 0
    check m.balancesModelForKey("b").isNil

  test "service hash-order churn absorbed by key-sort: no moves, no reset":
    gGroups = @[mkGroup("a"), mkGroup("b"), mkGroup("c")]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("c"), mkGroup("a"), mkGroup("b")]  # same keys, different service order
    m.modelsUpdated()

    check m.groupKeysInOrder() == @["a", "b", "c"]   # re-sorted stable
    check spy.moves() == 0
    check spy.countResets() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0

  test "balance row added to a group: child insert on that group, no parent reset":
    gGroups = @[mkGroup("a", @[mkBalance("a-t1", "acc", 100)])]
    let m = newTestModel()
    m.modelsUpdated()
    spy.clear()

    gGroups = @[mkGroup("a", @[mkBalance("a-t1", "acc", 100),
                               mkBalance("a-t2", "acc", 50)])]  # second chain balance
    m.modelsUpdated()

    check spy.countResets() == 0
    check spy.countInserts() == 1   # child BalancesModel insert
    check spy.countRemoves() == 0
    check m.balancesModelForKey("a").balanceCountForTest() == 2
