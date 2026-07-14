import nimqml, tables

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import ./collectibles_selector_item
import ./collectibles_selector_builder
import ./collectibles_selector_flat_model
import ./collectibles_selector_subitems_model
export collectibles_selector_item, collectibles_selector_builder,
  collectibles_selector_flat_model, collectibles_selector_subitems_model

when defined(QT_MODEL_SPY):
  import app/modules/shared/qt_model_spy

# CollectiblesSelectorModel — terminal model for the send modal's collectibles
# picker. Replaces CollectiblesSelectionAdaptor's QML proxy graph (LeftJoin ->
# per-row ObjectProxyModel with ownership SFPM + SumAggregator -> RangeFilter ->
# sort -> GroupingModel -> nested per-community GroupingModel), whose cost is
# O(GLOBAL collectibles universe).
#
# It owns TWO views, mirroring the adaptor:
#   - itself: the grouped model (community / collection groups with a nested
#     subitems submodel per group);
#   - `filteredFlatModel`: the input-shaped, account+chain-filtered flat rows the
#     deep-link resolution + flat delegates read.
#
# The producer pushes plain Nim seqs via setSource; recompute() runs the pure
# builder (one O(global) scan, no per-row QObjects) then diffs both views into
# place via modelSync — a balance tick on a shown collectible is a single
# nested-row dataChanged, an account switch is O(displayed) inserts/removes, and
# nothing resets.

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1     ## groupKey (groupingValue)
    GroupName
    Icon
    IconUrl
    ImageUrl
    MediaUrl
    Type
    Subitems

