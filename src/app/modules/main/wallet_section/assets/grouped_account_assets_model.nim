import app/modules/shared_models/model_utils
import nimqml, tables, algorithm, sequtils, sets

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

  proc syncKey(it: AssetGroupItem): string = it.key
  # No syncRoles(AssetGroupItem): the only exposed roles are Key (stable per id) and
  # Balances (stable object identity per key). Balance value changes travel through the
  # BalancesModel's own dataChanged, so surviving rows need no parent-level dataChanged;
  # omitting syncRoles leaves modelSync's getRoles nil, syncing the group SET only.

  proc reconcileBalances(self: Model, newGroups: seq[AssetGroupItem]) =
    # Rebuild balancesByKey identity-preservingly: keep the existing BalancesModel for
    # a surviving group key (QML is bound to it) and push its fresh balances in place,
    # create one for a new key, drop removed keys. Done BEFORE modelSync announces
    # inserts so data(Balances) is populated for a newly inserted row within this same
    # call (mirrors token_groups_model's market-details F1 fix).
    reconcileByKey(self.balancesByKey, newGroups,
      create = proc(g: AssetGroupItem): BalancesModel =
        newBalancesModel(g.balancesPerAccount),
      update = proc(bm: BalancesModel, g: AssetGroupItem) =
        bm.updateBalances(g.balancesPerAccount))

  proc modelsUpdated*(self: Model) =
    # The service builds groupedAssets via Table.values() (hash order), which can
    # reshuffle between refreshes even for an unchanged key set. The display order is
    # decided downstream by the AssetsView SortFilterProxyModel, so this model's row
    # order is display-irrelevant; sort by key here to give modelSync a deterministic
    # order and avoid spurious per-cycle moves. Key-sorted so survivors keep their
    # relative order across refreshes: the diff of matched ids never reorders (only
    # inserts/removes at sorted positions), so the remove+insert reorder path is never
    # exercised here.
    let newGroups = self.delegate.getGroupedAssetsList().sorted(
      proc(a, b: AssetGroupItem): int = cmp(a.key, b.key))
    # Keep every BalancesModel this refresh removes alive on the stack until AFTER
    # modelSync has emitted its remove signals. balancesByKey is a dropped child's
    # SOLE ORC owner, and reconcileBalances (below) frees it synchronously the moment
    # it drops the key — which is BEFORE modelSync announces the row removal. QML
    # delegates still hold the raw BalancesModel* handed out via data(Balances) (a
    # nimqml QVariant of a QObject does not keep the Nim ref alive), so freeing it
    # first is a use-after-free during the delegate's own row teardown. This local
    # seq outlives the whole proc, so ORC frees the dropped models only after the
    # view has torn the rows down.
    let survivingKeys = newGroups.mapIt(it.key).toHashSet
    var retained {.used.}: seq[BalancesModel] = @[]
    for key, bm in self.balancesByKey:
      if key notin survivingKeys:
        retained.add(bm)
    self.reconcileBalances(newGroups)
    self.modelSync(self.items, newGroups)

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
