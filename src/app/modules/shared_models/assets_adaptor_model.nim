import nimqml, tables, algorithm, sequtils

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync

# AssetsAdaptorModel — terminal model for AssetsView.
#
# Replaces the QML proxy chain (ObjectProxyModel aggregators + two
# SortFilterProxyModels + FastExpressionRoles + RoleSorters). It owns visibility
# filtering, the derived roles (isCommunity / marketBalance / change1DayFiat) and
# sorting, and emits per-row/per-role dataChanged (no layoutChanged, no reset) on
# a stable-set refresh.
#
# It is a TERMINAL model: bound directly to the ListView with no proxies above,
# which is what makes the granular emissions safe (a proxy above would amplify a
# single-cell change into a whole-model dataChanged).
#
# Input is a flat, already-aggregated list of AssetItem value DTOs (balances
# summed, market/community joined upstream). `setSourceItems` diffs the new
# filtered+sorted view against the mirror; `sortBy` re-sorts in place.

type
  AssetItem* = object
    key*: string
    name*: string
    symbol*: string
    logoUri*: string
    balance*: float
    balanceText*: string
    balanceLoading*: bool
    error*: string
    marketPrice*: float
    marketChangePct24hour*: float
    marketDetailsAvailable*: bool
    marketDetailsLoading*: bool
    communityId*: string
    communityName*: string
    communityImage*: string
    canBeHidden*: bool
    position*: int
    visible*: bool

proc isCommunityStr(it: AssetItem): string =
  if it.communityId.len > 0: "community" else: ""

proc marketBalance(it: AssetItem): float =
  it.balance * it.marketPrice

proc change1DayFiat(it: AssetItem): float =
  ## Fiat value gained/lost over the last day, matching AssetsView's
  ## change1DayFiat FastExpressionRole. A -100% change zeroes the denominator
  ## (a day ago the value was effectively unbounded); the QML expression yields
  ## ±Inf/NaN there, and NaN breaks the sort comparator's antisymmetry, so the
  ## degenerate case is defined as 0.
  let denom = it.marketChangePct24hour / 100.0 + 1.0
  if denom == 0.0:
    return 0.0
  marketBalance(it) * (1.0 - (1.0 / denom))

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    Name
    Symbol
    LogoUri
    Balance
    BalanceText
    BalanceLoading
    Error
    MarketPrice
    MarketChangePct24hour
    MarketDetailsAvailable
    MarketDetailsLoading
    CommunityId
    CommunityName
    CommunityImage
    CanBeHidden
    Position
    Visible
    IsCommunity
    MarketBalance
    Change1DayFiat

