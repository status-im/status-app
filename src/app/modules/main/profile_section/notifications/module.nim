import nimqml, chronicles
import io_interface
import ../io_interface as delegate_interface
import view, controller, model, item

import ../../../../global/global_singleton
import ../../../../core/eventemitter
import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/chat/service as chat_service
import ../../../../../app_service/service/contacts/service as contact_service
import ../../../../../app_service/service/community/service as community_service
from ../../../../../app_service/service/community/dto/community import CommunityDto

export io_interface

logScope:
  topics = "profile-section-notifications-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    settingsService: settings_service.Service,
    chatService: chat_service.Service,
    contactService: contact_service.Service,
    communityService: community_service.Service,
  ): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, settingsService, chatService, contactService,
    communityService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc createItem(self: Module, id, name, image, color: string, joinedTimestamp: int64, itemType: Type): Item =
  let exemptions = self.controller.getNotifSettingExemptions(id)
  var item = initItem(id, name, image, color, joinedTimestamp, itemType, exemptions.muteAllMessages,
  exemptions.personalMentions, exemptions.globalMentions, exemptions.otherMessages)
  return item

proc createChatItem(self: Module, chatDto: ChatDto): Item =
  var chatName = chatDto.name
  var chatImage = chatDto.icon
  var itemType = item.Type.GroupChat
  if(chatDto.chatType == ChatType.OneToOne):
    let contactDetails = self.controller.getContactDetails(chatDto.id)
    chatName = contactDetails.dto.displayName
    chatImage = contactDetails.icon
    itemType = item.Type.OneToOneChat

  return self.createItem(chatDto.id, chatName, chatImage, chatDto.color, chatDto.joined, itemType)

method initModel(self: Module) =
  var items: seq[Item]
  # Add personal section
  let personalChats = self.controller.getChatsForPersonalSection()
  for c in personalChats:
    if c.chatType != ChatType.OneToOne and c.chatType != ChatType.PrivateGroupChat:
      continue
    let item = self.createChatItem(c)
    items.add(item)

  # Add communities
  for community in self.controller.joinedAndSpectatedCommunities():
    let item = self.createItem(
      community.id,
      community.name,
      community.images.thumbnail,
      community.color,
      joinedTimestamp = 0,
      item.Type.Community
    )
    items.add(item)

  self.view.exemptionsModel().setItems(items)

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.notificationsModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method sendTestNotification*(self: Module, title: string, message: string) =
  singletonInstance.globalEvents.showTestNotification(title, message)

method saveExemptions*(self: Module, itemId: string, muteAllMessages: bool, personalMentions: string, 
  globalMentions: string, otherMessages: string) =
  let exemptions = NotificationsExemptions(muteAllMessages: muteAllMessages, 
    personalMentions: personalMentions,
    globalMentions: globalMentions, 
    otherMessages: otherMessages)
  if(self.controller.setNotifSettingExemptions(itemId, exemptions)):
    self.view.exemptionsModel().updateExemptions(itemId, muteAllMessages, personalMentions, globalMentions, otherMessages)  
  
method addCommunity*(self: Module, communityDto: CommunityDto) =
  let ind = self.view.exemptionsModel().findIndexForItemId(communityDto.id)
  if ind != -1:
    return
  let item = self.createItem(communityDto.id, communityDto.name, communityDto.images.thumbnail, communityDto.color, 
    joinedTimestamp = 0, item.Type.Community)
  self.view.exemptionsModel().addItem(item)

method editCommunity*(self: Module, communityDto: CommunityDto) =
  self.view.exemptionsModel().updateItem(
    communityDto.id,
    communityDto.name,
    communityDto.images.thumbnail,
    communityDto.color,
  )

method removeItemWithId*(self: Module, itemId: string) =
  if self.controller.removeNotifSettingExemptions(itemId):
    self.view.exemptionsModel().removeItemById(itemId)
  
method addChat*(self: Module, chatDto: ChatDto) =
  if chatDto.chatType != ChatType.OneToOne and chatDto.chatType != ChatType.PrivateGroupChat:
    return
  let ind = self.view.exemptionsModel().findIndexForItemId(chatDto.id)
  if ind != -1:
    return
  let item = self.createChatItem(chatDto)
  self.view.exemptionsModel().addItem(item)

method addChat*(self: Module, itemId: string) =
  let ind = self.view.exemptionsModel().findIndexForItemId(itemId)
  if ind != -1:
    return
  let chatDto = self.controller.getChatDetails(itemId)
  if chatDto.chatType != ChatType.OneToOne and chatDto.chatType != ChatType.PrivateGroupChat:
    return
  self.addChat(chatDto)

method setName*(self: Module, itemId: string, name: string) =
  self.view.exemptionsModel().updateName(itemId, name)
