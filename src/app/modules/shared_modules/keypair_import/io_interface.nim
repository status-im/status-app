import nimqml

import app/modules/shared_models/[keypair_item]
import app_service/service/wallet_account/dto/derived_address_dto

type ImportKeypairModuleMode* {.pure.}= enum
  SelectKeypair = 1
  SelectImportMethod
  ImportViaSeedPhrase
  ImportViaPrivateKey
  ImportViaQr
  ExportKeypairQr

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface, keyUid: string, mode: ImportKeypairModuleMode) {.base.} =
  raise newException(ValueError, "No implementation available")

method closeKeypairImportPopup*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method onBackActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onPrimaryActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onSecondaryActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCancelActionClicked*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onAuthenticationRequest*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onUserAuthenticated*(self: AccessInterface, pin: string, password: string, keyUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changePrivateKey*(self: AccessInterface, privateKey: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method changeSeedPhrase*(self: AccessInterface, seedPhrase: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method validSeedPhrase*(self: AccessInterface, seedPhrase: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method onAddressDetailsFetched*(self: AccessInterface, derivedAddresses: seq[DerivedAddressDto], error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getSelectedKeypair*(self: AccessInterface): KeyPairItem {.base.} =
  raise newException(ValueError, "No implementation available")

method clearSelectedKeypair*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method setConnectionString*(self: AccessInterface, connectionString: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method setSelectedKeyPairByKeyUid*(self: AccessInterface, keyUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method generateConnectionStringForExporting*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method validateConnectionString*(self: AccessInterface, connectionString: string): string {.base.} =
  raise newException(ValueError, "No implementation available")


type
  DelegateInterface* = concept c
    c.onKeypairImportModuleLoaded()
    c.destroyKeypairImportPopup()
