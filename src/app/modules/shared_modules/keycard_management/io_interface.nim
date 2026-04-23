import nimqml

import app_service/service/keycardV2/dto as keycard_serviceV2_dto
import app/modules/shared_models/keypair_item

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method startGetMetadata*(self: AccessInterface, pin: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method stopKeycardAction*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardStateUpdated*(self: AccessInterface, kcEvent: KeycardEventDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardGetMetadataFinished*(self: AccessInterface, metadata: CardMetadataDto, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startFactoryReset*(self: AccessInterface, keycardUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardFactoryResetFinished*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeyUidForSeedPhrase*(self: AccessInterface, seedPhrase: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method isKnownKeyUid*(self: AccessInterface, keyUid: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method isKeyPairMigratedToKeycard*(self: AccessInterface, keyUid: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeyPairNameForKeyUid*(self: AccessInterface, keyUid: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeyPairAccountPathsJsonForKeyUid*(self: AccessInterface, keyUid: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method startImportingKeyPair*(self: AccessInterface, pin: string, seedPhrase: string, metadataName: string,
      metadataAccounts: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startMigratingNonProfileKeypairToKeycard*(self: AccessInterface, password: string, pin: string,
    seedPhrase: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startAddingKeyPairToStatusFromKeycard*(self: AccessInterface, pin: string, keyUid: string,
    metadataName: string, metadataAccounts: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardExportExtendedPublicKeyFinished*(self: AccessInterface, xpub: string, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardLoadSeedPhraseFinished*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method generateMnemonic*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method populateKeyPairModel*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isMnemonicBackedUp*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getMnemonic*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method startMigratingProfileKeypairToKeycard*(self: AccessInterface, password: string, pin: string,
    seedPhrase: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onConvertingProfileKeypairFinished*(self: AccessInterface, success: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method startStopUsingKeycardForKeyPair*(self: AccessInterface, keyUid, seedPhrase, newPassword: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onStopUsingKeycardForKeyPairFinished*(self: AccessInterface, keyUid: string, success: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method startStopUsingKeycardForProfileKeyPair*(self: AccessInterface, seedPhrase, newPassword: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startChangeKeycardPIN*(self: AccessInterface, currentPin, newPin: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onChangeKeycardPINFinished*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startChangeKeycardPUK*(self: AccessInterface, currentPin, newPuk: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onChangeKeycardPUKFinished*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startRenameKeycard*(self: AccessInterface, currentPin, newName, metadataAccountsJson: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onRenameKeycardFinished*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeyPairItemForKeyUid*(self: AccessInterface, keyUid: string): KeyPairItem {.base.} =
  raise newException(ValueError, "No implementation available")

method remainingKeypairCapacity*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

method remainingAccountCapacity*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

type
  DelegateInterface* = concept c
