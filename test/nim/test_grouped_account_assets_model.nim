## Tests for src/app/modules/main/wallet_section/assets/grouped_account_assets_model.nim
##
## Coverage focus:
##   - Discriminated callbacks (onInsert / onUpdate / onRemove) fire in the
##     right places with the right indices
##   - The fast paths in setItemsWithSync (empty -> N and N -> empty) emit
##     beginResetModel/endResetModel instead of per-row inserts/removes
##   - Single-row balance ticks emit exactly one parent dataChanged + one
##     nested dataChanged, no extras
##   - Mid-list inserts and removes don't disturb the IDs of stable rows
##   - balancesPerChain stays in lockstep with the parent items array
##   - The nested BalancesModel's `setInitialItems` path bypasses signals
##     entirely (the small-N regression fix)
##   - DATA correctness: after every operation, the model exposes the right
##     keys at the right rows AND every nested BalancesModel exposes the
##     right (account, balance, tokenAddress) tuples at the right rows
##
## Build with `-d:QT_MODEL_SPY` so model_sync.nim's recordBegin*/recordEnd*
## hooks emit into the spy, and `-d:testing` so the model exposes its
## test-only field accessors (keyAt / nestedAt / balanceAtRow / etc.).

{.define: testing.}
{.define: QT_MODEL_SPY.}

import unittest
import std/tables
import stint

import nimqml

import app/core/cow_seq
import app/modules/shared/qt_model_spy
import app/modules/shared/model_sync
import app/modules/main/wallet_section/assets/grouped_account_assets_model as gam
import app/modules/main/wallet_section/assets/balances_model
import app/modules/main/wallet_section/assets/io_interface
import app_service/service/wallet_account/dto/asset_group_item

# ----------------------------------------------------------------------------
# Mock service - holds a CowSeq[AssetGroupItem] and exposes the data source
# ----------------------------------------------------------------------------

type MockService = ref object
  groupedAssets: CowSeq[AssetGroupItem]

proc newMockService(): MockService =
  result = MockService(groupedAssets: toCowSeq(newSeq[AssetGroupItem](0)))

proc dataSource(self: MockService): GroupedAccountAssetsDataSource =
  let svc = self
  return (
    getGroupedAssetsList: proc(): CowSeq[AssetGroupItem] = svc.groupedAssets
  )

proc populate(self: MockService, numTokens, numBalances: int) =
  ## Build a deterministic dataset: tokens are "token-0".."token-(N-1)";
  ## each token has `numBalances` BalanceItems on chain 1 across distinct
  ## accounts.
  var working: seq[AssetGroupItem] = @[]
  for t in 0 ..< numTokens:
    var item = AssetGroupItem(
      key: "token-" & $t,
      balancesPerAccount: @[]
    )
    for b in 0 ..< numBalances:
      item.balancesPerAccount.add(BalanceItem(
        account: "0xacct" & $b,
        groupKey: "token-" & $t,
        tokenKey: "token-" & $t,
        chainId: 1,
        tokenAddress: "0xtok" & $t,
        balance: u256(t * 1000 + b),
      ))
    working.add(item)
  self.groupedAssets = toCowSeq(working)

proc clear(self: MockService) =
  self.groupedAssets = toCowSeq(newSeq[AssetGroupItem](0))

proc bumpBalance(self: MockService, tokenIdx, balanceIdx: int) =
  ## Mutate exactly one BalanceItem to simulate a single-row balance tick.
  var working = self.groupedAssets.asSeq()
  working[tokenIdx].balancesPerAccount[balanceIdx].balance =
    working[tokenIdx].balancesPerAccount[balanceIdx].balance + u256(1)
  self.groupedAssets = toCowSeq(working)

proc insertTokenAt(self: MockService, idx: int, key: string, numBalances: int) =
  var working = self.groupedAssets.asSeq()
  var item = AssetGroupItem(key: key, balancesPerAccount: @[])
  for b in 0 ..< numBalances:
    item.balancesPerAccount.add(BalanceItem(
      account: "0xacct" & $b,
      groupKey: key,
      tokenKey: key,
      chainId: 1,
      tokenAddress: "0xtok-" & key,
      balance: u256(b),
    ))
  working.insert(item, idx)
  self.groupedAssets = toCowSeq(working)

proc removeTokenAt(self: MockService, idx: int) =
  var working = self.groupedAssets.asSeq()
  working.delete(idx)
  self.groupedAssets = toCowSeq(working)

