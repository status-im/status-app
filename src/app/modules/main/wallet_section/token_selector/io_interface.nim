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
# registers it for owned-source re-push under a fresh id, and returns both so the
# view can hand the id back to QML for later release.
method createModelForKind*(self: AccessInterface, kind: int): tuple[id: int, model: TokenSelectorModel] {.base.} =
  raise newException(ValueError, "No implementation available")

# Drops the registered model with the given id so it stops receiving owned-source
# re-pushes and can be collected once the view releases its QVariant. Called when
# the owning modal is destroyed.
method releaseModel*(self: AccessInterface, id: int) {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")
