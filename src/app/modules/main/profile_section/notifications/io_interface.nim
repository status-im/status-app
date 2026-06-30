import nimqml
from ../../../../../app_service/service/community/dto/community import CommunityDto
from ../../../../../app_service/service/chat/dto/chat import ChatDto

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method initModel*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method sendTestNotification*(self: AccessInterface, title: string, message: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method saveExemptions*(self: AccessInterface, itemId: string, muteAllMessages: bool, personalMentions: string, 
  globalMentions: string, allMessages: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method addCommunity*(self: AccessInterface, communityDto: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method editCommunity*(self: AccessInterface, communityDto: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method removeItemWithId*(self: AccessInterface, itemId: string) {.base.} =
  raise newException(ValueError, "No implementation available")
  
method addChat*(self: AccessInterface, chatDto: ChatDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method addChat*(self: AccessInterface, itemId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method editChat*(self: AccessInterface, itemId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method setName*(self: AccessInterface, itemId: string, name: string) {.base.} =
  raise newException(ValueError, "No implementation available")
