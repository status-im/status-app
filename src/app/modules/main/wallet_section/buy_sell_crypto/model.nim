import app/modules/shared_models/model_utils
import nimqml, tables

import item

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Name
    Description
    Fees
    LogoUrl
    Hostname
    SupportsSinglePurchase
    SupportsRecurrentPurchase
    SupportedAssets
    UrlsNeedParameters

QtObject:
  type
    Model* = ref object of QAbstractListModel
      list: seq[Item]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup()

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.list.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.Name.int:"name",
      ModelRole.Description.int:"description",
      ModelRole.Fees.int:"fees",
      ModelRole.LogoUrl.int:"logoUrl",
      ModelRole.Hostname.int:"hostname",
      ModelRole.SupportsSinglePurchase.int:"supportsSinglePurchase",
      ModelRole.SupportsRecurrentPurchase.int:"supportsRecurrentPurchase",
      ModelRole.SupportedAssets.int:"supportedAssets",
      ModelRole.UrlsNeedParameters.int:"urlsNeedParameters"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.list.len, role, ModelRole)

    let item = self.list[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Id:
      result = newQVariant(item.getId)
    of ModelRole.Name:
      result = newQVariant(item.getName)
    of ModelRole.Description:
      result = newQVariant(item.getDescription)
    of ModelRole.Fees:
      result = newQVariant(item.getFees)
    of ModelRole.LogoUrl:
      result = newQVariant(item.getLogoUrl)
    of ModelRole.Hostname:
      result = newQVariant(item.getHostname)
    of ModelRole.SupportsSinglePurchase:
      result = newQVariant(item.getSupportsSinglePurchase)
    of ModelRole.SupportsRecurrentPurchase:
      result = newQVariant(item.getSupportsRecurrentPurchase)
    of ModelRole.SupportedAssets:
      result = newQVariant(item.getSupportedAssets)
    of ModelRole.UrlsNeedParameters:
      result = newQVariant(item.getUrlsNeedParameters)

  proc setItems*(self: Model, items: seq[Item]) =
    self.beginResetModel()
    self.list = items
    self.endResetModel()

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
