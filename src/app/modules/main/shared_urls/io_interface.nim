import ../../../../app_service/service/shared_urls/service as urls_service

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method parseCommunitySharedUrl*(self: AccessInterface, url: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method parseCommunityChannelSharedUrl*(self: AccessInterface, url: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method parseContactSharedUrl*(self: AccessInterface, url: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method createMessageUrl*(self: AccessInterface, chatId: string, messageId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method parseMessageUrl*(self: AccessInterface, url: string): MessageUrlDataDto {.base.} =
  raise newException(ValueError, "No implementation available")

method parseSharedUrl*(self: AccessInterface, url: string): UrlDataDto {.base.} =
  raise newException(ValueError, "No implementation available")

# This way (using concepts) is used only for the modules managed by AppController
type
  DelegateInterface* = concept c
    c.mainDidLoad()
