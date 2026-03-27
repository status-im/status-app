import nimqml

import app_service/service/keycardV2/dto as keycard_serviceV2_dto

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method verifyPassword*(self: AccessInterface, password: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method isKeypairMigratedToKeycard*(self: AccessInterface, keyUid: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method startKeycardAuthentication*(self: AccessInterface, keyUid: string, pin: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method stopKeycardAuthentication*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardStateUpdated*(self: AccessInterface, kcEvent: KeycardEventDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardExportPublicKeysFinished*(self: AccessInterface, exportedPublicKeys: KeycardExportedPublicKeysDto, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

type
  DelegateInterface* = concept c
