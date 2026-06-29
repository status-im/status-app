import app/modules/shared_models/model_utils
import nimqml, tables
import item

import ../../../../../app_service/service/settings/dto/settings
import ../../../shared_models/model_utils

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Name
    Image
    Color
    Type
    Customized
    MuteAllMessages
    PersonalMentions
    GlobalMentions
    OtherMessages
    JoinedTimestamp

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete*(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Id.int:"itemId",
      ModelRole.Name.int:"name",
      ModelRole.Image.int:"image",
      ModelRole.Color.int:"color",
      ModelRole.Type.int:"type",
      ModelRole.Customized.int:"customized",
      ModelRole.MuteAllMessages.int:"muteAllMessages",
      ModelRole.PersonalMentions.int:"personalMentions",
      ModelRole.GlobalMentions.int:"globalMentions",
      ModelRole.OtherMessages.int:"otherMessages",
      ModelRole.JoinedTimestamp.int:"joinedTimestamp"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Id:
      result = newQVariant(item.id)
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.Image:
      result = newQVariant(item.image)
    of ModelRole.Color:
      result = newQVariant(item.color)
    of ModelRole.Type:
      result = newQVariant(item.itemType.int)
    of ModelRole.Customized:
      result = newQVariant(item.customized)
    of ModelRole.MuteAllMessages:
      result = newQVariant(item.muteAllMessages)
    of ModelRole.PersonalMentions:
      result = newQVariant(item.personalMentions)
    of ModelRole.GlobalMentions:
      result = newQVariant(item.globalMentions)
    of ModelRole.OtherMessages:
      result = newQVariant(item.otherMessages)
    of ModelRole.JoinedTimestamp:
      result = newQVariant(item.joinedTimestamp)

  proc addItem*(self: Model, item: Item) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    let position = self.items.len

    self.beginInsertRows(parentModelIndex, position, position)
    self.items.add(item)
    self.endInsertRows()

  proc setItems*(self: Model, items: seq[Item]) =
    if items.len == 0:
      return

    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc findIndexForItemId*(self: Model, id: string): int =
    var ind = 0
    for it in self.items:
      if it.id == id:
        return ind
      ind.inc
    return -1

  proc removeItemById*(self: Model, id: string) =
    let ind = self.findIndexForItemId(id)
    if ind == -1:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, ind, ind)
    self.items.delete(ind)
    self.endRemoveRows()

  proc updateExemptions*(self: Model, id: string, muteAllMessages = false, personalMentions = VALUE_NOTIF_SEND_ALERTS, 
    globalMentions = VALUE_NOTIF_SEND_ALERTS, otherMessages = VALUE_NOTIF_TURN_OFF) =
    updateItemRolesAndNotify self.findIndexForItemId(id):
      updateRole(muteAllMessages)
      updateRole(personalMentions)
      updateRole(globalMentions)
      updateRole(otherMessages)
      if roles.len > 0:
        roles.add(ModelRole.Customized.int)

  proc updateName*(self: Model, id: string, name: string) =
    let ind = self.findIndexForItemId(id)
    if ind == -1 or self.items[ind].name == name:
      return

    self.items[ind].name = name

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.Name.int])

  proc updateItem*(self: Model, id, name, image, color: string) =
    updateItemRolesAndNotify self.findIndexForItemId(id):
      updateRole(name)
      updateRole(image)
      updateRole(color)

  proc delete*(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

