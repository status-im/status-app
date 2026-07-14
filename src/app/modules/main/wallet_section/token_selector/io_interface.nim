import app/modules/shared_models/token_selector_model

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

# Factory used by the view's createModel slot: builds a terminal picker model
# wired to the right lazy popular/search source for the requested picker kind,
# registers it for owned-source re-push, and returns it.
method createModelForKind*(self: AccessInterface, kind: int): TokenSelectorModel {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")