proc reorderReverse(self: MockService) =
  var working = self.groupedAssets.asSeq()
  var reversed: seq[AssetGroupItem] = @[]
  for i in countdown(working.high, 0):
    reversed.add(working[i])
  self.groupedAssets = toCowSeq(reversed)

# ----------------------------------------------------------------------------
# Spy lifecycle helper
# ----------------------------------------------------------------------------

template withSpy(body: untyped): untyped =
  block:
    let spy {.inject.} = newQtModelSpy()
    spy.enable()
    try:
      body
    finally:
      spy.disable()

# ----------------------------------------------------------------------------
# Helpers that go through the public Qt model API
# ----------------------------------------------------------------------------
#
# Every value read in the tests goes through `model.data(index, role)`
# (the same path QML uses).  We look up role ints by their QML role name
# via `roleNames()` so the tests don't hardcode UserRole+1 magic numbers
# and stay valid if the enum is reordered.

proc roleByName(model: QAbstractListModel, name: string): int =
  for k, v in model.roleNames():
    if v == name: return k
  doAssert false, "role '" & name & "' not found in roleNames()"

proc topLevelCount(model: QAbstractListModel): int =
  ## Wraps `rowCount(invalid parent)` for top-level list model queries.
  let parent = newQModelIndex()
  defer: parent.delete
  return model.rowCount(parent)

proc dataString(model: QAbstractListModel, row: int, roleName: string): string =
  let idx = model.createIndex(row, 0, nil)
  defer: idx.delete
  let v = model.data(idx, model.roleByName(roleName))
  defer: v.delete
  return v.stringVal

proc dataInt(model: QAbstractListModel, row: int, roleName: string): int =
  let idx = model.createIndex(row, 0, nil)
  defer: idx.delete
  let v = model.data(idx, model.roleByName(roleName))
  defer: v.delete
  return v.intVal

# ----------------------------------------------------------------------------
# Data-shape assertion helper
# ----------------------------------------------------------------------------
#
# Walks every parent row (via `data(row, "key")`) and every nested row
# (via the nested BalancesModel's own `data(row, "account"|"balance"|...)`)
# and asserts the values match what the mock service currently holds.
# Used after every operation so any row drift, stale data, or off-by-one
# in the nested array is caught.
#
# `nestedAt()` is the ONLY test-only accessor; it just hands back the
# BalancesModel ref so we can call `data()` on it.  Necessary because
# nimqml has no QVariant -> QObject extraction, so the test can't unwrap
# the result of `parentModel.data(row, "balances")` back to a Nim ref.

proc verifyDataMatches(model: gam.Model, svc: MockService) =
  let snapshot = svc.groupedAssets
  let parentCount = model.topLevelCount()
  doAssert parentCount == snapshot.len,
    "parent rowCount " & $parentCount & " != svc len " & $snapshot.len
  doAssert model.nestedCount() == snapshot.len,
    "nested array len " & $model.nestedCount() & " != svc len " & $snapshot.len

  for parentIdx in 0 ..< snapshot.len:
    let expectedKey = snapshot[parentIdx].key
    let actualKey = model.dataString(parentIdx, "key")
    doAssert actualKey == expectedKey,
      "parent row " & $parentIdx & ": key " & actualKey &
      " != expected " & expectedKey

    let nested = model.nestedAt(parentIdx)
    doAssert not nested.isNil, "nested model nil at row " & $parentIdx

    let expectedBalances = snapshot[parentIdx].balancesPerAccount
    let nestedCount = nested.topLevelCount()
    doAssert nestedCount == expectedBalances.len,
      "nested[" & $parentIdx & "].rowCount " & $nestedCount &
      " != expected " & $expectedBalances.len

    for childIdx in 0 ..< expectedBalances.len:
      let exp = expectedBalances[childIdx]
      let actualAccount = nested.dataString(childIdx, "account")
      let actualBalance = nested.dataString(childIdx, "balance")
      let actualTokenAddress = nested.dataString(childIdx, "tokenAddress")
      let actualChainId = nested.dataInt(childIdx, "chainId")
      doAssert actualAccount == exp.account,
        "nested[" & $parentIdx & "][" & $childIdx & "].account " &
        actualAccount & " != " & exp.account
      doAssert actualBalance == exp.balance.toString(10),
        "nested[" & $parentIdx & "][" & $childIdx & "].balance " &
        actualBalance & " != " & exp.balance.toString(10)
      doAssert actualTokenAddress == exp.tokenAddress,
        "nested[" & $parentIdx & "][" & $childIdx & "].tokenAddress " &
        actualTokenAddress & " != " & exp.tokenAddress
      doAssert actualChainId == exp.chainId,
        "nested[" & $parentIdx & "][" & $childIdx & "].chainId " &
        $actualChainId & " != " & $exp.chainId

