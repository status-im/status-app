type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onActivated*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method bookmarkDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method dappsDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method providerDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method openUrl*(self: AccessInterface, url: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method purgePreferenceCategory*(self: AccessInterface, category: string, validKeys: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method putPreference*(self: AccessInterface, category, key, value: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getPreference*(self: AccessInterface, category, key: string): string {.base.} =
  raise newException(ValueError, "No implementation available")
