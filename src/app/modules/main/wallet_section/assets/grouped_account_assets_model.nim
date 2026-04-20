import nimqml, tables

import ./io_interface, ./balances_model
import app/core/cow_seq
import app/modules/shared/model_sync
import app_service/service/wallet_account/dto/asset_group_item

# Pattern 4 showcase: nested model with delegate-owned data.
#
# Producer (wallet_account.Service) owns a CowSeq[AssetGroupItem].  Each call
# to modelsUpdated() pulls a fresh CoW snapshot, diffs it against the
# model's `items` mirror via setItemsWithSync, and emits granular Qt
# notifications instead of a full beginResetModel/endResetModel.
#
# `items` is a plain `seq[AssetGroupItem]` (not a CowSeq) so applySync can
# mutate it IN LOCKSTEP with the begin*/end* signal pairs.  This is the
# only way Qt's row tracking stays consistent during the update - the
# previous CoW-based storage broke this contract because rowCount() and
# data() read from a snapshot that wasn't swapped until after all signals
# had fired.
#
# CoW remains valuable on the producer side: the wallet_account service
# holds its data in a CowSeq[AssetGroupItem], and the model borrows a
# stable snapshot for the diff via .borrow() (lent seq, zero-copy).  After
# the diff completes, the borrow is released and the producer's CowSeq
# refcount drops back to 1.
#
# Nested BalancesModel instances are kept in `balancesPerChain` in 1:1
# correspondence with `items` - inserts/removes shift the array via
# `insert(idx)`/`delete(idx)` and the affected nested models' index field
# is renumbered to match.

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1, # groupKey (crossChainId or tokenKey if crossChainId is empty)
    Balances

QtObject:
  type
    Model* = ref object of QAbstractListModel
      delegate: io_interface.GroupedAccountAssetsDataSource
      items: seq[AssetGroupItem]               # plain seq mirror, mutated in lockstep
      balancesPerChain: seq[BalancesModel]     # one nested model per row, indexed in lockstep with items

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(delegate: io_interface.GroupedAccountAssetsDataSource): Model =
    new(result, delete)
    result.setup
    result.delegate = delegate

  proc countChanged(self: Model) {.signal.}
  proc getCount*(self: Model): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.Balances.int:"balances",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if index.row < 0 or index.row >= self.rowCount() or
      index.row >= self.balancesPerChain.len:
      return

    # Guard against unknown roles - QAbstractItemModelTester probes models
    # with Qt::DisplayRole etc. and a raw `role.ModelRole` cast would
    # raise RangeDefect.  Return an empty QVariant for anything that isn't
    # one of our own roles.
    if role < ModelRole.low.int or role > ModelRole.high.int:
      return

    let enumRole = role.ModelRole
    let item = self.items[index.row]
    case enumRole:
    of ModelRole.Key:
      result = newQVariant(item.key)
    of ModelRole.Balances:
      result = newQVariant(self.balancesPerChain[index.row])

  proc modelsUpdated*(self: Model) =
    # Pull a fresh CoW snapshot from the producer.  O(1) - just bumps the
    # refcount on the producer's buffer.  The model's `items` field is a
    # plain seq, mutated in-place by setItemsWithSync.
    var snapshot = self.delegate.getGroupedAssetsList()

    setItemsWithSync(
      self,
      self.items,
      snapshot.borrow(),                       # zero-copy view
      getId = proc(it: AssetGroupItem): string = it.key,
      getRoles = proc(o, n: AssetGroupItem): seq[int] =
        if o.balancesPerAccount != n.balancesPerAccount:
          @[ModelRole.Balances.int]
        else:
          @[],
      countChanged = proc() = self.countChanged(),
      useBulkOps = true,

      onInsert = proc(idx: int, item: AssetGroupItem) =
        # New row.  Construct a fresh nested model and bulk-load its mirror
        # WITHOUT emitting signals (the model has no view attached yet).
        # This is the small-N perf fix: avoids the per-row signal cost.
        let nested = newBalancesModel()
        nested.setInitialItems(item.balancesPerAccount)
        self.balancesPerChain.insert(nested, idx),

      onUpdate = proc(idx: int, oldItem, newItem: AssetGroupItem) =
        # Stable row, balances changed.  Diff the nested seq for granular
        # dataChanged emissions on the nested model.
        self.balancesPerChain[idx].update(newItem.balancesPerAccount),

      onRemove = proc(idx: int) =
        # Row gone - drop the corresponding nested model.  Subsequent
        # nested models slide left automatically; their internal state
        # doesn't depend on a positional index any more.
        if idx >= 0 and idx < self.balancesPerChain.len:
          self.balancesPerChain.delete(idx),
    )

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
    self.items = @[]
    self.balancesPerChain = @[]

# Test-only accessors.  We expose JUST enough to (a) measure that the
# nested model array is in lockstep with `items`, and (b) hand back a
# nested model REF so the test can call `data()` on it directly.  Every
# actual value read in the tests goes through QAbstractItemModel::data()
# (this proc only exists because nimqml has no QVariant -> QObject
# extraction, so the test can't unwrap a `data(parent, BalancesRole)`
# result back to a Nim ref).  Stripped from production builds.
when defined(testing):
  proc nestedCount*(self: Model): int =
    return self.balancesPerChain.len

  proc nestedAt*(self: Model, idx: int): BalancesModel =
    if idx < 0 or idx >= self.balancesPerChain.len:
      return nil
    return self.balancesPerChain[idx]
