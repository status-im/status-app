import nimqml
import ../../../shared_models/message_model as pinned_msg_model
import ../item as chat_item
import ../../../../../app_service/common/types

import io_interface
import chat_details

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      pinnedMessagesModel: pinned_msg_model.Model
      pinnedMessagesModelVariant: QVariant
      chatDetails: ChatDetails
      chatDetailsVariant: QVariant


  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.pinnedMessagesModel = pinned_msg_model.newModel()
    result.pinnedMessagesModelVariant = newQVariant(result.pinnedMessagesModel)
    result.chatDetails = newChatDetails()
    result.chatDetailsVariant = newQVariant(result.chatDetails)

  proc chatDetailsChanged*(self:View) {.signal.}

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc pinnedModel*(self: View): pinned_msg_model.Model =
    return self.pinnedMessagesModel

  proc getInputAreaModule(self: View): QVariant {.slot.} =
    return self.delegate.getInputAreaModule()
  QtProperty[QVariant] inputAreaModule:
    read = getInputAreaModule

  proc getMessagesModule(self: View): QVariant {.slot.} =
    return self.delegate.getMessagesModule()
  QtProperty[QVariant] messagesModule:
    read = getMessagesModule

  proc getUsersModule(self: View): QVariant {.slot.} =
    return self.delegate.getUsersModule()
  QtProperty[QVariant] usersModule:
    read = getUsersModule

  proc getPinnedMessagesModel(self: View): QVariant {.slot.} =
    return self.pinnedMessagesModelVariant
  QtProperty[QVariant] pinnedMessagesModel:
    read = getPinnedMessagesModel

  proc unpinMessage*(self: View, messageId: string) {.slot.} =
    self.delegate.unpinMessage(messageId)

  proc getMyChatId*(self: View): string {.slot.} =
    return self.delegate.getMyChatId()

  proc muteChat*(self: View, interval: int) {.slot.} =
    self.delegate.muteChat(interval)

  proc unmuteChat*(self: View) {.slot.} =
    self.delegate.unmuteChat()

  proc unblockChat*(self: View): string {.slot.} =
    self.delegate.unblockChat()

  proc markAllMessagesRead*(self: View) {.slot.} =
    self.delegate.markAllMessagesRead()

  proc requestMoreMessages*(self: View) {.slot.} =
    self.delegate.requestMoreMessages()

  proc markMessageRead*(self: View, msgID: string) {.slot.} =
    self.delegate.markMessageRead(msgID)

  proc clearChatHistory*(self: View) {.slot.} =
    self.delegate.clearChatHistory()

  proc leaveChat*(self: View) {.slot.} =
    self.delegate.leaveChat()

  proc chatDetails*(self: View): ChatDetails =
    return self.chatDetails

  proc setMuted*(self: View, muted: bool) =
    self.chatDetails.setMuted(muted)

  proc setActive*(self: View) =
    self.chatDetails.setActive(true)

  proc setInactive*(self: View) =
    self.chatDetails.setActive(false)

  proc updateChatDetailsNameAndIcon*(self: View, name, icon: string) =
    self.chatDetails.setName(name)
    self.chatDetails.setIcon(icon)

  proc updateChatDetailsNameColorIcon*(self: View, name, color, icon: string) =
    self.updateChatDetailsNameAndIcon(name, icon)
    self.chatDetails.setColor(color)

  proc updateTrustStatus*(self: View, trustStatus: TrustStatus) =
    self.chatDetails.setTrustStatus(trustStatus)

  proc updateChatDetailsNotifications*(self: View, hasUnreadMessages: bool, notificationCount: int) =
    self.chatDetails.setHasUnreadMessages(hasUnreadMessages)
    self.chatDetails.setNotificationCount(notificationCount)
    if self.chatDetails.getHighlight and not hasUnreadMessages:
      self.chatDetails.setHighlight(false)

  proc getChatDetails(self: View): QVariant {.slot.} =
    return self.chatDetailsVariant
  QtProperty[QVariant] chatDetails:
    read = getChatDetails
    notify = chatDetailsChanged

  proc amIChatAdmin*(self: View): bool {.slot.} =
    return self.delegate.amIChatAdmin()

  proc updateChatDetailsName*(self: View, name: string) =
    self.chatDetails.setName(name)

  proc onMutualContactChanged*(self: View, value: bool) =
    self.chatDetails.setIsMutualContact(value)

  proc updateChatBlocked*(self: View, blocked: bool) =
    self.chatDetails.setBlocked(blocked)

  proc delete*(self: View) =
    self.QObject.delete

