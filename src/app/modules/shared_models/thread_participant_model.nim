import app/modules/shared_models/model_utils
import nimqml, tables

type
  Participant* = object
    id*: string
    name*: string
    image*: string
    colorId*: int

  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Name
    Image
    ColorId

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Participant]

  proc delete*(self: Model)
  proc setup(self: Model)

  proc newModel*(participants: seq[Participant] = @[]): Model =
    new(result, delete)
    result.setup
    result.items = participants

  method rowCount(self: Model, index: QModelIndex = nil): int =
    self.items.len

  proc count*(self: Model): int =
    self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Id.int: "id",
      ModelRole.Name.int: "name",
      ModelRole.Image.int: "image",
      ModelRole.ColorId.int: "colorId",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let participant = self.items[index.row]
    case role.ModelRole:
    of ModelRole.Id:
      result = newQVariant(participant.id)
    of ModelRole.Name:
      result = newQVariant(participant.name)
    of ModelRole.Image:
      result = newQVariant(participant.image)
    of ModelRole.ColorId:
      result = newQVariant(participant.colorId)
    else:
      result = newQVariant()

  proc setParticipants*(self: Model, participants: seq[Participant]) =
    self.beginResetModel()
    self.items = participants
    self.endResetModel()

  proc delete*(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
