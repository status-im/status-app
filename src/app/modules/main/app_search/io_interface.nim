import nimqml

import app_service/service/message/dto/message
import app_service/service/chat/service
import app_service/service/community/service

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method onActiveChatChange*(self: AccessInterface, sectionId: string, chatId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onSearchMessagesDone*(self: AccessInterface, messages: seq[MessageDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method prepareLocationMenuModel*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method setSearchLocation*(self: AccessInterface, location: string, subLocation: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getSearchLocationObject*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method searchMessages*(self: AccessInterface, searchTerm: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method resultItemClicked*(self: AccessInterface, itemId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateSearchLocationIfPointToChatWithId*(self: AccessInterface, chatId: string) {.base.} =
    raise newException(ValueError, "No implementation available")

method buildChatSearchModel*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateChatItems*(self: AccessInterface, updatedChats: seq[ChatDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method contactUpdated*(self: AccessInterface, contactId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method communityEdited*(self: AccessInterface, community: CommunityDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method chatAdded*(self: AccessInterface, chat: ChatDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method chatRemoved*(self: AccessInterface, chatId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateLastMessage*(self: AccessInterface, chatId, communityId: string, chatType: ChatType, lastmessage: MessageDto, lastMessageTimestamp: int) {.base.} =
  raise newException(ValueError, "No implementation available")
