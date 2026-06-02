import app/modules/shared_models/model_utils
import nimqml, tables
import token_permission_item
import token_permission_chat_list_item
import token_permission_chat_list_model
import token_criteria_model

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Key
    Type
    TokenCriteria
    ChatList
    IsPrivate
    TokenCriteriaMet
    State

QtObject:
  type TokenPermissionsModel* = ref object of QAbstractListModel
    items*: seq[TokenPermissionItem]

  proc setup(self: TokenPermissionsModel)
  proc delete(self: TokenPermissionsModel)
  proc newTokenPermissionsModel*(): TokenPermissionsModel =
    new(result, delete)
    result.setup

  method roleNames(self: TokenPermissionsModel): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.Key.int:"key",
      ModelRole.Type.int:"permissionType",
      ModelRole.TokenCriteria.int:"holdingsListModel",
      ModelRole.ChatList.int:"channelsListModel",
      ModelRole.IsPrivate.int:"isPrivate",
      ModelRole.TokenCriteriaMet.int:"tokenCriteriaMet",
      ModelRole.State.int:"permissionState",
    }.toTable

  proc countChanged(self: TokenPermissionsModel) {.signal.}
  proc getCount*(self: TokenPermissionsModel): int {.slot.} =
    return self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc findIndexById(self: TokenPermissionsModel, id: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].getId() == id):
        return i
    return -1

  proc renameChatById*(self: TokenPermissionsModel, chatId: string, newName: string) =
    for i in 0 ..< self.items.len:
      let item = self.items[i]
      item.getChatList().renameChatById(chatId, newName)

  proc belongsToChat*(self: TokenPermissionsModel, permissionId: string, chatId: string): bool {.slot.} =
    let idx = self.findIndexById(permissionId)
    if(idx == -1):
      return false

    for clItem in self.items[idx].chatList.getItems():
      if clItem.getKey() == chatId:
        return true

    return false

  method rowCount(self: TokenPermissionsModel, index: QModelIndex = nil): int =
    return self.items.len

  method data(self: TokenPermissionsModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Id:
        result = newQVariant(item.getId())
      of ModelRole.Key:
        result = newQVariant(item.getId())
      of ModelRole.Type:
        result = newQVariant(item.getType())
      of ModelRole.TokenCriteria:
        result = newQVariant(item.getTokenCriteria())
      of ModelRole.ChatList:
        result = newQVariant(item.getChatList())
      of ModelRole.IsPrivate:
        result = newQVariant(item.getIsPrivate())
      of ModelRole.TokenCriteriaMet:
        result = newQVariant(item.getTokenCriteriaMet())
      of ModelRole.State:
        result = newQVariant(item.getState())

  proc addItem*(self: TokenPermissionsModel, item: TokenPermissionItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc setItems*(self: TokenPermissionsModel, items: seq[TokenPermissionItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getItems*(self: TokenPermissionsModel): seq[TokenPermissionItem] =
    return self.items

  proc removeItemWithId*(self: TokenPermissionsModel, permissionId: string) =
    let idx = self.findIndexById(permissionId)
    if(idx == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, idx, idx)
    self.items.delete(idx)
    self.endRemoveRows()
    self.countChanged()

  proc getItemById*(self: TokenPermissionsModel, permissionId: string): TokenPermissionItem =
    let idx = self.findIndexById(permissionId)
    if(idx == -1):
      return

    return self.items[idx]

  proc tokenCriteriaUpdated(self: TokenPermissionsModel) {.signal.}

  proc updateItem*(self: TokenPermissionsModel, permissionId: string, item: TokenPermissionItem) =
    let idx = self.findIndexById(permissionId)
    if(idx == -1):
      return

    self.items[idx].`type` = item.`type`
    self.items[idx].tokenCriteria.setItems(item.tokenCriteria.getItems())
    self.items[idx].chatList.setItems(item.chatList.getItems())
    self.items[idx].isPrivate = item.isPrivate
    self.items[idx].tokenCriteriaMet = item.tokenCriteriaMet
    self.items[idx].state = item.state

    let index = self.createIndex(idx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[
      ModelRole.Type.int,
      ModelRole.TokenCriteria.int,
      ModelRole.ChatList.int,
      ModelRole.IsPrivate.int,
      ModelRole.TokenCriteriaMet.int,
      ModelRole.State.int
    ])
    self.tokenCriteriaUpdated()

  proc setup(self: TokenPermissionsModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenPermissionsModel) =
    self.QAbstractListModel.delete
