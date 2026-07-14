import nimqml, tables

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import ./collectibles_selector_item
export collectibles_selector_item

# Per-group nested model of subitems (collectibles for "other" groups, collections
# for community groups) the picker's sublist delegate renders. Held by the parent
# CollectiblesSelectorModel per group KEY (not positional index) so it survives the
# parent's granular reorders; the parent pushes fresh subitems via setSubItems(),
# which diffs against this snapshot and emits granular dataChanged/insert/remove.

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    Name
    Balance
    Icon
    IconUrl

QtObject:
  type
    CollectiblesSelectorSubitemsModel* = ref object of QAbstractListModel
      items: seq[CollectibleSubItem]

  proc setup(self: CollectiblesSelectorSubitemsModel)
  proc delete(self: CollectiblesSelectorSubitemsModel)
  proc newCollectiblesSelectorSubitemsModel*(
      items: seq[CollectibleSubItem] = @[]): CollectiblesSelectorSubitemsModel =
    new(result, delete)
    result.setup
    result.items = items

  proc countChanged(self: CollectiblesSelectorSubitemsModel) {.signal.}
  proc getCount(self: CollectiblesSelectorSubitemsModel): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: CollectiblesSelectorSubitemsModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: CollectiblesSelectorSubitemsModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.Name.int: "name",
      ModelRole.Balance.int: "balance",
      ModelRole.Icon.int: "icon",
      ModelRole.IconUrl.int: "iconUrl",
    }.toTable

  method data(self: CollectiblesSelectorSubitemsModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let item = self.items[index.row]
    case role.ModelRole:
    of ModelRole.Key: return newQVariant(item.key)
    of ModelRole.Name: return newQVariant(item.name)
    of ModelRole.Balance: return newQVariant(item.balance)
    of ModelRole.Icon: return newQVariant(item.icon)
    of ModelRole.IconUrl: return newQVariant(item.iconUrl)

  proc subItemRoles(o, n: CollectibleSubItem): seq[int] =
    result = @[]
    if o.name != n.name: result.add(ModelRole.Name.int)
    if o.balance != n.balance: result.add(ModelRole.Balance.int)
    if o.icon != n.icon: result.add(ModelRole.Icon.int)
    if o.iconUrl != n.iconUrl: result.add(ModelRole.IconUrl.int)

  proc setSubItems*(self: CollectiblesSelectorSubitemsModel, items: seq[CollectibleSubItem]) =
    setItemsWithSync(
      self, self.items, items,
      getId = proc(it: CollectibleSubItem): string = it.key,
      getRoles = proc(o, n: CollectibleSubItem): seq[int] = subItemRoles(o, n),
      countChanged = proc() = self.countChanged(),
      useBulkOps = true)

  proc setup(self: CollectiblesSelectorSubitemsModel) =
    self.QAbstractListModel.setup

  proc delete(self: CollectiblesSelectorSubitemsModel) =
    self.QAbstractListModel.delete

  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: CollectiblesSelectorSubitemsModel): seq[string] =
      for it in self.items: result.add(it.key)
    proc balancesInOrder*(self: CollectiblesSelectorSubitemsModel): seq[int] =
      for it in self.items: result.add(it.balance)
