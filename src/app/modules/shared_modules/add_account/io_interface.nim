import tables, nimqml

import ../../../../app_service/service/accounts/dto/generated_accounts
import ../../../../app_service/service/wallet_account/dto/derived_address_dto

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadForAddingAccount*(self: AccessInterface, addingWatchOnlyAccount: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadForEditingAccount*(self: AccessInterface, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method closeAddAccountPopup*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method getSeedPhrase*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method onBackActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onPrimaryActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onSecondaryActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onTertiaryActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onQuaternaryActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCancelActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method finalizeAction*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method authenticateForEditingDerivationPath*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onUserAuthenticated*(self: AccessInterface, pin: string, password: string, keyUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changeSelectedOrigin*(self: AccessInterface, keyUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changeDerivationPath*(self: AccessInterface, path: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changeSelectedDerivedAddress*(self: AccessInterface, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changeWatchOnlyAccountAddress*(self: AccessInterface, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changePrivateKey*(self: AccessInterface, privateKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changeSeedPhrase*(self: AccessInterface, seedPhrase: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method validSeedPhrase*(self: AccessInterface, seedPhrase: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method resetDerivationPath*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onDerivedAddressesFetched*(self: AccessInterface, derivedAddresses: seq[DerivedAddressDto], error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onDerivedAddressesFromMnemonicFetched*(self: AccessInterface, derivedAddresses: seq[DerivedAddressDto], error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onAddressesFromNotImportedMnemonicFetched*(self: AccessInterface, derivations: Table[string, DerivedAccountDetails], error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateDerivedAddresses*(self: AccessInterface, derivedAddresses: seq[DerivedAddressDto], error: string, detailsLoaded: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method startScanningForActivity*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method buildNewPrivateKeyKeypairAndAddItToOrigin*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method buildNewSeedPhraseKeypairAndAddItToOrigin*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method removingSavedAddressConfirmed*(self: AccessInterface, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method savedAddressDeleted*(self: AccessInterface, address: string, errorMsg: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method isChecksumValidForAddress*(self: AccessInterface, address: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method remainingAccountCapacity*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

method remainingKeypairCapacity*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

method remainingWatchOnlyAccountCapacity*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

type
  DelegateInterface* = concept c
    c.onAddAccountModuleLoaded()
    c.destroyAddAccountPopup()
