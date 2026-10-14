import nimqml, sequtils, sugar
import io_interface
import view, controller
import ../../../../shared_models/[member_model, member_item]
import ../../../../../global/global_singleton
import ../../../../../core/eventemitter
import ../../../../../../app_service/common/types
import ../../../../../../app_service/service/contacts/dto/contacts
import ../../../../../../app_service/service/contacts/service as contact_service
import ../../../../../../app_service/service/chat/service as chat_service
import ../../../../../../app_service/service/community/service as community_service
import ../../../../../../app_service/service/message/service as message_service
from ../../../../../../app_service/common/conversion import intToEnum

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool

# Forward declaration
proc processChatMember(self: Module,  member: ChatMember, reset: bool = false): tuple[doAdd: bool, memberItem: MemberItem]

proc newModule*(
  events: EventEmitter, sectionId: string, chatId: string,
  belongsToCommunity: bool, isUsersListAvailable: bool, contactService: contact_service.Service,
  chatService: chat_service.Service, communityService: community_service.Service,
  messageService: message_service.Service,
): Module =
  result = Module()
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(
    result, events, sectionId, chatId, belongsToCommunity, isUsersListAvailable,
    contactService, chatService, communityService, messageService,
  )
  result.moduleLoaded = false

method delete*(self: Module) =
  self.controller.delete
  self.view.delete
  self.viewVariant.delete

method load*(self: Module) =
  if self.moduleLoaded:
    return
  # community members come from the section's roster; this model is for 1:1 and group chats
  if not self.controller.belongsToCommunity():
    self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  if not self.controller.belongsToCommunity():
    self.updateMembersList()
  self.moduleLoaded = true

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method getUsersListVariant*(self: Module): QVariant =
  self.view.getModel()

method contactNicknameChanged*(self: Module, publicKey: string) =
  let contactDetails = self.controller.getContactDetails(publicKey)
  self.view.model().setName(
    publicKey,
    contactDetails.dto.displayName,
    contactDetails.dto.name,
    contactDetails.dto.localNickname
    )

method contactsStatusUpdated*(self: Module, statusUpdates: seq[StatusUpdateDto]) =
  for s in statusUpdates:
    var status = toOnlineStatus(s.statusType)
    self.view.model().setOnlineStatus(s.publicKey, status)

method contactUpdated*(self: Module, publicKey: string) =
  let contactDetails = self.controller.getContactDetails(publicKey)
  self.view.model().updateItem(
    pubKey = publicKey,
    displayName = contactDetails.dto.displayName,
    ensName = contactDetails.dto.name,
    isEnsVerified = contactDetails.dto.ensVerified,
    localNickname = contactDetails.dto.localNickname,
    alias = contactDetails.dto.alias,
    icon = contactDetails.icon,
    isContact = contactDetails.dto.isContact,
    isBlocked = contactDetails.dto.isBlocked,
    trustStatus = contactDetails.dto.trustStatus,
    contactRequest = toContactStatus(contactDetails.dto.contactRequestState),
  )

method userProfileUpdated*(self: Module) =
  self.contactUpdated(singletonInstance.userProfile.getPubKey())

method loggedInUserImageChanged*(self: Module) =
  self.view.model().setIcon(singletonInstance.userProfile.getPubKey(), singletonInstance.userProfile.getIcon())

# This function either removes the member if it is no longer part of the community,
# does nothing if the member is already in the model or creates the MemberItem
proc processChatMember(self: Module,  member: ChatMember, reset: bool = false): tuple[doAdd: bool, memberItem: MemberItem] =
  result.doAdd = false
  if member.id == "":
    return

  if not reset and not member.joined:
    if self.view.model().isContactWithIdAdded(member.id):
      # Member is no longer joined
      self.view.model().removeItemById(member.id)
    return

  if not reset and self.view.model().isContactWithIdAdded(member.id):
    return

  let isMe = member.id == singletonInstance.userProfile.getPubKey()
  let contactDetails = self.controller.getContactDetails(member.id)
  var status = OnlineStatus.Online
  if isMe:
    let currentUserStatus = intToEnum(singletonInstance.userProfile.getCurrentUserStatus(), StatusType.Unknown)
    status = toOnlineStatus(currentUserStatus)
  else:
    let statusUpdateDto = self.controller.getStatusForContact(member.id)
    status = toOnlineStatus(statusUpdateDto.statusType)

  result.doAdd = true

  result.memberItem = createMemberItemFromDtos(
    contactDetails,
    status,
    state = MembershipRequestState.None,
    requestId = "",
    role = member.role,
    airdropAddress = "",
    joined = member.joined,
  )

method onChatMembersAdded*(self: Module, ids: seq[string]) =
  var memberItems: seq[MemberItem] = @[]

  for memberId in ids:
    let (doAdd, item) = self.processChatMember(ChatMember(id: memberId, role: MemberRole.None, joined: true))
    if doAdd:
      memberItems.add(item)

  self.view.model().addItems(memberItems)

method onChatMemberRemoved*(self: Module, id: string) =
  self.view.model().removeItemById(id)

method onMembersChanged*(self: Module,  members: seq[ChatMember]) =
  let modelIDs = self.view.model().getItemIds()
  let membersAdded = filter(members, member => not modelIDs.contains(member.id))
  let membersRemoved = filter(modelIDs, id => not members.any(member => member.id == id))

  var memberItems: seq[MemberItem] = @[]
  for member in membersAdded:
    let (doAdd, item) = self.processChatMember(member)
    if doAdd:
      memberItems.add(item)
  self.view.model().addItems(memberItems)

  for id in membersRemoved:
    self.onChatMemberRemoved(id)

method onChatMemberUpdated*(self: Module, publicKey: string, memberRole: MemberRole, joined: bool) =
  let contactDetails = self.controller.getContactDetails(publicKey)
  discard self.view.model().updateItem(
    pubKey = publicKey,
    displayName = contactDetails.dto.displayName,
    ensName = contactDetails.dto.name,
    isEnsVerified = contactDetails.dto.ensVerified,
    localNickname = contactDetails.dto.localNickname,
    alias = contactDetails.dto.alias,
    icon = contactDetails.icon,
    isContact = contactDetails.dto.isContact,
    isBlocked = contactDetails.dto.isBlocked,
    memberRole,
    joined,
    trustStatus = contactDetails.dto.trustStatus,
    contactRequest = toContactStatus(contactDetails.dto.contactRequestState),
  )

method addGroupMembers*(self: Module, pubKeys: seq[string]) =
  self.controller.addGroupMembers(pubKeys)

method removeGroupMembers*(self: Module, pubKeys: seq[string]) =
  self.controller.removeGroupMembers(pubKeys)

method updateMembersList*(self: Module, membersToReset: seq[ChatMember] = @[]) =
  let reset = membersToReset.len > 0
  let members = if reset: membersToReset else: self.controller.getMyChat().members

  var memberItems: seq[MemberItem] = @[]
  for member in members:
    let (doAdd, item) = self.processChatMember(member, reset)
    if doAdd:
      memberItems.add(item)

  if reset:
    self.view.model().setItems(memberItems)
  else:
    self.view.model().addItems(memberItems)
