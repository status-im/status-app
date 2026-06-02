import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils

import ./io_interface

import app_service/service/network/rpc_provider_item

type
  ModelRole {.pure.} = enum
    ChainId = UserRole + 1
    Id
    Name
    Url
    IsRpsLimiterEnabled
    ProviderType
    IsEnabled
    AuthType
    AuthLogin
    AuthPassword
    AuthToken

QtObject:
  type RpcProvidersModel* = ref object of QAbstractListModel
    delegate: io_interface.NetworksDataSource

  proc setup(self: RpcProvidersModel)
  proc delete(self: RpcProvidersModel)
  proc newRpcProvidersModel*(delegate: io_interface.NetworksDataSource): RpcProvidersModel =
    new(result, delete)
    result.setup
    result.delegate = delegate

  method rowCount(self: RpcProvidersModel, index: QModelIndex = nil): int =
    return self.delegate.getRpcProvidersList().len

  method roleNames(self: RpcProvidersModel): Table[int, string] =
    {
      ModelRole.ChainId.int:"chainId",
      ModelRole.Id.int:"id",
      ModelRole.Name.int:"name",
      ModelRole.Url.int:"url",
      ModelRole.IsRpsLimiterEnabled.int:"isRpsLimiterEnabled",
      ModelRole.ProviderType.int:"providerType",
      ModelRole.IsEnabled.int:"isEnabled",
      ModelRole.AuthType.int:"authType",
      ModelRole.AuthLogin.int:"authLogin",
      ModelRole.AuthPassword.int:"authPassword",
      ModelRole.AuthToken.int:"authToken",
    }.toTable

  method data(self: RpcProvidersModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    let item = self.delegate.getRpcProvidersList()[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.ChainId:
        result = newQVariant(item.chainId)
      of ModelRole.Id:
        result = newQVariant(item.id)
      of ModelRole.Name:
        result = newQVariant(item.name)
      of ModelRole.Url:
        result = newQVariant(item.url)
      of ModelRole.IsRpsLimiterEnabled:
        result = newQVariant(item.isRpsLimiterEnabled)
      of ModelRole.ProviderType:
        result = newQVariant($item.providerType)
      of ModelRole.IsEnabled:
        result = newQVariant(item.isEnabled)
      of ModelRole.AuthType:
        result = newQVariant($item.authType)
      of ModelRole.AuthLogin:
        result = newQVariant(item.authLogin)
      of ModelRole.AuthPassword:
        result = newQVariant(item.authPassword)
      of ModelRole.AuthToken:
        result = newQVariant(item.authToken)

  proc refreshModel*(self: RpcProvidersModel) =
    self.beginResetModel()
    self.endResetModel()

  proc setup(self: RpcProvidersModel) =
    self.QAbstractListModel.setup

  proc delete(self: RpcProvidersModel) =
    self.QAbstractListModel.delete
