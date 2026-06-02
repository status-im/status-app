import app/modules/shared_models/model_utils
import nimqml, tables
import token_permission_chat_list_item

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    ChannelName

QtObject:
  type TokenPermissionChatListModel* = ref object of QAbstractListModel
    items*: seq[TokenPermissionChatListItem]

  proc setup(self: TokenPermissionChatListModel)
  proc delete(self: TokenPermissionChatListModel)
  proc newTokenPermissionChatListModel*(): TokenPermissionChatListModel =
    new(result, delete)
    result.setup

  method roleNames(self: TokenPermissionChatListModel): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.ChannelName.int:"channelName",
    }.toTable

  proc countChanged(self: TokenPermissionChatListModel) {.signal.}
  proc getCount(self: TokenPermissionChatListModel): int {.slot.} =
    self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: TokenPermissionChatListModel, index: QModelIndex = nil): int =
    return self.items.len

  method data(self: TokenPermissionChatListModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Key:
        result = newQVariant(item.getKey())
      of ModelRole.ChannelName:
        result = newQVariant(item.getChannelName())

  proc addItem*(self: TokenPermissionChatListModel, item: TokenPermissionChatListItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc setItems*(self: TokenPermissionChatListModel, items: seq[TokenPermissionChatListItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getItems*(self: TokenPermissionChatListModel): seq[TokenPermissionChatListItem] =
    return self.items

  proc renameChatById*(self: TokenPermissionChatListModel, chatId: string, newName: string) =
    for i in 0 ..< self.items.len:
      if self.items[i].getKey() == chatId:
        self.items[i] = initTokenPermissionChatListItem(chatId, newName)
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[ModelRole.ChannelName.int])
        return

  proc setup(self: TokenPermissionChatListModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenPermissionChatListModel) =
    self.QAbstractListModel.delete
