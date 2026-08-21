import nimqml

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method syncKeycard*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method deleteAccount*(self: AccessInterface, address: string, password: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method deleteKeypair*(self: AccessInterface, keyUid: string, password: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshWalletAccounts*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateAccount*(self: AccessInterface, address: string, accountName: string, colorId: string, emoji: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method moveAccountFinally*(self: AccessInterface, fromPosition: int, toPosition: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method renameKeypair*(self: AccessInterface, keyUid: string, name: string) {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method getCollectiblesModel*(self: AccessInterface): QAbstractListModel {.base.} =
  raise newException(ValueError, "No implementation available")

method updateWatchAccountHiddenFromTotalBalance*(self: AccessInterface, address: string, hideFromTotalBalance: bool) {.base.} =
  raise newException(ValueError, "No implementation available")
