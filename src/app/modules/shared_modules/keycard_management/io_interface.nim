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

type
  DelegateInterface* = concept c
