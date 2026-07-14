import app/modules/shared_models/collectibles_model as collectibles_model
import app/modules/shared_models/collectibles_selector_model as collectibles_selector_model

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getAllCollectiblesModel*(self: AccessInterface): collectibles_model.Model {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshNetworks*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshWalletAccounts*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateCollectiblePreferences*(self: AccessInterface, collectiblePreferencesJson: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getCollectiblePreferencesJson*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getCollectibleGroupByCommunity*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleCollectibleGroupByCommunity*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getCollectibleGroupByCollection*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleCollectibleGroupByCollection*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method setSelectedAccount*(self: AccessInterface, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

# Send-modal collectibles picker: create a terminal CollectiblesSelectorModel
# seeded with the current collectibles universe; the owner releases it by id when
# the modal is destroyed. refreshCollectiblesSelectorModels re-pushes the source
# to every live model on a collectibles data update.
method createCollectiblesSelectorModel*(self: AccessInterface):
    tuple[id: int, model: collectibles_selector_model.CollectiblesSelectorModel] {.base.} =
  raise newException(ValueError, "No implementation available")

method releaseCollectiblesSelectorModel*(self: AccessInterface, id: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshCollectiblesSelectorModels*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")
