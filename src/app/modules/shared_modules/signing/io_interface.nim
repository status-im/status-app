import nimqml

import app_service/service/keycardV2/dto as keycard_serviceV2_dto
import app/modules/shared_models/keypair_item

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method verifyPassword*(self: AccessInterface, password: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method signMessage*(self: AccessInterface, address: string, password: string, txHash: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method isKeypairMigratedToColdWallet*(self: AccessInterface, keyUid: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method buildKeyPairForProcessing*(self: AccessInterface, keyUid: string): KeyPairItem {.base.} =
  raise newException(ValueError, "No implementation available")

method startKeycardSigning*(self: AccessInterface, keyUid: string, pin: string, txHash: string, path: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method stopKeycardSigning*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardStateUpdated*(self: AccessInterface, kcEvent: KeycardEventDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardSignFinished*(self: AccessInterface, signature: KeycardSignatureDto, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

type
  DelegateInterface* = concept c
