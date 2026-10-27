import app/modules/shared_models/model_utils
import nimqml, tables, sequtils, sets
import token_list_item

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    Name
    Shortname
    Symbol
    Color
    Image
    Category
    CommunityId
    Supply
    InfiniteSupply
    Decimals
    PrivilegesLevel

QtObject:
  type TokenListModel* = ref object of QAbstractListModel
    items*: seq[TokenListItem]

  proc setup(self: TokenListModel)
  proc delete(self: TokenListModel)
  proc newTokenListModel*(): TokenListModel =
    new(result, delete)
    result.setup

  proc countChanged(self: TokenListModel) {.signal.}

  proc getCount(self: TokenListModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc setItems*(self: TokenListModel, items: seq[TokenListItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc setWalletTokenItems*(self: TokenListModel, items: seq[TokenListItem]): HashSet[(string, string)] {.discardable.} =
    ## Returns the (symbol, communityId) of the community-issued wallet rows that
    ## went, whose community's own row is not listed then
    var newItems = items
    var walletKeys = initHashSet[(string, string)](items.len)
    for it in items:
      walletKeys.incl((it.getSymbol(), it.getCommunityId()))
    for item in self.items:
      # wallet rows are General, also those of community-issued tokens; a community's
      # own row a wallet row covers goes, as the communities never add it then
      if item.category != ord(TokenListItemCategory.General):
        if (item.getSymbol(), item.getCommunityId()) notin walletKeys:
          newItems.add(item)
      elif item.getCommunityId().len > 0:
        let itemKey = (item.getSymbol(), item.getCommunityId())
        if itemKey notin walletKeys:
          result.incl(itemKey)
    self.beginResetModel()
    self.items = newItems
    self.endResetModel()
    self.countChanged()

  proc hasItem*(self: TokenListModel, symbol: string, communityId: string): bool =
    for item in self.items:
      if item.getSymbol() == symbol and item.getCommunityId() == communityId:
        return true
    return false

  proc getItem*(self: TokenListModel, symbol: string): TokenListItem =
    for item in self.items:
      if item.getSymbol() == symbol:
        return item

  proc addItems*(self: TokenListModel, items: seq[TokenListItem]) =
    if(items.len == 0):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    let first = self.items.len
    let last = first + items.len - 1
    self.beginInsertRows(parentModelIndex, first, last)
    self.items.add(items)
    self.endInsertRows()
    self.countChanged()

  proc addUnlistedItems*(self: TokenListModel, items: seq[TokenListItem]) =
    var listed = initHashSet[(string, string)](self.items.len)
    for it in self.items:
      listed.incl((it.getSymbol(), it.getCommunityId()))
    self.addItems(items.filterIt((it.getSymbol(), it.getCommunityId()) notin listed))

  method roleNames(self: TokenListModel): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.Name.int:"name",
      ModelRole.Symbol.int:"symbol",
      ModelRole.Shortname.int:"shortName",
      ModelRole.Color.int:"color",
      ModelRole.Image.int:"icon",
      ModelRole.Category.int:"category",
      ModelRole.CommunityId.int:"communityId",
      ModelRole.Supply.int:"supply",
      ModelRole.InfiniteSupply.int:"infiniteSupply",
      ModelRole.Decimals.int:"decimals",
      ModelRole.PrivilegesLevel.int:"privilegesLevel",
    }.toTable

  method rowCount(self: TokenlistModel, index: QModelIndex = nil): int =
    return self.items.len

  method data(self: TokenListModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Key:
        result = newQVariant(item.getKey())
      of ModelRole.Name:
        result = newQVariant(item.getName())
      of ModelRole.Symbol:
        result = newQVariant(item.getSymbol())
      of ModelRole.Shortname:
        result = newQVariant(item.getSymbol())
      of ModelRole.Color:
        result = newQVariant(item.getColor())
      of ModelRole.Image:
        result = newQVariant(item.getImage())
      of ModelRole.Category:
        result = newQVariant(item.getCategory())
      of ModelRole.CommunityId:
        result = newQVariant(item.getCommunityId())
      of ModelRole.Supply:
        result = newQVariant(item.getSupply())
      of ModelRole.InfiniteSupply:
        result = newQVariant(item.getInfiniteSupply())
      of ModelRole.Decimals:
        result = newQVariant(item.getDecimals())
      of ModelRole.PrivilegesLevel:
        result = newQVariant(item.getPrivilegesLevel())

  proc setup(self: TokenListModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenListModel) =
    self.QAbstractListModel.delete
