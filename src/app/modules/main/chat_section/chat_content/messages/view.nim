import nimqml, json
import ../../../../shared_models/message_model
import ../../../../shared_models/message_item
import ../../../../../../app_service/service/chat/dto/chat
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model
      modelVariant: QVariant
      messageSearchOngoing: bool
      amIChatAdmin: bool
      isPinMessageAllowedForMembers: bool
      chatColor: string
      chatIcon: string
      chatType: int
      loading: bool
      keepUnread: bool

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = newModel()
    result.modelVariant = newQVariant(result.model)
    result.messageSearchOngoing = false
    result.amIChatAdmin = false
    result.isPinMessageAllowedForMembers = false
    result.chatColor = ""
    result.chatIcon = ""
    result.chatType = ChatType.Unknown.int
    result.loading = false
    result.keepUnread = false

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc model*(self: View): Model =
    return self.model

  proc getModel(self: View): QVariant {.slot.} =
    return self.modelVariant
  QtProperty[QVariant] model:
    read = getModel

  proc toggleReaction*(self: View, messageId: string, emoji: string) {.slot.} =
    self.delegate.toggleReaction(messageId, emoji)

  proc pinMessage*(self: View, messageId: string) {.slot.} =
    self.delegate.pinUnpinMessage(messageId, true)

  proc unpinMessage*(self: View, messageId: string) {.slot.} =
    self.delegate.pinUnpinMessage(messageId, false)

  proc keepUnreadChanged*(self: View) {.signal.}
  proc getKeepUnread*(self: View): bool {.slot.} =
    return self.keepUnread

  QtProperty[bool] keepUnread:
    read = getKeepUnread
    notify = keepUnreadChanged

  proc setKeepUnread*(self: View, value: bool) =
    self.keepUnread = value
    self.keepUnreadChanged()

  proc markMessageAsUnread*(self: View, messageId: string) {.slot.} =
    self.delegate.markMessageAsUnread(messageId)
    self.setKeepUnread(true)

  proc updateKeepUnread*(self: View, flag: bool) {.slot.} =
    self.setKeepUnread(flag)

  proc getMessageByIdAsJson*(self: View, messageId: string): string {.slot.} =
    let jsonObj = self.model.getMessageByIdAsJson(messageId)
    if(jsonObj.isNil):
      return ""
    return $jsonObj

  proc getMessageByIndexAsJson*(self: View, index: int): string {.slot.} =
    let jsonObj = self.model.getMessageByIndexAsJson(index)
    if(jsonObj.isNil):
      return ""
    return $jsonObj

  proc getSectionId*(self: View): string {.slot.} =
    return self.delegate.getSectionId()

  proc getChatId*(self: View): string {.slot.} =
    return self.delegate.getChatId()

  proc getNumberOfPinnedMessages*(self: View): int {.slot.} =
    return self.delegate.getNumberOfPinnedMessages()

  proc loadMoreMessages*(self: View) {.slot.} =
    self.delegate.loadMoreMessages()

  proc messageSuccessfullySent*(self: View) {.signal.}
  proc emitSendingMessageSuccessSignal*(self: View) =
    self.messageSuccessfullySent()

  proc sendingMessageFailed*(self: View, error: string) {.signal.}

  proc emitSendingMessageErrorSignal*(self: View, error: string) =
    self.sendingMessageFailed(error)

  proc deleteMessage*(self: View, messageId: string) {.slot.} =
    self.delegate.deleteMessage(messageId)

  proc setEditModeOn*(self: View, messageId: string) {.slot.} =
   self.model.setEditModeOn(messageId)

  proc setEditModeOff*(self: View, messageId: string) {.slot.} =
   self.model.setEditModeOff(messageId)

  proc editMessage*(self: View, messageId: string, updatedMsg: string) {.slot.} =
    self.delegate.editMessage(messageId, updatedMsg)

  proc switchToMessage(self: View, messageIndex: int) {.signal.}
  proc emitSwitchToMessageSignal*(self: View, messageIndex: int) =
    self.switchToMessage(messageIndex)

  proc scrollToMessage(self: View, messageIndex: int) {.signal.}
  proc emitScrollToMessageSignal*(self: View, messageIndex: int) =
    self.scrollToMessage(messageIndex)

  proc fillGaps(self: View, messageId: string) {.slot.} =
    self.delegate.fillGaps(messageId)

  proc leaveChat*(self: View) {.slot.} =
    self.delegate.leaveChat()

  proc jumpToMessage*(self: View, messageId: string) {.slot.} =
    self.delegate.scrollToMessage(messageId)

  proc isEditAllowed(messageImage: string, sticker: string): bool =
    return messageImage == "" and sticker == ""

  proc setEditModeOnAndScrollToLastMessage*(self: View, pubkey: string) {.slot.} =
    let lastMessage = self.model.getLastItemFrom(pubKey)
    if lastMessage != nil and lastMessage.id != "" and isEditAllowed(lastMessage.messageImage, lastMessage.sticker):
      self.model.setEditModeOn(lastMessage.id)
      self.jumpToMessage(lastMessage.id)

  proc resendMessage*(self: View, messageId: string) {.slot.} =
    let error = self.delegate.resendChatMessage(messageId)
    if (error != ""):
      self.model.itemFailedResending(messageId, error)
      return
    self.model.itemSending(messageId)

  proc messageSearchOngoingChanged*(self: View) {.signal.}
  proc getMessageSearchOngoing*(self: View): bool {.slot.} =
    return self.messageSearchOngoing

  QtProperty[bool] messageSearchOngoing:
    read = getMessageSearchOngoing
    notify = messageSearchOngoingChanged

  proc setMessageSearchOngoing*(self: View, value: bool) =
    self.messageSearchOngoing = value
    self.messageSearchOngoingChanged()

  proc addNewMessagesMarker*(self: View) {.slot.} =
    if self.model.newMessagesMarkerIndex() == -1:
      self.delegate.resetNewMessagesMarker()

  proc amIChatAdminChanged*(self: View) {.signal.}
  proc getAmIChatAdmin*(self: View): bool {.slot.} =
    return self.amIChatAdmin
  
  QtProperty[bool] amIChatAdmin:
    read = getAmIChatAdmin
    notify = amIChatAdminChanged
  
  proc setAmIChatAdmin*(self: View, value: bool) =
    self.amIChatAdmin = value
    self.amIChatAdminChanged()

  proc isPinMessageAllowedForMembersChanged*(self: View) {.signal.}
  proc getIsPinMessageAllowedForMembers*(self: View): bool {.slot.} =
    return self.isPinMessageAllowedForMembers
  
  QtProperty[bool] isPinMessageAllowedForMembers:
    read = getIsPinMessageAllowedForMembers
    notify = isPinMessageAllowedForMembersChanged
  
  proc setIsPinMessageAllowedForMembers*(self: View, value: bool) =
    self.isPinMessageAllowedForMembers = value
    self.isPinMessageAllowedForMembersChanged()

  proc chatColorChanged*(self: View) {.signal.}
  proc getChatColor*(self: View): string {.slot.} =
    return self.chatColor

  QtProperty[string] chatColor:
    read = getChatColor
    notify = chatColorChanged
  
  proc setChatColor*(self: View, value: string) =
    self.chatColor = value
    self.chatColorChanged()

  proc chatIconChanged*(self: View) {.signal.}
  proc getChatIcon*(self: View): string {.slot.} =
    return self.chatIcon

  QtProperty[string] chatIcon:
    read = getChatIcon
    notify = chatIconChanged
  
  proc setChatIcon*(self: View, value: string) =
    self.chatIcon = value
    self.chatIconChanged()
  
  proc chatTypeChanged*(self: View) {.signal.}
  proc getChatType*(self: View): int {.slot.} =
    return self.chatType

  QtProperty[int] chatType:
    read = getChatType
    notify = chatTypeChanged
  
  proc setChatType*(self: View, value: int) =
    self.chatType = value
    self.chatTypeChanged()

  proc loadingChanged*(self: View) {.signal.}
  proc isLoading*(self: View): bool {.slot.} =
    return self.loading
  proc setLoading*(self: View, value: bool) =
    self.loading = value
    self.loadingChanged()
  
  QtProperty[bool] loading:
    read = isLoading
    notify = loadingChanged

  proc firstUnseenMentionMessageId(self: View): string {.slot.} =
    return self.model.getFirstUnseenMentionMessageId()

  proc forceLinkPreviewsLocalData*(self: View, messageId: string) {.slot.} =
    self.delegate.forceLinkPreviewsLocalData(messageId)

  proc delete*(self: View) =
    self.QObject.delete

