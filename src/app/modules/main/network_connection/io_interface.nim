type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method networkConnectionStatusUpdate*(self: AccessInterface, website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAt: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshBlockchainValues*(self: AccessInterface)  {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshMarketValues*(self: AccessInterface)  {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshCollectiblesValues*(self: AccessInterface)  {.base.} =
  raise newException(ValueError, "No implementation available")

method onUnsupportedCollectibleChainsLoaded*(self: AccessInterface, chains: seq[int]) {.base.} =
  raise newException(ValueError, "No implementation available")