QtObject:
  type
    AssetsAdaptorModel* = ref object of QAbstractListModel
      source: seq[AssetItem]   # raw aggregated input (unfiltered, unsorted)
      items: seq[AssetItem]    # displayed mirror (filtered + sorted), in lockstep with signals
      sortRoleName: string
      sortOrder: int           # Qt.AscendingOrder (0) / Qt.DescendingOrder (1)

  proc delete(self: AssetsAdaptorModel)
  proc setup(self: AssetsAdaptorModel)
  proc newAssetsAdaptorModel*(): AssetsAdaptorModel =
    new(result, delete)
    result.setup

  proc countChanged(self: AssetsAdaptorModel) {.signal.}
  proc getCount*(self: AssetsAdaptorModel): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: AssetsAdaptorModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: AssetsAdaptorModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.Name.int: "name",
      ModelRole.Symbol.int: "symbol",
      ModelRole.LogoUri.int: "logoUri",
      ModelRole.Balance.int: "balance",
      ModelRole.BalanceText.int: "balanceText",
      ModelRole.BalanceLoading.int: "balanceLoading",
      ModelRole.Error.int: "error",
      ModelRole.MarketPrice.int: "marketPrice",
      ModelRole.MarketChangePct24hour.int: "marketChangePct24hour",
      ModelRole.MarketDetailsAvailable.int: "marketDetailsAvailable",
      ModelRole.MarketDetailsLoading.int: "marketDetailsLoading",
      ModelRole.CommunityId.int: "communityId",
      ModelRole.CommunityName.int: "communityName",
      ModelRole.CommunityImage.int: "communityImage",
      ModelRole.CanBeHidden.int: "canBeHidden",
      ModelRole.Position.int: "position",
      ModelRole.Visible.int: "visible",
      ModelRole.IsCommunity.int: "isCommunity",
      ModelRole.MarketBalance.int: "marketBalance",
      ModelRole.Change1DayFiat.int: "change1DayFiat",
    }.toTable

  method data(self: AssetsAdaptorModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
    of ModelRole.Key: return newQVariant(item.key)
    of ModelRole.Name: return newQVariant(item.name)
    of ModelRole.Symbol: return newQVariant(item.symbol)
    of ModelRole.LogoUri: return newQVariant(item.logoUri)
    of ModelRole.Balance: return newQVariant(item.balance)
    of ModelRole.BalanceText: return newQVariant(item.balanceText)
    of ModelRole.BalanceLoading: return newQVariant(item.balanceLoading)
    of ModelRole.Error: return newQVariant(item.error)
    of ModelRole.MarketPrice: return newQVariant(item.marketPrice)
    of ModelRole.MarketChangePct24hour: return newQVariant(item.marketChangePct24hour)
    of ModelRole.MarketDetailsAvailable: return newQVariant(item.marketDetailsAvailable)
    of ModelRole.MarketDetailsLoading: return newQVariant(item.marketDetailsLoading)
    of ModelRole.CommunityId: return newQVariant(item.communityId)
    of ModelRole.CommunityName: return newQVariant(item.communityName)
    of ModelRole.CommunityImage: return newQVariant(item.communityImage)
    of ModelRole.CanBeHidden: return newQVariant(item.canBeHidden)
    of ModelRole.Position: return newQVariant(item.position)
    of ModelRole.Visible: return newQVariant(item.visible)
    of ModelRole.IsCommunity: return newQVariant(isCommunityStr(item))
    of ModelRole.MarketBalance: return newQVariant(marketBalance(item))
    of ModelRole.Change1DayFiat: return newQVariant(change1DayFiat(item))

  proc compareItems(self: AssetsAdaptorModel, a, b: AssetItem): int =
    # Primary: isCommunity ascending (regular tokens before community, matching
    # AssetsView's first RoleSorter). Secondary: chosen role honouring sortOrder.
    # No further tiebreak: returning 0 on ties lets Nim's stable sort preserve
    # source order, matching production SFPM (which has no tiebreak either).
    let ca = isCommunityStr(a)
    let cb = isCommunityStr(b)
    if ca != cb:
      return cmp(ca, cb)
    var r = 0
    case self.sortRoleName:
    of "name": r = cmp(a.name, b.name)
    of "balance": r = cmp(a.balance, b.balance)
    of "marketPrice": r = cmp(a.marketPrice, b.marketPrice)
    of "marketBalance": r = cmp(marketBalance(a), marketBalance(b))
    of "change1DayFiat": r = cmp(change1DayFiat(a), change1DayFiat(b))
    of "position": r = cmp(a.position, b.position)
    else: r = 0
    if self.sortOrder == 1: # Qt.DescendingOrder
      r = -r
    return r

  proc rolesChanged(o, n: AssetItem): seq[int] =
    result = @[]
    if o.name != n.name: result.add(ModelRole.Name.int)
    if o.symbol != n.symbol: result.add(ModelRole.Symbol.int)
    if o.logoUri != n.logoUri: result.add(ModelRole.LogoUri.int)
    if o.balanceText != n.balanceText: result.add(ModelRole.BalanceText.int)
    if o.balanceLoading != n.balanceLoading: result.add(ModelRole.BalanceLoading.int)
    if o.error != n.error: result.add(ModelRole.Error.int)
    if o.marketDetailsAvailable != n.marketDetailsAvailable: result.add(ModelRole.MarketDetailsAvailable.int)
    if o.marketDetailsLoading != n.marketDetailsLoading: result.add(ModelRole.MarketDetailsLoading.int)
    if o.communityName != n.communityName: result.add(ModelRole.CommunityName.int)
    if o.communityImage != n.communityImage: result.add(ModelRole.CommunityImage.int)
    if o.canBeHidden != n.canBeHidden: result.add(ModelRole.CanBeHidden.int)
    if o.position != n.position: result.add(ModelRole.Position.int)
    if o.communityId != n.communityId:
      result.add(ModelRole.CommunityId.int)
      result.add(ModelRole.IsCommunity.int)
    let balChanged = o.balance != n.balance
    let priceChanged = o.marketPrice != n.marketPrice
    let changeChanged = o.marketChangePct24hour != n.marketChangePct24hour
    if balChanged: result.add(ModelRole.Balance.int)
    if priceChanged: result.add(ModelRole.MarketPrice.int)
    if changeChanged: result.add(ModelRole.MarketChangePct24hour.int)
    if balChanged or priceChanged:
      result.add(ModelRole.MarketBalance.int)
    if balChanged or priceChanged or changeChanged:
      result.add(ModelRole.Change1DayFiat.int)

  proc recompute(self: AssetsAdaptorModel) =
    var display = self.source.filterIt(it.visible)
    display.sort(proc(a, b: AssetItem): int = self.compareItems(a, b))
    setItemsWithSync(
      self, self.items, display,
      getId = proc(it: AssetItem): string = it.key,
      getRoles = proc(o, n: AssetItem): seq[int] = rolesChanged(o, n),
      countChanged = proc() = self.countChanged(),
      useBulkOps = true)

  proc setSourceItems*(self: AssetsAdaptorModel, items: seq[AssetItem]) =
    self.source = items
    self.recompute()

  proc sortBy*(self: AssetsAdaptorModel, roleName: string, order: int) =
    if roleName == self.sortRoleName and order == self.sortOrder:
      return
    self.sortRoleName = roleName
    self.sortOrder = order
    self.recompute()

  proc delete(self: AssetsAdaptorModel) =
    self.QAbstractListModel.delete

  proc setup(self: AssetsAdaptorModel) =
    self.QAbstractListModel.setup
    self.sortRoleName = "name"
    self.sortOrder = 1 # Qt.DescendingOrder — matches AssetsView's default

  # Test/inspection accessors — kept out of production builds.
  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: AssetsAdaptorModel): seq[string] =
      self.items.mapIt(it.key)
    proc itemAtForTest*(self: AssetsAdaptorModel, i: int): AssetItem =
      self.items[i]
    proc marketBalanceAtForTest*(self: AssetsAdaptorModel, i: int): float =
      marketBalance(self.items[i])
    proc change1DayFiatAtForTest*(self: AssetsAdaptorModel, i: int): float =
      change1DayFiat(self.items[i])
    proc isCommunityAtForTest*(self: AssetsAdaptorModel, i: int): string =
      isCommunityStr(self.items[i])
