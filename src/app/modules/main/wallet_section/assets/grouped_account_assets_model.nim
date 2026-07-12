import app/modules/shared_models/model_utils
import nimqml, tables, algorithm

import app_service/service/wallet_account/dto/asset_group_item
import app/modules/shared/model_sync
import ./io_interface, ./balances_model

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1, # groupKey (crossChainId or tokenKey if crossChainId is empty)
    Balances

QtObject:
  type
    Model* = ref object of QAbstractListModel
      delegate: io_interface.GroupedAccountAssetsDataSource
      # Cached display snapshot, diffed against the incoming group list on every
      # refresh so we emit granular insert/remove/move/dataChanged instead of a full
      # beginResetModel. A reset here tears down the entire AssetsView
      # proxy chain (LeftJoinModel -> ObjectProxyModel -> SFPMs -> ListView delegates).
      items: seq[AssetGroupItem]
      # One BalancesModel per group KEY (not per positional index), preserved across
      # refreshes so QML keeps its nested filteredBalances SFPM + aggregators alive.
      # The BalancesModel delivers balance changes via its own granular signals.
      balancesByKey: Table[string, BalancesModel]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(delegate: io_interface.GroupedAccountAssetsDataSource): Model =
    new(result, delete)
    result.setup
    result.delegate = delegate
    result.balancesByKey = initTable[string, BalancesModel]()

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
    guardModelData(index, self.rowCount(), role, ModelRole)

    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
    of ModelRole.Key:
      result = newQVariant(item.key)
    of ModelRole.Balances:
      if self.balancesByKey.hasKey(item.key):
        result = newQVariant(self.balancesByKey[item.key])

  proc reconcileBalances(self: Model, newGroups: seq[AssetGroupItem]) =
    # Rebuild balancesByKey identity-preservingly: keep the existing BalancesModel for
    # a surviving group key (QML is bound to it) and push its fresh balances in place,
    # create one for a new key, drop removed keys. Done BEFORE setItemsWithSync
    # announces inserts so data(Balances) is populated for a newly inserted row within
    # this same call (mirrors token_groups_model's market-details F1 fix).
    var updated = initTable[string, BalancesModel]()
    for group in newGroups:
      if self.balancesByKey.hasKey(group.key):
        let bm = self.balancesByKey[group.key]
        bm.updateBalances(group.balancesPerAccount)
        updated[group.key] = bm
      else:
        updated[group.key] = newBalancesModel(group.balancesPerAccount)
    self.balancesByKey = updated

  proc modelsUpdated*(self: Model) =
    # The service builds groupedAssets via Table.values() (hash order), which can
    # reshuffle between refreshes even for an unchanged key set. The display order is
    # decided downstream by the AssetsView SortFilterProxyModel, so this model's row
    # order is display-irrelevant; sort by key here to give setItemsWithSync a
    # deterministic order and avoid spurious per-cycle moves.
    let newGroups = self.delegate.getGroupedAssetsList().sorted(
      proc(a, b: AssetGroupItem): int = cmp(a.key, b.key))
    self.reconcileBalances(newGroups)
    # getRoles=nil: the only exposed roles are Key (stable per id) and Balances (stable
    # object identity per key); balance value changes travel through the BalancesModel's
    # own dataChanged, so surviving rows need no parent-level dataChanged. Only the group
    # SET is synced here.
    # Key-sorted above so survivors keep their relative order across refreshes: the
    # diff of matched ids never reorders (only inserts/removes at sorted positions),
    # so syncModel's remove+insert reorder path is never exercised here.
    setItemsWithSync(
      self, self.items, newGroups,
      getId = proc(item: AssetGroupItem): string = item.key,
      countChanged = proc() = self.countChanged())

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

  # Test-only accessors (used by grouped_account_assets_model_test).
  proc groupKeysInOrder*(self: Model): seq[string] =
    result = @[]
    for item in self.items:
      result.add(item.key)
  proc balancesModelForKey*(self: Model, key: string): BalancesModel =
    if self.balancesByKey.hasKey(key):
      return self.balancesByKey[key]
    return nil