# ----------------------------------------------------------------------------
# Tests
# ----------------------------------------------------------------------------

suite "grouped_account_assets_model - fast paths":

  test "fresh load (empty -> 5) takes the beginResetModel fast path":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    withSpy:
      svc.populate(5, 3)
      model.modelsUpdated()

      check model.getCount() == 5
      # The empty -> N fast path emits one reset, no inserts.
      check spy.countResets() == 1
      check spy.countInserts() == 0
      check spy.countDataChanged() == 0
      check spy.countRemoves() == 0
    verifyDataMatches(model, svc)

  test "full clear (5 -> empty) takes the beginResetModel fast path":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()

    withSpy:
      svc.clear()
      model.modelsUpdated()

      check model.getCount() == 0
      check spy.countResets() == 1
      check spy.countRemoves() == 0
      check spy.countInserts() == 0
      check spy.countDataChanged() == 0
    verifyDataMatches(model, svc)


suite "grouped_account_assets_model - balance ticks":

  test "single-row balance tick emits exactly one parent dataChanged + one nested dataChanged":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()
    verifyDataMatches(model, svc)  # baseline before mutation

    withSpy:
      svc.bumpBalance(2, 1)  # change row 2's balance for account 1
      model.modelsUpdated()

      check model.getCount() == 5
      # Exactly two dataChanged - one on the parent (Balances role), one on
      # the affected nested model (Balance role).  No inserts, removes,
      # or resets.
      check spy.countDataChanged() == 2
      check spy.countInserts() == 0
      check spy.countRemoves() == 0
      check spy.countResets() == 0

      let dc = spy.getDataChanged()
      # Parent emission: row 2.
      check dc[0].topLeft == 2
      check dc[0].bottomRight == 2
      # Nested emission: row 1 of token 2's nested balances.
      check dc[1].topLeft == 1
      check dc[1].bottomRight == 1
    verifyDataMatches(model, svc)
    # And specifically: the bumped balance is now visible via data().
    let nested = model.nestedAt(2)
    check nested.dataString(1, "balance") == "2002"  # was 2*1000+1=2001; bumped by 1

  test "no-op update (same data) emits zero signals":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()

    withSpy:
      # Re-snapshot without mutating.
      svc.populate(5, 3)
      model.modelsUpdated()

      check spy.countDataChanged() == 0
      check spy.countInserts() == 0
      check spy.countRemoves() == 0
      check spy.countResets() == 0
    verifyDataMatches(model, svc)


suite "grouped_account_assets_model - structural changes":

  test "mid-list insert (5 -> 6) emits one insert at the right index, no shifts":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()

    withSpy:
      svc.insertTokenAt(2, "token-X", 3)
      model.modelsUpdated()

      check model.getCount() == 6
      check spy.countInserts() == 1
      check spy.countRemoves() == 0
      check spy.countResets() == 0

      let ins = spy.getInserts()
      check ins[0].first == 2
      check ins[0].last == 2
    verifyDataMatches(model, svc)
    # Stable rows kept their keys; the inserted row landed at index 2.
    check model.dataString(0, "key") == "token-0"
    check model.dataString(1, "key") == "token-1"
    check model.dataString(2, "key") == "token-X"
    check model.dataString(3, "key") == "token-2"
    check model.dataString(5, "key") == "token-4"

  test "tail insert (5 -> 6) emits one insert at end":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()

    withSpy:
      svc.insertTokenAt(5, "token-Z", 3)
      model.modelsUpdated()

      check model.getCount() == 6
      check spy.countInserts() == 1
      let ins = spy.getInserts()
      check ins[0].first == 5
      check ins[0].last == 5
    verifyDataMatches(model, svc)
    check model.dataString(5, "key") == "token-Z"

  test "mid-list remove (5 -> 4) emits one remove at the right index":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()

    withSpy:
      svc.removeTokenAt(2)
      model.modelsUpdated()

      check model.getCount() == 4
      check spy.countRemoves() == 1
      check spy.countInserts() == 0
      check spy.countResets() == 0

      let rem = spy.getRemoves()
      check rem[0].first == 2
      check rem[0].last == 2
    verifyDataMatches(model, svc)
    # The hole closed up - what was token-3 is now at row 2.
    check model.dataString(2, "key") == "token-3"
    check model.dataString(3, "key") == "token-4"

  test "balancesPerChain stays in lockstep with items after insert+remove sequence":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()
    check model.getCount() == 5
    verifyDataMatches(model, svc)

    svc.insertTokenAt(2, "token-X", 3)
    model.modelsUpdated()
    check model.getCount() == 6
    verifyDataMatches(model, svc)

    svc.removeTokenAt(0)
    model.modelsUpdated()
    check model.getCount() == 5
    verifyDataMatches(model, svc)

    svc.removeTokenAt(model.getCount() - 1)
    model.modelsUpdated()
    check model.getCount() == 4
    verifyDataMatches(model, svc)