QtObject:
  type
    CollectiblesSelectorModel* = ref object of QAbstractListModel
      groups: seq[CollectibleGroup]
      # One nested subitems model per group KEY, preserved across refreshes so
      # QML keeps its bound submodel alive; subitem changes travel through it.
      subitemsByKey: Table[string, CollectiblesSelectorSubitemsModel]
      flatModel: CollectiblesSelectorFlatModel
      # Producer-driven inputs the model re-derives its rows from on any change.
      source: seq[CollectibleItem]
      networks: seq[CollectiblesNetworkInfo]
      params: CollectiblesSelectorParams

  proc delete(self: CollectiblesSelectorModel)
  proc setup(self: CollectiblesSelectorModel)
  proc newCollectiblesSelectorModel*(): CollectiblesSelectorModel =
    new(result, delete)
    result.setup
    result.subitemsByKey = initTable[string, CollectiblesSelectorSubitemsModel]()
    result.flatModel = newCollectiblesSelectorFlatModel()

  proc countChanged(self: CollectiblesSelectorModel) {.signal.}
  proc getCount*(self: CollectiblesSelectorModel): int {.slot.} =
    return self.groups.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc getFilteredFlatModel(self: CollectiblesSelectorModel): QVariant {.slot.} =
    newQVariant(self.flatModel)
  QtProperty[QVariant] filteredFlatModel:
    read = getFilteredFlatModel

  method rowCount(self: CollectiblesSelectorModel, index: QModelIndex = nil): int =
    return self.groups.len

  method roleNames(self: CollectiblesSelectorModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.GroupName.int: "groupName",
      ModelRole.Icon.int: "icon",
      ModelRole.IconUrl.int: "iconUrl",
      ModelRole.ImageUrl.int: "imageUrl",
      ModelRole.MediaUrl.int: "mediaUrl",
      ModelRole.Type.int: "type",
      ModelRole.Subitems.int: "subitems",
    }.toTable

  method data(self: CollectiblesSelectorModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let group = self.groups[index.row]
    case role.ModelRole:
    of ModelRole.Key: return newQVariant(group.groupKey)
    of ModelRole.GroupName: return newQVariant(group.groupName)
    of ModelRole.Icon: return newQVariant(group.icon)
    of ModelRole.IconUrl: return newQVariant(group.iconUrl)
    of ModelRole.ImageUrl: return newQVariant(group.imageUrl)
    of ModelRole.MediaUrl: return newQVariant(group.mediaUrl)
    of ModelRole.Type: return newQVariant(group.groupType)
    of ModelRole.Subitems:
      if self.subitemsByKey.hasKey(group.groupKey):
        return newQVariant(self.subitemsByKey[group.groupKey])

  proc syncKey(it: CollectibleGroup): string = it.groupKey
  proc syncRoles(o, n: CollectibleGroup): seq[int] =
    result = @[]
    if o.groupName != n.groupName: result.add(ModelRole.GroupName.int)
    if o.icon != n.icon: result.add(ModelRole.Icon.int)
    if o.iconUrl != n.iconUrl: result.add(ModelRole.IconUrl.int)
    if o.imageUrl != n.imageUrl: result.add(ModelRole.ImageUrl.int)
    if o.mediaUrl != n.mediaUrl: result.add(ModelRole.MediaUrl.int)
    if o.groupType != n.groupType: result.add(ModelRole.Type.int)
    # Subitems travel through the nested model's own signals, so no parent-level
    # dataChanged for the Subitems role here.

  proc setGroups(self: CollectiblesSelectorModel, newGroups: seq[CollectibleGroup]) =
    # Reconcile the per-key nested subitems models BEFORE modelSync announces
    # inserts, so data(Subitems) is populated for a newly inserted group within
    # this same call. The update closure recurses into the surviving child model.
    reconcileByKey(self.subitemsByKey, newGroups,
      create = proc(g: CollectibleGroup): CollectiblesSelectorSubitemsModel =
        newCollectiblesSelectorSubitemsModel(g.subitems),
      update = proc(sm: CollectiblesSelectorSubitemsModel, g: CollectibleGroup) =
        sm.setSubItems(g.subitems))
    self.modelSync(self.groups, newGroups)

  proc recompute(self: CollectiblesSelectorModel) =
    let display = buildDisplay(self.source, self.networks, self.params)
    self.flatModel.setRows(display.flat)
    self.setGroups(display.groups)

  proc setSource*(self: CollectiblesSelectorModel, items: seq[CollectibleItem],
      networks: seq[CollectiblesNetworkInfo]) =
    ## Producer push of the raw collectibles universe + network join data.
    self.source = items
    self.networks = networks
    self.recompute()

  proc setNetworks*(self: CollectiblesSelectorModel, networks: seq[CollectiblesNetworkInfo]) =
    self.networks = networks
    self.recompute()

  proc setParams*(self: CollectiblesSelectorModel, params: CollectiblesSelectorParams) =
    self.params = params
    self.recompute()

  # Param setters exposed for the QML sites to drive declaratively; each guards
  # and recomputes.
  proc setAccountKey*(self: CollectiblesSelectorModel, accountKey: string) {.slot.} =
    if accountKey == self.params.accountKey: return
    self.params.accountKey = accountKey
    self.recompute()
  proc getAccountKey(self: CollectiblesSelectorModel): string {.slot.} =
    self.params.accountKey
  QtProperty[string] accountKey:
    read = getAccountKey
    write = setAccountKey

  proc setEnabledChainIds*(self: CollectiblesSelectorModel, chainIds: seq[int]) =
    if chainIds == self.params.enabledChainIds: return
    self.params.enabledChainIds = chainIds
    self.recompute()

  # Single-chain convenience for the send modal. Faithful to the retired adaptor's
  # `enabledChainIds: [selectedChainId]`: the value maps to a single-element list
  # (chainId 0 therefore filters to nothing, exactly as before), so the picker
  # shows the selected chain's collectibles.
  proc setEnabledChainId*(self: CollectiblesSelectorModel, chainId: int) {.slot.} =
    self.setEnabledChainIds(@[chainId])
  proc getEnabledChainId(self: CollectiblesSelectorModel): int {.slot.} =
    if self.params.enabledChainIds.len > 0: self.params.enabledChainIds[0] else: 0
  QtProperty[int] enabledChainId:
    read = getEnabledChainId
    write = setEnabledChainId

  proc setFilterCommunityOwnerAndMasterTokens*(self: CollectiblesSelectorModel, value: bool) {.slot.} =
    if value == self.params.filterCommunityOwnerAndMasterTokens: return
    self.params.filterCommunityOwnerAndMasterTokens = value
    self.recompute()
  proc getFilterCommunityOwnerAndMasterTokens(self: CollectiblesSelectorModel): bool {.slot.} =
    self.params.filterCommunityOwnerAndMasterTokens
  QtProperty[bool] filterCommunityOwnerAndMasterTokens:
    read = getFilterCommunityOwnerAndMasterTokens
    write = setFilterCommunityOwnerAndMasterTokens

  proc delete(self: CollectiblesSelectorModel) =
    # The nested subitems models + the flat model are new(_, delete), so ORC runs
    # their finalizers when the fields are collected. Match the repo convention
    # (token_selector_model): only tear down self.
    self.QAbstractListModel.delete

  proc setup(self: CollectiblesSelectorModel) =
    self.QAbstractListModel.setup

  when defined(testing) or defined(QT_MODEL_SPY):
    proc groupKeysInOrder*(self: CollectiblesSelectorModel): seq[string] =
      for g in self.groups: result.add(g.groupKey)
    proc groupTypeAt*(self: CollectiblesSelectorModel, i: int): string =
      self.groups[i].groupType
    proc groupNameAt*(self: CollectiblesSelectorModel, i: int): string =
      self.groups[i].groupName
    proc groupImageUrlAt*(self: CollectiblesSelectorModel, i: int): string =
      self.groups[i].imageUrl
    proc groupMediaUrlAt*(self: CollectiblesSelectorModel, i: int): string =
      self.groups[i].mediaUrl
    proc groupRoleNamesForTest*(self: CollectiblesSelectorModel): seq[string] =
      for _, name in self.roleNames(): result.add(name)
    proc subitemsModelForKey*(self: CollectiblesSelectorModel,
        key: string): CollectiblesSelectorSubitemsModel =
      if self.subitemsByKey.hasKey(key): return self.subitemsByKey[key]
      return nil
    proc flatModelForTest*(self: CollectiblesSelectorModel): CollectiblesSelectorFlatModel =
      self.flatModel
