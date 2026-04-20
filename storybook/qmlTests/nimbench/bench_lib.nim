## Bench harness for grouped_account_assets_model: OLD vs NEW.
##
## Built as a static library (`--app:staticlib --noMain`) and linked into
## storybook's QmlTests executable.  The C++ side calls `NimMain()` once at
## startup and `createBenchHarness()` to obtain a QObject pointer that can
## be exposed as a QML context property.
##
## The harness owns:
##   - one BenchServiceOld + one GroupedAccountAssetsModelOld  (the old
##     reset-based model with ref-object DTOs)
##   - one BenchServiceNew + new grouped_account_assets_model.Model (the
##     CoW + setItemsWithSync model from src/)
## and exposes:
##   - oldModel / newModel  Q_PROPERTY (QObject)  - so QML can wrap them in
##     proxies and views
##   - populate(numTokens, numAccounts, numChains)  - rebuilds both
##     services with identical synthetic data and pushes the new state to
##     both models
##   - pureLoadOld() / pureLoadNew()  - clear, repopulate, modelsUpdated;
##     return elapsed seconds (measured with std/monotimes)
##   - simulateBalanceTickOld() / simulateBalanceTickNew()  - mutate one
##     balance and call modelsUpdated; return elapsed seconds
##   - currentSize()  - rowcount sanity check for QML asserts

import nimqml
import std/monotimes
import std/times

# OLD code (verbatim copy of master, suffixed with `Old`)
import bench_old/asset_group_item_old
import bench_old/io_interface_old
import bench_old/balances_model_old
import bench_old/grouped_account_assets_model_old
import bench_old/bench_service_old

# NEW code (production files reached via --path:src/)
import bench_new/bench_service_new
import app/modules/main/wallet_section/assets/grouped_account_assets_model as new_grouped_model

# ---------------------------------------------------------------------------
# Public C entry points
# ---------------------------------------------------------------------------

proc NimMain() {.importc.}

# ---------------------------------------------------------------------------
# Timing helper
# ---------------------------------------------------------------------------

template timeIt(body: untyped): float =
  let t0 = getMonoTime()
  body
  let t1 = getMonoTime()
  inNanoseconds(t1 - t0).float / 1_000_000_000.0

# ---------------------------------------------------------------------------
# BenchHarness QObject
# ---------------------------------------------------------------------------

