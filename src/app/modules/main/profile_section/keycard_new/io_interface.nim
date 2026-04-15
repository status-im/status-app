import nimqml

import app/modules/shared/keypairs

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isKnownKeyUid*(self: AccessInterface, keyUid: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method allNonProfileKeyPairsMigratedToKeycard*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method keycardPairingExists*(self: AccessInterface, keycardUid: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeyPairItemForKeyUid*(self: AccessInterface, keyUid: string): KeyPairItem {.base.} =
  raise newException(ValueError, "No implementation available")
