import app/modules/shared_models/model_utils
import nimqml, tables
import curated_community_item
import ../../../shared_models/token_permission_item

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Available
    Name
    Description
    Icon
    Banner
    Featured
    Members
    ActiveMembers
    Popularity
    Color
    Tags
    Permissions
    AmIBanned
    Joined
    Encrypted

QtObject:
  type CuratedCommunityModel* = ref object of QAbstractListModel
    items: seq[CuratedCommunityItem]

  proc setup(self: CuratedCommunityModel)
  proc delete(self: CuratedCommunityModel)
  proc newCuratedCommunityModel*(): CuratedCommunityModel =
    new(result, delete)
    result.setup

  proc countChanged(self: CuratedCommunityModel) {.signal.}

  proc setItems*(self: CuratedCommunityModel, items: seq[CuratedCommunityItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getCount(self: CuratedCommunityModel): int {.slot.} =
    self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: CuratedCommunityModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: CuratedCommunityModel): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.Name.int:"name",
      ModelRole.Available.int:"available",
      ModelRole.Description.int:"description",
      ModelRole.Icon.int:"icon",
      ModelRole.Banner.int:"banner",
      ModelRole.Featured.int:"featured",
      ModelRole.Members.int:"members",
      ModelRole.ActiveMembers.int:"activeMembers",
      ModelRole.Color.int:"color",
      ModelRole.Popularity.int:"popularity",
      ModelRole.Tags.int:"tags",
      ModelRole.Permissions.int:"permissionsModel",
      ModelRole.AmIBanned.int:"amIBanned",
      ModelRole.Joined.int:"joined",
      ModelRole.Encrypted.int:"encrypted"
    }.toTable

  method data(self: CuratedCommunityModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Id:
        result = newQVariant(item.getId())
      of ModelRole.Name:
        result = newQVariant(item.getName())
      of ModelRole.Description:
        result = newQVariant(item.getDescription())
      of ModelRole.Available:
        result = newQVariant(item.isAvailable())
      of ModelRole.Icon:
        result = newQVariant(item.getIcon())
      of ModelRole.Banner:
        result = newQVariant(item.getBanner())
      of ModelRole.Members:
        result = newQVariant(item.getMembers())
      of ModelRole.ActiveMembers:
        result = newQVariant(item.getActiveMembers())
      of ModelRole.Color:
        result = newQVariant(item.getColor())
      of ModelRole.Popularity:
        # TODO: replace this with a real value
        result = newQVariant(index.row)
      of ModelRole.Tags:
        result = newQVariant(item.getTags())
      of ModelRole.Permissions:
        result = newQVariant(item.getPermissionsModel())
      of ModelRole.Featured:
        result = newQVariant(item.getFeatured())
      of ModelRole.AmIBanned:
        result = newQVariant(item.getAmIBanned())
      of ModelRole.Joined:
        result = newQVariant(item.getJoined())
      of ModelRole.Encrypted:
        result = newQVariant(item.getEncrypted())

  proc findIndexById(self: CuratedCommunityModel, id: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].getId() == id):
        return i
    return -1

  proc getItemById*(self: CuratedCommunityModel, id: string): CuratedCommunityItem =
    let ind = self.findIndexById(id)
    if(ind == -1):
      return

    return self.items[ind]

  proc containsItemWithId*(self: CuratedCommunityModel, id: string): bool =
    return self.findIndexById(id) != -1

  proc removeItemWithId*(self: CuratedCommunityModel, id: string) =
    let ind = self.findIndexById(id)
    if(ind == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, ind, ind)
    self.items.delete(ind)
    self.endRemoveRows()
    self.countChanged()

  proc addItem*(self: CuratedCommunityModel, item: CuratedCommunityItem) =
    let idx = self.findIndexById(item.getId())
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      self.items[idx] = item
      self.dataChanged(index, index)
    else:
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete
      self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
      self.items.add(item)
      self.endInsertRows()
      self.countChanged()

  proc setPermissionItems*(self: CuratedCommunityModel, itemId: string, items: seq[TokenPermissionItem]) =
    let idx = self.findIndexById(itemId)
    if idx == -1:
      echo "Tried to set permission items on an item that doesn't exist. Item ID: ", itemId
      return
    self.items[idx].setPermissionModelItems(items)

  proc setup(self: CuratedCommunityModel) =
    self.QAbstractListModel.setup

  proc delete(self: CuratedCommunityModel) =
    self.QAbstractListModel.delete