QtObject:
  type
    BenchHarness* = ref object of QObject
      svcOld: BenchServiceOld
      svcNew: BenchServiceNew
      modelOld: GroupedAccountAssetsModelOld
      modelNew: new_grouped_model.Model
      modelOldVariant: QVariant
      modelNewVariant: QVariant

  proc setup(self: BenchHarness) =
    self.QObject.setup
    self.svcOld = newBenchServiceOld()
    self.svcNew = newBenchServiceNew()
    self.modelOld = newGroupedAccountAssetsModelOld(self.svcOld.dataSource())
    self.modelNew = new_grouped_model.newModel(self.svcNew.dataSource())
    self.modelOldVariant = newQVariant(self.modelOld)
    self.modelNewVariant = newQVariant(self.modelNew)

  proc delete(self: BenchHarness) =
    if not self.modelOldVariant.isNil:
      self.modelOldVariant.delete
    if not self.modelNewVariant.isNil:
      self.modelNewVariant.delete
    if not self.modelOld.isNil:
      self.modelOld.delete
    if not self.modelNew.isNil:
      self.modelNew.delete
    self.QObject.delete

  proc newBenchHarness*(): BenchHarness =
    new(result, delete)
    result.setup

  # ----- model accessors as Q_PROPERTY -----

  proc oldModelChanged(self: BenchHarness) {.signal.}
  proc getOldModel(self: BenchHarness): QVariant {.slot.} =
    return self.modelOldVariant
  QtProperty[QVariant] oldModel:
    read = getOldModel
    notify = oldModelChanged

  proc newModelChanged(self: BenchHarness) {.signal.}
  proc getNewModel(self: BenchHarness): QVariant {.slot.} =
    return self.modelNewVariant
  QtProperty[QVariant] newModel:
    read = getNewModel
    notify = newModelChanged

  # ----- one-shot dataset population -----

  proc populate*(self: BenchHarness, numTokens: int, numAccounts: int, numChains: int) {.slot.} =
    ## Builds an identical synthetic dataset in both services and pushes
    ## the new state to both models.  Idempotent - safe to call repeatedly.
    self.svcOld.populate(numTokens, numAccounts, numChains)
    self.svcNew.populate(numTokens, numAccounts, numChains)
    self.modelOld.modelsUpdated()
    self.modelNew.modelsUpdated()

  proc currentSize*(self: BenchHarness): int {.slot.} =
    ## Returns the OLD model's row count - used by QML asserts to make sure
    ## both models agree on size after populate().
    return self.modelOld.getCount()

  # ----- reset between scenarios -----
  #
  # Each pure* slot resets BOTH services AND BOTH models so the
  # measurement starts from a deterministic empty state.  Without this,
  # the test order leaks state across scenarios (e.g. running pureLoad(50)
  # after pureLoad(500) would measure a 500->50 shrink, not a fresh load).

  proc resetState(self: BenchHarness) =
    self.svcOld.clear()
    self.svcNew.clear()
    self.modelOld.modelsUpdated()
    self.modelNew.modelsUpdated()

  # ----- pure-model timing slots (return elapsed seconds) -----

  proc pureLoadOld*(self: BenchHarness, numTokens: int, numAccounts: int, numChains: int): float {.slot.} =
    ## Fresh load: reset to empty state, then populate + modelsUpdated.
    ## Returns elapsed seconds for the populate+update only (the reset is
    ## NOT included in the measurement).
    self.resetState()
    result = timeIt:
      self.svcOld.populate(numTokens, numAccounts, numChains)
      self.modelOld.modelsUpdated()

  proc pureLoadNew*(self: BenchHarness, numTokens: int, numAccounts: int, numChains: int): float {.slot.} =
    self.resetState()
    result = timeIt:
      self.svcNew.populate(numTokens, numAccounts, numChains)
      self.modelNew.modelsUpdated()

  proc pureUpdateOld*(self: BenchHarness): float {.slot.} =
    ## Re-populates the OLD service with the SAME shape (so the diff is
    ## effectively a no-op data-wise but the old model still does a full
    ## reset).  Returns elapsed seconds.
    let n = self.modelOld.getCount()
    if n == 0:
      return 0.0
    let accounts = if self.svcOld.groupedAssets.len > 0:
                     self.svcOld.groupedAssets[0].balancesPerAccount.len div max(1, self.modelOld.getCount() div n)
                   else:
                     0
    result = timeIt:
      self.svcOld.populate(n, max(1, accounts), 1)
      self.modelOld.modelsUpdated()

  proc pureUpdateNew*(self: BenchHarness): float {.slot.} =
    let n = self.modelNew.getCount()
    if n == 0:
      return 0.0
    result = timeIt:
      self.svcNew.populate(n, 1, 1)
      self.modelNew.modelsUpdated()

  proc simulateBalanceTickOld*(self: BenchHarness): float {.slot.} =
    ## One-row balance change scenario - the most common production case.
    ## OLD: rebuild the seq (no-op for ref objects since we mutate in
    ## place), then call modelsUpdated which does a FULL reset.
    result = timeIt:
      self.svcOld.bumpSingleBalance()
      self.modelOld.modelsUpdated()

  proc simulateBalanceTickNew*(self: BenchHarness): float {.slot.} =
    ## NEW: bump the value, swap a fresh CowSeq into the service, call
    ## modelsUpdated which runs setItemsWithSync and emits a single
    ## dataChanged for the affected nested-model row.
    result = timeIt:
      self.svcNew.bumpSingleBalance()
      self.modelNew.modelsUpdated()

# ---------------------------------------------------------------------------
# C entry: hand a QObject* back to the C++ host
# ---------------------------------------------------------------------------

# Keep a global reference so the GC doesn't reclaim the harness while QML
# holds a context property pointing at it.
var gHarness: BenchHarness

proc createBenchHarness*(): pointer {.exportc, dynlib, cdecl.} =
  gHarness = newBenchHarness()
  # `vptr` is the public accessor on nimqml.QObject - returns a
  # `DosQObject` (which is `distinct pointer`).  The underlying value IS a
  # real C++ `QObject*` because DOtherSide subclasses QObject and routes
  # virtual dispatch back to our Nim slots.  We must upcast to QObject so
  # the accessor (which lives on the QObject base type) is in scope.
  let asQObject: QObject = gHarness.QObject
  return cast[pointer](asQObject.vptr)

proc getOldModelPtr*(): pointer {.exportc, dynlib, cdecl.} =
  ## Returns the underlying QAbstractListModel* of the OLD model variant.
  ## Used by the C++ host to attach a QAbstractItemModelTester for
  ## contract validation.
  if gHarness.isNil or gHarness.modelOld.isNil:
    return nil
  let asQObject: QObject = gHarness.modelOld.QObject
  return cast[pointer](asQObject.vptr)

proc getNewModelPtr*(): pointer {.exportc, dynlib, cdecl.} =
  ## Returns the underlying QAbstractListModel* of the NEW model variant.
  if gHarness.isNil or gHarness.modelNew.isNil:
    return nil
  let asQObject: QObject = gHarness.modelNew.QObject
  return cast[pointer](asQObject.vptr)