suite "grouped_account_assets_model - per-operation data correctness":

  # Drives the model through a sequence of small atomic operations
  # (one insert / one remove / one update per modelsUpdated call) and,
  # AFTER EACH, queries the model via data() to verify it returns the
  # correct values for every parent row AND every nested balance.
  #
  # This is the per-emit verification that consumers actually need:
  # any granular Qt signal that reaches a view eventually triggers a
  # rowCount + data() call on the model.  By exercising one operation
  # at a time and reading EVERY (parent, nested, role) tuple via data()
  # immediately after, we cover the same correctness ground as
  # connecting to rowsInserted/rowsRemoved/dataChanged handlers - just
  # at the boundary of each modelsUpdated() instead of inside it.
  #
  # We pair the data() reads with the qt_model_spy to also verify the
  # exact signal stream emitted by each operation.

  proc buildLetterToken(letter: char, balanceOffset: int = 0): AssetGroupItem =
    result = AssetGroupItem(
      key: "token-" & $letter,
      balancesPerAccount: @[])
    for b in 0 ..< 3:
      result.balancesPerAccount.add(BalanceItem(
        account: "0xacct" & $b,
        groupKey: "token-" & $letter,
        tokenKey: "token-" & $letter,
        chainId: 1,
        tokenAddress: "0xtok-" & $letter,
        balance: u256(b + balanceOffset),
      ))

  test "2 removes + 2 inserts + 1 update: data() correct after every operation":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())

    # ---- Step 0: initial load [A, B, C, D] ----
    svc.groupedAssets = toCowSeq(@[
      buildLetterToken('A'), buildLetterToken('B'),
      buildLetterToken('C'), buildLetterToken('D'),
    ])
    model.modelsUpdated()
    verifyDataMatches(model, svc)
    check model.dataString(0, "key") == "token-A"
    check model.dataString(1, "key") == "token-B"
    check model.dataString(2, "key") == "token-C"
    check model.dataString(3, "key") == "token-D"

    # ---- Step 1: remove D (one remove at the tail) ----
    withSpy:
      svc.groupedAssets = toCowSeq(@[
        buildLetterToken('A'), buildLetterToken('B'), buildLetterToken('C'),
      ])
      model.modelsUpdated()
      check spy.countRemoves() == 1
      check spy.countInserts() == 0
      check spy.countDataChanged() == 0
      check spy.countResets() == 0
      check spy.getRemoves()[0].first == 3
      check spy.getRemoves()[0].last == 3
    verifyDataMatches(model, svc)
    check model.topLevelCount() == 3
    check model.dataString(0, "key") == "token-A"
    check model.dataString(1, "key") == "token-B"
    check model.dataString(2, "key") == "token-C"

    # ---- Step 2: remove A (one remove at the head, surviving rows shift) ----
    withSpy:
      svc.groupedAssets = toCowSeq(@[
        buildLetterToken('B'), buildLetterToken('C'),
      ])
      model.modelsUpdated()
      check spy.countRemoves() == 1
      check spy.countInserts() == 0
      check spy.countDataChanged() == 0
      check spy.getRemoves()[0].first == 0
      check spy.getRemoves()[0].last == 0
    verifyDataMatches(model, svc)
    check model.topLevelCount() == 2
    # B and C slid into rows 0 and 1.
    check model.dataString(0, "key") == "token-B"
    check model.dataString(1, "key") == "token-C"

    # ---- Step 3: insert X in the middle (one insert at row 1) ----
    withSpy:
      svc.groupedAssets = toCowSeq(@[
        buildLetterToken('B'), buildLetterToken('X'), buildLetterToken('C'),
      ])
      model.modelsUpdated()
      check spy.countInserts() == 1
      check spy.countRemoves() == 0
      check spy.countDataChanged() == 0
      check spy.getInserts()[0].first == 1
      check spy.getInserts()[0].last == 1
    verifyDataMatches(model, svc)
    check model.topLevelCount() == 3
    check model.dataString(0, "key") == "token-B"
    check model.dataString(1, "key") == "token-X"  # the new one
    check model.dataString(2, "key") == "token-C"  # shifted right

    # ---- Step 4: insert Y at the tail (one insert at row 3) ----
    withSpy:
      svc.groupedAssets = toCowSeq(@[
        buildLetterToken('B'), buildLetterToken('X'),
        buildLetterToken('C'), buildLetterToken('Y'),
      ])
      model.modelsUpdated()
      check spy.countInserts() == 1
      check spy.countRemoves() == 0
      check spy.countDataChanged() == 0
      check spy.getInserts()[0].first == 3
      check spy.getInserts()[0].last == 3
    verifyDataMatches(model, svc)
    check model.topLevelCount() == 4
    check model.dataString(3, "key") == "token-Y"

    # ---- Step 5: update B's balance (one stable update, no structural change) ----
    withSpy:
      svc.groupedAssets = toCowSeq(@[
        buildLetterToken('B', 100),  # bumped
        buildLetterToken('X'),
        buildLetterToken('C'),
        buildLetterToken('Y'),
      ])
      model.modelsUpdated()
      check spy.countDataChanged() == 2  # 1 parent + 1 nested
      check spy.countInserts() == 0
      check spy.countRemoves() == 0
      check spy.countResets() == 0
      let dc = spy.getDataChanged()
      # Parent dataChanged: row 0 (B's Balances role)
      check dc[0].topLeft == 0
      check dc[0].bottomRight == 0
      # Nested dataChanged: rows 0..2 (all three balances changed because
      # buildLetterToken('B', 100) shifts every BalanceItem by +100).
      # applySyncWithBulkOps groups consecutive same-role updates into a
      # single ranged dataChanged.
      check dc[1].topLeft == 0
      check dc[1].bottomRight == 2
    verifyDataMatches(model, svc)
    # Final state: keys unchanged, but the nested model now reports the
    # bumped balance via data().
    check model.dataString(0, "key") == "token-B"
    check model.dataString(1, "key") == "token-X"
    check model.dataString(2, "key") == "token-C"
    check model.dataString(3, "key") == "token-Y"
    let bNested = model.nestedAt(0)
    check bNested.dataString(0, "balance") == "100"   # 0 + offset 100
    check bNested.dataString(1, "balance") == "101"   # 1 + offset 100
    check bNested.dataString(2, "balance") == "102"   # 2 + offset 100
    # Other tokens' balances are unchanged (offset = 0).
    let cNested = model.nestedAt(2)
    check cNested.dataString(0, "balance") == "0"
    check cNested.dataString(1, "balance") == "1"
    check cNested.dataString(2, "balance") == "2"


