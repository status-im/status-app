import nimqml, json
import ../../../../shared_models/message_model
import ../../../../shared_models/message_item
import ../../../../../../app_service/service/chat/dto/chat
import ../../../../shared_models/thread_model as thread_model
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: message_model.Model
      modelVariant: QVariant
      threads: thread_model.Model
      threadsVariant: QVariant
      threadsLoading: bool
      threadsError: bool
      threadId: string
      threadName: string
      threadParentChatName: string
      canEditThread: bool
      threadEditPending: bool
      threadDeletePending: bool
      threadDeleted: bool
      messageSearchOngoing: bool
      amIChatAdmin: bool
      isPinMessageAllowedForMembers: bool
      chatColor: string
      chatIcon: string
      chatType: int
      loading: bool
      keepUnread: bool

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface, threadId: string = ""): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = message_model.newModel()
    result.modelVariant = newQVariant(result.model)
    result.threadId = threadId
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

  proc model*(self: View): message_model.Model =
    return self.model

  proc getModel(self: View): QVariant {.slot.} =
    return self.modelVariant
  QtProperty[QVariant] model:
    read = getModel

  proc hasThreadsModel*(self: View): bool =
    not self.threads.isNil

  proc threadsModel*(self: View): thread_model.Model =
    if self.threadId.len > 0:
      return nil
    if self.threads.isNil:
      self.threads = thread_model.newModel()
      self.threadsVariant = newQVariant(self.threads)
    self.threads

  proc getThreadsModel(self: View): QVariant {.slot.} =
    if self.threadsModel().isNil:
      return newQVariant()
    self.threadsVariant
  QtProperty[QVariant] threadsModel:
    read = getThreadsModel

  proc threadsStateChanged(self: View) {.signal.}
  proc getThreadsLoading(self: View): bool {.slot.} =
    self.threadsLoading
  QtProperty[bool] threadsLoading:
    read = getThreadsLoading
    notify = threadsStateChanged

  proc getThreadsError(self: View): bool {.slot.} =
    self.threadsError
  QtProperty[bool] threadsError:
    read = getThreadsError
    notify = threadsStateChanged

  proc setThreadsState*(self: View, loading, failed: bool) =
    if self.threadsLoading == loading and self.threadsError == failed:
      return
    self.threadsLoading = loading
    self.threadsError = failed
    self.threadsStateChanged()

  proc loadChatThreads*(self: View) {.slot.} =
    if self.threadId.len > 0 or self.threadsLoading:
      return
    self.setThreadsState(true, false)
    self.delegate.loadChatThreads()

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

  proc threadIdChanged*(self: View) {.signal.}
  proc getThreadId*(self: View): string {.slot.} =
    return self.threadId
  proc setThreadId*(self: View, value: string) {.slot.} =
    self.threadId = value
    self.threadIdChanged()

  QtProperty[string] threadId:
    read = getThreadId
    notify = threadIdChanged

  proc threadDetailsChanged*(self: View) {.signal.}
  proc getThreadName(self: View): string {.slot.} =
    self.threadName
  QtProperty[string] threadName:
    read = getThreadName
    notify = threadDetailsChanged

  proc getThreadParentChatName(self: View): string {.slot.} =
    self.threadParentChatName
  QtProperty[string] threadParentChatName:
    read = getThreadParentChatName
    notify = threadDetailsChanged

  proc getCanEditThread*(self: View): bool {.slot.} =
    self.canEditThread
  QtProperty[bool] canEditThread:
    read = getCanEditThread
    notify = threadDetailsChanged

  proc setThreadDetails*(self: View, name, parentChatName: string, canEdit: bool, deleted: bool = false) =
    if self.threadName == name and self.threadParentChatName == parentChatName and
        self.canEditThread == canEdit and self.threadDeleted == deleted:
      return
    self.threadName = name
    self.threadParentChatName = parentChatName
    self.canEditThread = canEdit
    self.threadDeleted = deleted
    self.threadDetailsChanged()

  proc getThreadDeleted*(self: View): bool {.slot.} =
    self.threadDeleted
  QtProperty[bool] threadDeleted:
    read = getThreadDeleted
    notify = threadDetailsChanged

  proc threadDeletePendingChanged*(self: View) {.signal.}
  proc getThreadDeletePending(self: View): bool {.slot.} = self.threadDeletePending
  QtProperty[bool] threadDeletePending:
    read = getThreadDeletePending
    notify = threadDeletePendingChanged
  proc setThreadDeletePending*(self: View, pending: bool) =
    if self.threadDeletePending == pending: return
    self.threadDeletePending = pending
    self.threadDeletePendingChanged()
  proc threadDeleteFinished*(self: View, error: string) {.signal.}
  proc emitThreadDeleteFinished*(self: View, error: string) = self.threadDeleteFinished(error)
  proc deleteThread*(self: View) {.slot.} = self.delegate.deleteThread()
  proc deleteThreadById*(self: View, threadId: string) {.slot.} = self.delegate.deleteThreadById(threadId)
  proc canManageThreadById*(self: View, threadId: string): bool {.slot.} = self.delegate.canManageThreadById(threadId)

  proc threadEditPendingChanged*(self: View) {.signal.}
  proc getThreadEditPending(self: View): bool {.slot.} =
    self.threadEditPending
  QtProperty[bool] threadEditPending:
    read = getThreadEditPending
    notify = threadEditPendingChanged

  proc setThreadEditPending*(self: View, pending: bool) =
    if self.threadEditPending == pending:
      return
    self.threadEditPending = pending
    self.threadEditPendingChanged()

  proc threadEditFinished*(self: View, error: string) {.signal.}
  proc emitThreadEditFinished*(self: View, error: string) =
    self.threadEditFinished(error)

  proc editThread*(self: View, name: string) {.slot.} =
    self.delegate.editThread(name)

  proc createThread*(self: View, parentMessageId: string) {.slot.} =
    self.delegate.createThread(parentMessageId)

  proc chatThreadsLoadingFailed*(self: View) {.signal.}
  proc emitChatThreadsLoadingFailedSignal*(self: View) =
    self.chatThreadsLoadingFailed()

  proc threadCreationFailed*(self: View) {.signal.}
  proc emitThreadCreationFailedSignal*(self: View) =
    self.threadCreationFailed()

  proc threadOpenRequested*(self: View, threadId: string, threadName: string) {.signal.}
  proc emitThreadOpenRequestedSignal*(self: View, threadId: string, threadName: string) =
    self.threadOpenRequested(threadId, threadName)

  proc getNumberOfPinnedMessages*(self: View): int {.slot.} =
    return self.delegate.getNumberOfPinnedMessages()

  proc loadMoreMessages*(self: View) {.slot.} =
    self.delegate.loadMoreMessages()

  # A loadMoreMessages() call has been answered: emitted once the fetched page
  # is in the model - even when it brought nothing or failed - and at once when
  # there is nothing left to fetch. Loads nobody asked for (the initial one)
  # emit it too.
  proc moreMessagesLoaded*(self: View) {.signal.}
  proc emitMoreMessagesLoadedSignal*(self: View) =
    self.moreMessagesLoaded()

  proc messageSuccessfullySent*(self: View) {.signal.}
  proc emitSendingMessageSuccessSignal*(self: View) =
    self.messageSuccessfullySent()

  proc sendingMessageFailed*(self: View, error: string) {.signal.}

  proc emitSendingMessageErrorSignal*(self: View, error: string) =
    self.sendingMessageFailed(error)

  proc reactionActionFailed*(self: View, addAction: bool, error: string) {.signal.}

  proc emitReactionActionFailedSignal*(self: View, addAction: bool, error: string) =
    self.reactionActionFailed(addAction, error)

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
    if self.hasThreadsModel():
      self.threadsVariant.delete()
      self.threads.delete()
      self.threadsVariant = nil
      self.threads = nil
    self.QObject.delete
