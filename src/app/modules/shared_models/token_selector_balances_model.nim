import nimqml, tables

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import ./token_selector_item
export token_selector_item

# Per-token nested model of balance chips (one row per contributing chain) that
# the picker delegate renders as network icon + amount. Held by the parent
# TokenSelectorModel per group KEY (not positional index) so it survives the
# parent's granular reorders; the parent pushes fresh chips via updateChips(),
# which diffs against this snapshot and emits granular dataChanged/insert/remove.
#
# Balance is exposed as a double; locale formatting happens in the QML delegate.

type
  ModelRole {.pure.} = enum
    ChainId = UserRole + 1
    IconUrl
    ChainName
    Balance
    RawBalance

QtObject:
  type
    TokenSelectorBalancesModel* = ref object of QAbstractListModel
      items: seq[TokenSelectorChip]

  proc setup(self: TokenSelectorBalancesModel)
  proc delete(self: TokenSelectorBalancesModel)
  proc newTokenSelectorBalancesModel*(chips: seq[TokenSelectorChip] = @[]): TokenSelectorBalancesModel =
    new(result, delete)
    result.setup
    result.items = chips

  proc countChanged(self: TokenSelectorBalancesModel) {.signal.}
  proc getCount(self: TokenSelectorBalancesModel): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: TokenSelectorBalancesModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: TokenSelectorBalancesModel): Table[int, string] =
    {
      ModelRole.ChainId.int: "chainId",
      ModelRole.IconUrl.int: "iconUrl",
      ModelRole.ChainName.int: "chainName",
      ModelRole.Balance.int: "balance",
      ModelRole.RawBalance.int: "rawBalance",
    }.toTable

  method data(self: TokenSelectorBalancesModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let item = self.items[index.row]
    case role.ModelRole:
    of ModelRole.ChainId: return newQVariant(item.chainId)
    of ModelRole.IconUrl: return newQVariant(item.iconUrl)
    of ModelRole.ChainName: return newQVariant(item.chainName)
    of ModelRole.Balance: return newQVariant(item.balance)
    of ModelRole.RawBalance: return newQVariant(item.rawBalance)

  proc syncKey(it: TokenSelectorChip): string = $it.chainId
  proc syncRoles(o, n: TokenSelectorChip): seq[int] =
    result = @[]
    if o.iconUrl != n.iconUrl: result.add(ModelRole.IconUrl.int)
    if o.chainName != n.chainName: result.add(ModelRole.ChainName.int)
    if o.balance != n.balance: result.add(ModelRole.Balance.int)
    if o.rawBalance != n.rawBalance: result.add(ModelRole.RawBalance.int)

  proc updateChips*(self: TokenSelectorBalancesModel, chips: seq[TokenSelectorChip]) =
    self.modelSync(self.items, chips)

  proc setup(self: TokenSelectorBalancesModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenSelectorBalancesModel) =
    self.QAbstractListModel.delete

  when defined(testing) or defined(QT_MODEL_SPY):
    proc chainIdsInOrder*(self: TokenSelectorBalancesModel): seq[int] =
      for it in self.items: result.add(it.chainId)
    proc rawBalancesInOrder*(self: TokenSelectorBalancesModel): seq[string] =
      for it in self.items: result.add(it.rawBalance)