suite "grouped_account_assets_model - reorder (LIS)":

  test "full reverse keeps the longest stable subsequence (LIS picks 1 element)":
    let svc = newMockService()
    let model = gam.newModel(svc.dataSource())
    svc.populate(5, 3)
    model.modelsUpdated()

    withSpy:
      svc.reorderReverse()
      model.modelsUpdated()

      check model.getCount() == 5
      check spy.countResets() == 0
      # LIS over old-positions [4,3,2,1,0] is length 1 -> exactly 1 row
      # stays stable, 4 rows are emitted as remove+insert pairs.
      # applySyncWithBulkOps groups consecutive runs into single bulk
      # calls, so we check the SPANS, not the call counts.
      var rowsInserted = 0
      for op in spy.getInserts():
        rowsInserted += (op.last - op.first + 1)
      var rowsRemoved = 0
      for op in spy.getRemoves():
        rowsRemoved += (op.last - op.first + 1)
      check rowsInserted == 4
      check rowsRemoved == 4
    verifyDataMatches(model, svc)
    # The model now matches the reversed mock service.
    check model.dataString(0, "key") == "token-4"
    check model.dataString(1, "key") == "token-3"
    check model.dataString(2, "key") == "token-2"
    check model.dataString(3, "key") == "token-1"
    check model.dataString(4, "key") == "token-0"
