import nimqml

import io_interface, market_leaderboard_model

import app_service/service/market/service as market_service

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      marketLeaderboardModel: MarketLeaderboardModel

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.delegate = delegate
    result.setup()
    result.marketLeaderboardModel = newMarketLeaderboardModel(delegate.getMarketLeaderboardDataSource())

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc marketLeaderboardLoadingChanged*(self: View) {.signal.}
  proc getMarketLeaderboardLoading(self: View): bool {.slot.} =
    return self.delegate.getMarketLeaderboardLoading()
  proc setMarketLeaderboardLoading(self: View) {.slot.} =
    self.marketLeaderboardLoadingChanged()
  QtProperty[bool] marketLeaderboardLoading:
    read = getMarketLeaderboardLoading
    notify = marketLeaderboardLoadingChanged

  proc totalMarketLeaderboardModelCountChanged*(self: View) {.signal.}
  proc getTotalMarketLeaderboardModelCount(self: View): int {.slot.} =
    return self.delegate.getTotalMarketLeaderboardModelCount()
  proc setTotalMarketLeaderboardModelCount(self: View) {.slot.} =
    self.totalMarketLeaderboardModelCountChanged()
  QtProperty[int] totalMarketLeaderboardModelCount:
    read = getTotalMarketLeaderboardModelCount
    notify = totalMarketLeaderboardModelCountChanged

  proc currentPageChanged*(self: View) {.signal.}
  proc getCurrentPage(self: View): int {.slot.} =
    return self.delegate.getCurrentPage()
  proc setCurrentPage(self: View) {.slot.} =
    self.currentPageChanged()
  QtProperty[int] currentPage:
    read = getCurrentPage
    notify = currentPageChanged

  proc marketLeaderboardModelChanged*(self: View) {.signal.}
  proc getMarketLeaderboardModel(self: View): QAbstractListModel {.slot.} =
    return self.marketLeaderboardModel
  QtProperty[QAbstractListModel] marketLeaderboardModel:
    read = getMarketLeaderboardModel
    notify = marketLeaderboardModelChanged

  proc requestMarketTokenPage(self: View, page: int, pageSize: int = 100, sortOrder: int = 0) {.slot.} =
    self.delegate.requestMarketTokenPage(page, pageSize, sortOrder)
    self.setMarketLeaderboardLoading()

  proc unsubscribeFromUpdates(self: View) {.slot.} =
    self.delegate.unsubscribeFromUpdates()

  proc loadPage*(self: View) =
    self.setMarketLeaderboardLoading()
    self.setTotalMarketLeaderboardModelCount()
    self.setCurrentPage()
    self.marketLeaderboardModel.modelsUpdated()

  proc updatePage*(self: View, updates: seq[LeaderboardTokenUpdated]) =
    self.marketLeaderboardModel.pageUpdated(updates)

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

