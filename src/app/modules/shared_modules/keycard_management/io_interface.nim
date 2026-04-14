import nimqml

import app_service/service/keycardV2/dto as keycard_serviceV2_dto

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

method getKeyPairNameForKeyUid*(self: AccessInterface, keyUid: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeyPairAccountPathsJsonForKeyUid*(self: AccessInterface, keyUid: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method startLoadSeedPhrase*(self: AccessInterface, pin: string, seedPhrase: string, metadataName: string,
      metadataAccounts: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardLoadSeedPhraseFinished*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method generateMnemonic*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

type
  DelegateInterface* = concept c
