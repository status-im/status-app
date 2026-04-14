import nimqml

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method ensUsernameAvailabilityChecked*(self: AccessInterface, availabilityStatus: string, ownerAddress: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onDetailsForEnsUsername*(self: AccessInterface, chainId: int, ensUsername: string, address: string, pubkey: string,
  isStatus: bool, expirationTime: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method ensTransactionSent*(self: AccessInterface, trxType: string, chainId: int, ensUsername: string, txHash: string, err: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method ensTransactionConfirmed*(self: AccessInterface, trxType: string, ensUsername: string, transactionHash: string)
  {.base.} =
  raise newException(ValueError, "No implementation available")

method ensTransactionReverted*(self: AccessInterface, trxType: string, ensUsername: string, transactionHash: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method checkEnsUsernameAvailability*(self: AccessInterface, desiredEnsUsername: string, statusDomain: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method numOfPendingEnsUsernames*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

method fetchDetailsForEnsUsername*(self: AccessInterface, chainId: int, ensUsername: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method removeEnsUsername*(self: AccessInterface, chainId: int, ensUsername: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method connectOwnedUsername*(self: AccessInterface, ensUsername: string, isStatus: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method getEnsRegisteredAddress*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getWalletDefaultAddress*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getCurrentCurrency*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getFiatValue*(self: AccessInterface, cryptoBalance: string, cryptoSymbol: string): string
  {.base.} =
  raise newException(ValueError, "No implementation available")

method getCryptoValue*(self: AccessInterface, fiatAmount: string, cryptoSymbol: string): string
  {.base.} =
  raise newException(ValueError, "No implementation available")

method setPrefferedEnsUsername*(self: AccessInterface, ensUsername: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method ensnameResolverAddress*(self: AccessInterface, ensUsername: string): string {.base.} =
  raise newException(ValueError, "No implementation available")
