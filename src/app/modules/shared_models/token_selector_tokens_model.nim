import nimqml, tables

import app/modules/shared_models/model_utils
import ./token_selector_item
export token_selector_item

# Per-group nested model of the group's tokens (one row per chain), exposing the
# per-chain token key + chainId. Only the buy modal's provider filter reads it
# (ModelUtils.getFirstModelEntryIf over chainId/key); it is not rendered, and the
# token set is static metadata, so it is rebuilt wholesale (beginResetModel) on
# the rare change rather than diffed.

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    ChainId

QtObject:
  type
    TokenSelectorTokensModel* = ref object of QAbstractListModel
      items: seq[TokenSelectorTokenRef]

  proc setup(self: TokenSelectorTokensModel)
  proc delete(self: TokenSelectorTokensModel)
  proc newTokenSelectorTokensModel*(tokens: seq[TokenSelectorTokenRef] = @[]): TokenSelectorTokensModel =
    new(result, delete)
    result.setup
    result.items = tokens

  proc countChanged(self: TokenSelectorTokensModel) {.signal.}
  proc getCount(self: TokenSelectorTokensModel): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: TokenSelectorTokensModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: TokenSelectorTokensModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.ChainId.int: "chainId",
    }.toTable

  method data(self: TokenSelectorTokensModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let item = self.items[index.row]
    case role.ModelRole:
    of ModelRole.Key: return newQVariant(item.key)
    of ModelRole.ChainId: return newQVariant(item.chainId)

  proc setItems*(self: TokenSelectorTokensModel, tokens: seq[TokenSelectorTokenRef]) =
    self.beginResetModel()
    self.items = tokens
    self.endResetModel()
    self.countChanged()

  proc tokenRefs*(self: TokenSelectorTokensModel): seq[TokenSelectorTokenRef] =
    self.items

  proc setup(self: TokenSelectorTokensModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenSelectorTokensModel) =
    self.QAbstractListModel.delete
