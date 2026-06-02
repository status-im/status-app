import app/modules/shared_models/model_utils
import nimqml, tables

import io_interface
import tokens_model
type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Name
    Timestamp
    FetchedTimestamp
    Source
    Version
    LogoURI
    Tokens


QtObject:
  type TokenListsModel* = ref object of QAbstractListModel
    delegate: io_interface.TokenListsModelDataSource
    tokensModel: TokensModel

  proc setup(self: TokenListsModel)
  proc delete(self: TokenListsModel)
  proc newTokenListsModel*(delegate: io_interface.TokenListsModelDataSource): TokenListsModel =
    new(result, delete)
    result.setup
    result.delegate = delegate

  method rowCount(self: TokenListsModel, index: QModelIndex = nil): int =
    return self.delegate.getAllTokenLists().len

  proc countChanged(self: TokenListsModel) {.signal.}
  proc getCount(self: TokenListsModel): int {.slot.} =
    return self.rowCount()
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method roleNames(self: TokenListsModel): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.Name.int:"name",
      ModelRole.Timestamp.int:"timestamp",
      ModelRole.FetchedTimestamp.int:"fetchedTimestamp",
      ModelRole.Source.int:"source",
      ModelRole.Version.int:"version",
      ModelRole.LogoURI.int:"logoUri",
      ModelRole.Tokens.int:"tokens",
    }.toTable

  proc getTokensModelDataSource*(self: TokenListsModel, index: int): TokensModelDataSource =
    return (
      getTokens: proc(): var seq[TokenItem] = self.delegate.getAllTokenLists()[index].tokens,
    )

  method data(self: TokenListsModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    var item = self.delegate.getAllTokenLists()[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Id:
        return newQVariant(item.id)
      of ModelRole.Name:
        return newQVariant(item.name)
      of ModelRole.Timestamp:
        return newQVariant(item.timestamp)
      of ModelRole.FetchedTimestamp:
        return newQVariant(item.fetchedTimestamp)
      of ModelRole.Source:
        return newQVariant(item.source)
      of ModelRole.Version:
        return newQVariant($item.version)
      of ModelRole.LogoURI:
        return newQVariant(item.logoUri)
      of ModelRole.Tokens:
        self.tokensModel = newTokensModel(self.getTokensModelDataSource(index.row))
        self.tokensModel.modelsUpdated()
        return newQVariant(self.tokensModel)

  proc modelsUpdated*(self: TokenListsModel) =
    self.beginResetModel()
    self.endResetModel()

  proc setup(self: TokenListsModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenListsModel) =
    self.QAbstractListModel.delete