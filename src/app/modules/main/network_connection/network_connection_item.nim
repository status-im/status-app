import nimqml, std/strformat

QtObject:
  type NetworkConnectionItem* = ref object of QObject
    completelyDown: bool
    connectionState: int
    chainIds: string
    lastCheckedAt: int

  proc delete*(self: NetworkConnectionItem)
  proc newNetworkConnectionItem*(completelyDown = false, connectionState = 0, chainIds = "", lastCheckedAt = 0): NetworkConnectionItem =
    new(result, delete)
    result.QObject.setup
    result.completelyDown = completelyDown
    result.connectionState = connectionState
    result.chainIds = chainIds
    result.lastCheckedAt = lastCheckedAt

  proc `$`*(self: NetworkConnectionItem): string =
    result = fmt"""NetworkConnectionItem[
      completelyDown: {self.completelyDown},
      connectionState: {self.connectionState},
      chainIds: {self.chainIds},
      lastCheckedAt: {self.lastCheckedAt}
      ]"""

  proc completelyDownChanged*(self: NetworkConnectionItem) {.signal.}
  proc getCompletelyDown*(self: NetworkConnectionItem): bool {.slot.} =
    return self.completelyDown
  QtProperty[bool] completelyDown:
    read = getCompletelyDown
    notify = completelyDownChanged

  proc connectionStateChanged*(self: NetworkConnectionItem) {.signal.}
  proc getConnectionState*(self: NetworkConnectionItem): int {.slot.} =
    return self.connectionState
  QtProperty[int] connectionState:
    read = getConnectionState
    notify = connectionStateChanged

  proc chainIdsChanged*(self: NetworkConnectionItem) {.signal.}
  proc getChainIds*(self: NetworkConnectionItem): string {.slot.} =
    return self.chainIds
  QtProperty[string] chainIds:
    read = getChainIds
    notify = chainIdsChanged

  proc lastCheckedAtChanged*(self: NetworkConnectionItem) {.signal.}
  proc getLastCheckedAt*(self: NetworkConnectionItem): int {.slot.} =
    return self.lastCheckedAt
  QtProperty[int] lastCheckedAt:
    read = getLastCheckedAt
    notify = lastCheckedAtChanged

  proc updateValues*(self: NetworkConnectionItem, completelyDown: bool, connectionState: int,
    chainIds: string, lastCheckedAt: int) =
      if self.completelyDown != completelyDown :
        self.completelyDown = completelyDown
        self.completelyDownChanged()

      if self.connectionState != connectionState :
        self.connectionState = connectionState
        self.connectionStateChanged()

      if self.chainIds != chainIds :
        self.chainIds = chainIds
        self.chainIdsChanged()

      if self.lastCheckedAt != lastCheckedAt :
        self.lastCheckedAt = lastCheckedAt
        self.lastCheckedAtChanged()

  proc delete*(self: NetworkConnectionItem) =
    self.QObject.delete

