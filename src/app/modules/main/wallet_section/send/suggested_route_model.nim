import nimqml, tables, strutils, std/strformat

import ./suggested_route_item

type
  ModelRole {.pure.} = enum
    Route = UserRole + 1,

QtObject:
  type
    SuggestedRouteModel* = ref object of QAbstractListModel
      items*: seq[SuggestedRouteItem]

  proc delete(self: SuggestedRouteModel)
  proc setup(self: SuggestedRouteModel)
  proc newSuggestedRouteModel*(): SuggestedRouteModel =
    new(result, delete)
    result.setup

  proc `$`*(self: SuggestedRouteModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: SuggestedRouteModel) {.signal.}

  proc getCount*(self: SuggestedRouteModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc firstItem*(self: SuggestedRouteModel): QVariant {.slot.} =
    let index = 0
    if index < 0 or index >= self.items.len:
      return newQVariant(newSuggestedRouteItem())
    return newQVariant(self.items[index])

  method rowCount(self: SuggestedRouteModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: SuggestedRouteModel): Table[int, string] =
    {
      ModelRole.Route.int:"route",
    }.toTable

  proc setItems*(self: SuggestedRouteModel, items: seq[SuggestedRouteItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  method data(self: SuggestedRouteModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Route:
      result = newQVariant(item)

  proc delete(self: SuggestedRouteModel) =
    self.QAbstractListModel.delete

  proc setup(self: SuggestedRouteModel) =
    self.QAbstractListModel.setup

