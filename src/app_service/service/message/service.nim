import nimqml, tables, json, regex, sequtils, std/strformat, strutils, chronicles, times, oids, uuids

import ../../../app/core/tasks/[qt, threadpool]
import ../../../app/core/signals/types
import ../../../app/core/eventemitter
import ../../../app/global/global_singleton
import ../../../backend/accounts as status_accounts
import ../../../backend/messages as status_go
import ../contacts/service as contact_service
import ../chat/service as chat_service
import ../token/service as token_service
import ../network/service as network_service
import ../wallet_account/service as wallet_account_service
import ./dto/message as message_dto
import ./dto/pinned_message as pinned_msg_dto
import ./dto/reaction as reaction_dto
import ../chat/dto/chat as chat_dto
import ./dto/pinned_message_update as pinned_msg_update_dto
import ./dto/removed_message as removed_msg_dto
import ./dto/urls_unfurling_plan
import ./dto/link_preview
import ./message_cursor

import app_service/common/activity_center
import app_service/common/message as message_common
import app_service/common/conversion as service_conversion
from app_service/common/account_constants import ZERO_ADDRESS

import web3/conversions

export message_dto
export pinned_msg_dto
export reaction_dto

logScope:
  topics = "messages-service"

const MESSAGES_PER_PAGE* = 20
const MESSAGES_PER_PAGE_MAX* = 40

# Signals which may be emitted by this service:
const SIGNAL_MESSAGES_LOADED* = "messagesLoaded"
const SIGNAL_PINNED_MESSAGES_LOADED* = "pinnedMessagesLoaded"
const SIGNAL_REACTIONS_FOR_MESSAGE_LOADED* = "signalReactionsForMessageLoaded"
const SIGNAL_FIRST_UNSEEN_MESSAGE_LOADED* = "firstUnseenMessageLoaded"
const SIGNAL_NEW_MESSAGE_RECEIVED* = "newMessageReceived"
const SIGNAL_MESSAGE_PINNED* = "messagePinned"
const SIGNAL_MESSAGE_UNPINNED* = "messageUnpinned"
const SIGNAL_SEARCH_MESSAGES_LOADED* = "searchMessagesLoaded"
const SIGNAL_MESSAGES_MARKED_AS_READ* = "messagesMarkedAsRead"
const SIGNAL_MESSAGE_REACTION_ADDED* = "messageReactionAdded"
const SIGNAL_MESSAGE_REACTION_REMOVED* = "messageReactionRemoved"
const SIGNAL_MESSAGE_REACTION_FROM_OTHERS* = "messageReactionFromOthers"
const SIGNAL_MESSAGE_REMOVED* = "messageRemoved"
const SIGNAL_MESSAGES_DELETED* = "messagesDeleted"
const SIGNAL_MESSAGE_DELIVERED* = "messageDelivered"
const SIGNAL_MESSAGE_EDITED* = "messageEdited"
const SIGNAL_ENVELOPE_SENT* = "envelopeSent"
const SIGNAL_ENVELOPE_EXPIRED* = "envelopeExpired"
const SIGNAL_RELOAD_MESSAGES* = "reloadMessages"
const SIGNAL_URLS_UNFURLED* = "urlsUnfurled"
const SIGNAL_GET_MESSAGE_FINISHED* = "getMessageFinished"
const SIGNAL_URLS_UNFURLING_PLAN_READY* = "urlsUnfurlingPlanReady"
const SIGNAL_MESSAGE_MARKED_AS_UNREAD* = "messageMarkedAsUnread"
const SIGNAL_COMMUNITY_MEMBER_ALL_MESSAGES* = "communityMemberAllMessages"

include async_tasks

type
  MessagesArgs* = ref object of Args
    sectionId*: string
    chatId*: string
    chatType*: ChatType
    lastMessageTimestamp*: int
    unviewedMessagesCount*: int
    unviewedMentionsCount*: int
    messages*: seq[MessageDto]

  MessagesLoadedArgs* = ref object of Args
    chatId*: string
    messages*: seq[MessageDto]
    reactions*: seq[ReactionDto]

  PinnedMessagesLoadedArgs* = ref object of Args
    chatId*: string
    pinnedMessages*: seq[PinnedMessageDto]
    reactions*: seq[ReactionDto]

  ReactionsLoadedArgs* = ref object of Args
    chatId*: string
    messageId*: string
    reactions*: seq[ReactionDto]

  MessagePinUnpinArgs* = ref object of Args
    chatId*: string
    messageId*: string
    actionInitiatedBy*: string

  MessageMarkMessageAsUnreadArgs* = ref object of Args
    chatId*: string
    messageId*: string
    messagesCount*: int
    messagesWithMentionsCount*: int

  MessagesMarkedAsReadArgs* = ref object of Args
    chatId*: string
    allMessagesMarked*: bool
    messagesIds*: seq[string]
    messagesCount*: int
    messagesWithMentionsCount*: int

  MessageAddRemoveReactionArgs* = ref object of Args
    chatId*: string
    messageId*: string
    emoji*: string
    reactionId*: string
    reactionFrom*: string

  MessageRemovedArgs* =  ref object of Args
    chatId*: string
    messageId*: string
    deletedBy*: string

  MessagesDeletedArgs* =  ref object of Args
    communityId*: string
    deletedMessages*: Table[string, seq[string]]

  MessageDeliveredArgs* = ref object of Args
    chatId*: string
    messageId*: string

  EnvelopeSentArgs* = ref object of Args
    messagesIds*: seq[string]

  EnvelopeExpiredArgs* = ref object of Args
    messagesIds*: seq[string]

  MessageEditedArgs* = ref object of Args
    chatId*: string
    message*: MessageDto

  UrlsUnfurlingPlanDataArgs* = ref object of Args
    plan*: UrlsUnfurlingPlan
    requestUuid*: string

  LinkPreviewDataArgs* = ref object of Args
    linkPreviews*: Table[string, LinkPreview]
    requestUuid*: string

  ReloadMessagesArgs* = ref object of Args
    communityId*: string

  FirstUnseenMessageLoadedArgs* = ref object of Args
    chatId*: string
    messageId*: string

  GetMessageResult* = ref object of Args
    requestId*: UUID
    messageId*: string
    message*: MessageDto
    error*: string

  CommunityMemberMessagesArgs* = ref object of Args
    communityId*: string
    messages*: seq[MessageDto]

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    chatService: chat_service.Service
    contactService: contact_service.Service
    tokenService: token_service.Service
    walletAccountService: wallet_account_service.Service
    networkService: network_service.Service
    msgCursor: Table[string, MessageCursor]
    pinnedMsgCursor: Table[string, MessageCursor]
    numOfPinnedMessagesPerChat: Table[string, int] # [chat_id, num_of_pinned_messages]

  proc bulkReplacePubKeysWithDisplayNames(self: Service, messages: var seq[MessageDto])

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    chatService: chat_service.Service,
    contactService: contact_service.Service,
    tokenService: token_service.Service,
    walletAccountService: wallet_account_service.Service,
    networkService: network_service.Service,
  ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.chatService = chatService
    result.contactService = contactService
    result.tokenService = tokenService
    result.walletAccountService = walletAccountService
    result.networkService = networkService
    result.msgCursor = initTable[string, MessageCursor]()
    result.pinnedMsgCursor = initTable[string, MessageCursor]()

  proc isChatCursorInitialized(self: Service, chatId: string): bool =
    return self.msgCursor.hasKey(chatId)

  proc resetMessageCursor*(self: Service, chatId: string) =
    if not self.msgCursor.hasKey(chatId):
      return
    self.msgCursor.del(chatId)

  proc resetAllMessageCursors*(self: Service) =
    self.msgCursor = initTable[string, MessageCursor]()
    self.pinnedMsgCursor = initTable[string, MessageCursor]()

  proc initOrGetMessageCursor(self: Service, chatId: string): MessageCursor =
    if(not self.msgCursor.hasKey(chatId)):
      self.msgCursor[chatId] = initMessageCursor(value="", pending=false, mostRecent=false)
    return self.msgCursor[chatId]

  proc initOrGetPinnedMessageCursor(self: Service, chatId: string): MessageCursor =
    if(not self.pinnedMsgCursor.hasKey(chatId)):
      self.pinnedMsgCursor[chatId] = initMessageCursor(value="", pending=false, mostRecent=false)

    return self.pinnedMsgCursor[chatId]

  proc checkPaymentRequestsInMessage*(self: Service, message: var MessageDto) =
    for paymentRequest in message.paymentRequests.mitems:
      if paymentRequest.tokenKey.len == 0 or paymentRequest.logoUri.len == 0:
        if paymentRequest.symbol.len > 0:
          # due to backward compatibility, in case the tokenKey is empty, we should try to find it by symbol on the received chain.
          let token = self.tokenService.getTokenBySymbolOnChain(paymentRequest.symbol, paymentRequest.chainId)
          if token.isNil:
            error "token is nil", tokenKey=paymentRequest.tokenKey, procName="checkPaymentRequestsInMessage"
            continue
          paymentRequest.tokenKey = token.key
          paymentRequest.symbol = token.symbol
          paymentRequest.logoUri = token.logoUri

  proc checkPaymentRequestsInMessages*(self: Service, messages: var seq[MessageDto]) =
    for message in messages.mitems:
      self.checkPaymentRequestsInMessage(message)

  proc checkPaymentRequestsInPinnedMessages*(self: Service, pinnedMessages: var seq[PinnedMessageDto]) =
    for pinnedMessage in pinnedMessages.mitems:
      self.checkPaymentRequestsInMessage(pinnedMessage.message)

  proc asyncLoadMoreMessagesForChat*(self: Service, chatId: string, limit = MESSAGES_PER_PAGE): bool =
    if (chatId.len == 0):
      error "empty chat id", procName="asyncLoadMoreMessagesForChat"
      return false

    let msgCursor = self.initOrGetMessageCursor(chatId)

    if msgCursor.isPending():
      return true

    if msgCursor.isMostRecent():
      return false

    let msgCursorValue = msgCursor.getValue()
    msgCursor.setPending()

    let arg = AsyncFetchChatMessagesTaskArg(
      tptr: asyncFetchChatMessagesTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncLoadMoreMessagesForChat",
      chatId: chatId,
      msgCursor: msgCursorValue,
      limit: if(limit <= MESSAGES_PER_PAGE_MAX): limit else: MESSAGES_PER_PAGE_MAX
    )

    self.threadpool.start(arg)
    return true

  proc onAsyncLoadReactionsForMessage*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj.kind != JObject:
        raise newException(CatchableError, "load reactions for message response is not a json object")

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId: string
      discard responseObj.getProp("chatId", chatId)

      var messageId: string
      discard responseObj.getProp("messageId", messageId)

     # handling reactions
      var reactions: seq[ReactionDto]
      var reactionsArr: JsonNode
      if responseObj.getProp("reactions", reactionsArr):
        reactions = map(
          reactionsArr.getElems(),
          proc(x: JsonNode): ReactionDto =
            result = x.toReactionDto()
        )

      let data = ReactionsLoadedArgs(chatId: chatId, messageId: messageId, reactions: reactions)

      self.events.emit(SIGNAL_REACTIONS_FOR_MESSAGE_LOADED, data)
    except Exception as e:
      error "Error load reactions for message async", msg = e.msg

  proc asyncLoadReactionsForMessage*(self: Service, chatId: string, messageId: string) =
    if chatId.len == 0 or messageId.len == 0:
      error "empty chat id or message id", procName="asyncLoadReactionsForMessage"
      return

    let arg = AsyncFetchReactionsForMessageTaskArg(
      tptr: asyncFetchReactionsForMessageTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncLoadReactionsForMessage",
      chatId: chatId,
      messageId: messageId
    )

    self.threadpool.start(arg)

  proc asyncLoadPinnedMessagesForChat*(self: Service, chatId: string) =
    if (chatId.len == 0):
      error "empty chat id", procName="asyncLoadPinnedMessagesForChat"
      return

    let pinnedMsgCursor = self.initOrGetPinnedMessageCursor(chatId)
    if not pinnedMsgCursor.isFetchable():
      return

    let pinnedMsgCursorValue = pinnedMsgCursor.getValue()
    pinnedMsgCursor.setPending()

    let arg = AsyncFetchChatMessagesTaskArg(
      tptr: asyncFetchPinnedChatMessagesTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncLoadPinnedMessagesForChat",
      chatId: chatId,
      msgCursor: pinnedMsgCursorValue,
      limit: MESSAGES_PER_PAGE_MAX
    )

    self.threadpool.start(arg)

  proc asyncLoadInitialMessagesForChat*(self: Service, chatId: string) =
    if self.isChatCursorInitialized(chatId):
      let data = MessagesLoadedArgs(chatId: chatId,
        messages: @[],
        reactions: @[])

      self.events.emit(SIGNAL_MESSAGES_LOADED, data)
      return

    discard self.asyncLoadMoreMessagesForChat(chatId)

  proc asyncLoadCommunityMemberAllMessages*(self: Service, communityId: string, memberPublicKey: string) =
    let arg = AsyncLoadCommunityMemberAllMessagesTaskArg(
      communityId: communityId,
      memberPubKey: memberPublicKey,
      tptr: asyncLoadCommunityMemberAllMessagesTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncLoadCommunityMemberAllMessages"
    )

    self.threadpool.start(arg)

  proc handleMessagesUpdate(self: Service, chats: var seq[ChatDto], messages: var seq[MessageDto]) =
    # We included `chats` in this condition cause that's the form how `status-go` sends updates.
    # The first element from the `receivedData.chats` array contains details about the chat a messages received in
    # `receivedData.messages` refer to.
    if(chats.len == 0):
      error "error: received `chats` array for handling messages update is empty"
      return

    if (not chats[0].active):
      return

    self.bulkReplacePubKeysWithDisplayNames(messages)
    self.checkPaymentRequestsInMessages(messages)

    for i in 0 ..< chats.len:
      let chatId = chats[i].id

      if(chats[i].chatType == ChatType.Unknown):
        error "error: new message with an unknown chat type received", chatId=chatId
        continue

      if self.chatService.getChatById(chats[i].id, showWarning = false).id == "":
        # Chat is not present in the chat cache. We need to add it first
        self.chatService.updateOrAddChat(chats[i])
        self.events.emit(SIGNAL_CHAT_UPDATE, ChatUpdateArgs(chats: chats))

      var chatMessages: seq[MessageDto]
      for msg in messages:
        if(msg.localChatId != chatId):
          continue

        # Ignore messages older than current chat cursor
        if self.isChatCursorInitialized(chatId):
          let currentChatCursor = self.initOrGetMessageCursor(chatId)
          let msgCursorValue = initCursorValue(msg.id, msg.clock)
          if(not currentChatCursor.isLessThan(msgCursorValue)):
            currentChatCursor.makeObsolete()
            continue

        if msg.editedAt > 0:
          let data = MessageEditedArgs(chatId: msg.localChatId, message: msg)
          self.events.emit(SIGNAL_MESSAGE_EDITED, data)
        else:
          chatMessages.add(msg)

      let data = MessagesArgs(
        sectionId: if chats[i].communityId.len != 0: chats[i].communityId else: singletonInstance.userProfile.getPubKey(),
        chatId: chatId,
        chatType: chats[i].chatType,
        lastMessageTimestamp: chats[i].timestamp.int,
        unviewedMessagesCount: chats[i].unviewedMessagesCount,
        unviewedMentionsCount: chats[i].unviewedMentionsCount,
        messages: chatMessages
      )
      self.events.emit(SIGNAL_NEW_MESSAGE_RECEIVED, data)

  proc getNumOfPinnedMessages*(self: Service, chatId: string): int =
    if(self.numOfPinnedMessagesPerChat.hasKey(chatId)):
      return self.numOfPinnedMessagesPerChat[chatId]
    return 0

  proc handlePinnedMessagesUpdate(self: Service, pinnedMessages: var seq[PinnedMessageUpdateDto]) =
    for pm in pinnedMessages:
      var chatId: string = ""
      if (self.numOfPinnedMessagesPerChat.contains(pm.localChatId)):
        # In 1-1 chats, the message's chatId is the localChatId
        chatId = pm.localChatId
      elif (self.numOfPinnedMessagesPerChat.contains(pm.chatId)):
        chatId = pm.chatId

      let data = MessagePinUnpinArgs(chatId: chatId, messageId: pm.messageId, actionInitiatedBy: pm.pinnedBy)
      if(pm.pinned):
        if (chatId != "" and pm.pinnedBy != singletonInstance.userProfile.getPubKey()):
          self.numOfPinnedMessagesPerChat[chatId] = self.getNumOfPinnedMessages(chatId) + 1
        self.events.emit(SIGNAL_MESSAGE_PINNED, data)
      else:
        if (chatId != "" and pm.pinnedBy != singletonInstance.userProfile.getPubKey()):
          self.numOfPinnedMessagesPerChat[chatId] = self.getNumOfPinnedMessages(chatId) - 1
        self.events.emit(SIGNAL_MESSAGE_UNPINNED, data)

  proc handleRemovedMessagesUpdate(self: Service, removedMessages: seq[RemovedMessageDto]) =
    for rm in removedMessages:
      let data = MessageRemovedArgs(chatId: rm.chatId, messageId: rm.messageId, deletedBy: rm.deletedBy)
      self.events.emit(SIGNAL_MESSAGE_REMOVED, data)

  proc handleDeletedMessagesUpdate(self: Service, deletedMessages: Table[string, seq[string]], communityId: string) =
      let data = MessagesDeletedArgs(deletedMessages: deletedMessages, communityId: communityId)
      self.events.emit(SIGNAL_MESSAGES_DELETED, data)

  proc handleEmojiReactionsUpdate(self: Service, emojiReactions: seq[ReactionDto]) =
    for r in emojiReactions:
      let data = MessageAddRemoveReactionArgs(chatId: r.localChatId, messageId: r.messageId,
      reactionId: r.id, reactionFrom: r.`from`, emoji: r.emoji)
      self.events.emit(SIGNAL_MESSAGE_REACTION_FROM_OTHERS, data)

  proc handleMessagesReload(self: Service, communityId: string) =
    var keys = newSeq[string]()
    for k in self.msgCursor.keys:
      if k.startsWith(communityId):
        keys.add(k)
    for k in keys:
      self.msgCursor.del(k)

    keys = @[]
    for k in self.pinnedMsgCursor.keys:
      if k.startsWith(communityId):
        keys.add(k)
    for k in keys:
      self.pinnedMsgCursor.del(k)

    self.events.emit(SIGNAL_RELOAD_MESSAGES, ReloadMessagesArgs(communityId: communityId))

  proc init*(self: Service) =
    self.events.on(SignalType.MessageDelivered.event) do(e: Args):
      let receivedData = MessageDeliveredSignal(e)
      let data = MessageDeliveredArgs(chatId: receivedData.chatId, messageId: receivedData.messageId)
      self.events.emit(SIGNAL_MESSAGE_DELIVERED, data)

    self.events.on(SignalType.EnvelopeSent.event) do(e: Args):
      let receivedData = EnvelopeSentSignal(e)
      let data = EnvelopeSentArgs(messagesIds: receivedData.messageIds)
      self.events.emit(SIGNAL_ENVELOPE_SENT, data)

    self.events.on(SignalType.EnvelopeExpired.event) do(e: Args):
      let receivedData = EnvelopeExpiredSignal(e)
      let data = EnvelopeExpiredArgs(messagesIds: receivedData.messageIds)
      self.events.emit(SIGNAL_ENVELOPE_EXPIRED, data)

    self.events.on(SIGNAL_APPEND_CHAT_MESSAGES) do(e: Args):
      let args = AppendChatMessagesArgs(e)

      if args.messages != nil and args.messages.kind != JNull:
        var messages: seq[MessageDto]
        messages = map(args.messages.getElems(), proc(x: JsonNode): MessageDto = x.toMessageDto())

        self.bulkReplacePubKeysWithDisplayNames(messages)
        self.checkPaymentRequestsInMessages(messages)

        self.events.emit(SIGNAL_MESSAGES_LOADED, MessagesLoadedArgs(
          chatId: args.chatId,
          messages: messages,
          reactions: @[],
        ))

    self.events.on(SignalType.Message.event) do(e: Args):
      var receivedData = MessageSignal(e)

      # Handling messages updates
      if (receivedData.messages.len > 0 and receivedData.chats.len > 0):
        self.handleMessagesUpdate(receivedData.chats, receivedData.messages)
      # Handling pinned messages updates
      if (receivedData.pinnedMessages.len > 0):
        self.handlePinnedMessagesUpdate(receivedData.pinnedMessages)
      # Handling removed messages updates
      if (receivedData.removedMessages.len > 0):
        self.handleRemovedMessagesUpdate(receivedData.removedMessages)
      # Handling deleted messages updates
      if (receivedData.deletedMessages.len > 0):
        self.handleDeletedMessagesUpdate(receivedData.deletedMessages, "")
      # Handling emoji reactions updates
      if (receivedData.emojiReactions.len > 0):
        self.handleEmojiReactionsUpdate(receivedData.emojiReactions)

    self.events.on(SignalType.DownloadingHistoryArchivesFinished.event) do(e: Args):
      var receivedData = HistoryArchivesSignal(e)
      self.handleMessagesReload(receivedData.communityId)

    self.events.on(SignalType.DiscordCommunityImportFinished.event) do(e: Args):
      var receivedData = DiscordCommunityImportFinishedSignal(e)
      self.handleMessagesReload(receivedData.communityId)

    self.events.on(SignalType.DiscordChannelImportFinished.event) do(e: Args):
      var receivedData = DiscordChannelImportFinishedSignal(e)
      self.resetMessageCursor(receivedData.channelId)
      discard self.asyncLoadMoreMessagesForChat(receivedData.channelId)

    self.events.on(SIGNAL_CHAT_LEFT) do(e: Args):
      var chatArg = ChatArgs(e)
      self.resetMessageCursor(chatArg.chatId)

    self.events.on(SignalType.LocalMessageBackupDone.event) do(e: Args):
      self.resetAllMessageCursors()

  proc getTransactionDetails*(self: Service, message: MessageDto): (string, string) =
    let chainIds = self.networkService.getCurrentNetworksChainIds()
    var token = self.tokenService.getTokenByChainAddress(chainIds[0], ZERO_ADDRESS)

    if message.transactionParameters.contract != "":
      for chainId in chainIds:
        let tokenFound = self.tokenService.getTokenByChainAddress(chainId, message.transactionParameters.contract)
        if tokenFound.isNil:
          continue

        token = tokenFound
        break

    let tokenStr = $(Json.encode(token))
    var weiStr = service_conversion.wei2Eth(message.transactionParameters.value, token.decimals)
    weiStr.trimZeros()
    return (tokenStr, weiStr)

  proc onAsyncLoadPinnedMessagesForChat*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj.kind != JObject:
        raise newException(CatchableError, "load pinned messages response is not a json object")

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId: string
      discard responseObj.getProp("chatId", chatId)

      let pinnedMsgCursor = self.initOrGetPinnedMessageCursor(chatId)
      # handling pinned messages
      var pinnedMsgCursorValue: string
      if(responseObj.getProp("pinnedMessagesCursor", pinnedMsgCursorValue)):
        pinnedMsgCursor.setValue(pinnedMsgCursorValue)

      var pinnedMsgArr: JsonNode
      var pinnedMessages: seq[PinnedMessageDto]
      if(responseObj.getProp("pinnedMessages", pinnedMsgArr)):
        pinnedMessages = map(pinnedMsgArr.getElems(), proc(x: JsonNode): PinnedMessageDto = x.toPinnedMessageDto())

      # set initial number of pinned messages
      self.numOfPinnedMessagesPerChat[chatId] = pinnedMessages.len

     # handling reactions
      var reactions: seq[ReactionDto]
      var reactionsArr: JsonNode
      if responseObj.getProp("reactions", reactionsArr):
        reactions = map(
          reactionsArr.getElems(),
          proc(x: JsonNode): ReactionDto =
            result = x.toReactionDto()
        )

      self.checkPaymentRequestsInPinnedMessages(pinnedMessages)

      let data = PinnedMessagesLoadedArgs(chatId: chatId, pinnedMessages: pinnedMessages, reactions: reactions)

      self.events.emit(SIGNAL_PINNED_MESSAGES_LOADED, data)
    except Exception as e:
      error "Error load pinned messages for chat async", msg = e.msg
      # notify view, this is important
      self.events.emit(SIGNAL_PINNED_MESSAGES_LOADED, PinnedMessagesLoadedArgs())

  proc onAsyncLoadMoreMessagesForChat*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj.kind != JObject:
        raise newException(CatchableError, "load more messages response is not a json object")

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId: string
      discard responseObj.getProp("chatId", chatId)

      let msgCursor = self.initOrGetMessageCursor(chatId)
      if msgCursor.getValue() == "":
        # this is the first time we load messages for this chat
        # we need to load pinned messages as well
        self.asyncLoadPinnedMessagesForChat(chatId)

      # handling messages
      var msgCursorValue: string
      if responseObj.getProp("messagesCursor", msgCursorValue):
        msgCursor.setValue(msgCursorValue)

      var messagesArr: JsonNode
      var messages: seq[MessageDto]
      if responseObj.getProp("messages", messagesArr):
        messages = map(messagesArr.getElems(), proc(x: JsonNode): MessageDto = x.toMessageDto())

      self.bulkReplacePubKeysWithDisplayNames(messages)
      self.checkPaymentRequestsInMessages(messages)

      # handling reactions
      var reactionsArr: JsonNode
      var reactions: seq[ReactionDto]
      if responseObj.getProp("reactions", reactionsArr):
        reactions = map(
          reactionsArr.getElems(),
          proc(x: JsonNode): ReactionDto =
            result = x.toReactionDto()
        )

      let data = MessagesLoadedArgs(
        chatId: chatId,
        messages: messages,
        reactions: reactions,
      )

      self.events.emit(SIGNAL_MESSAGES_LOADED, data)
    except Exception as e:
      error "Erorr load more messages for chat async", msg = e.msg
      # notify view, this is important
      self.events.emit(SIGNAL_MESSAGES_LOADED, MessagesLoadedArgs())

  proc onAsyncLoadCommunityMemberAllMessages*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      let errorString = rpcResponseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      if rpcResponseObj{"messages"}.kind == JNull:
        return
      if rpcResponseObj{"messages"}.kind != JArray:
        raise newException(RpcException, "invalid messages type in response")

      var communityId: string
      discard rpcResponseObj.getProp("communityId", communityId)

      var messages = map(rpcResponseObj{"messages"}.getElems(), proc(x: JsonNode): MessageDto = x.toMessageDto())
      if messages.len > 0:
        self.bulkReplacePubKeysWithDisplayNames(messages)
        self.checkPaymentRequestsInMessages(messages)

      let data = CommunityMemberMessagesArgs(communityId: communityId, messages: messages)
      self.events.emit(SIGNAL_COMMUNITY_MEMBER_ALL_MESSAGES, data)

    except Exception as e:
      error "error: ", procName="onAsyncLoadCommunityMemberAllMessages", errName = e.name, errDesription = e.msg

  proc addReaction*(self: Service, chatId: string, messageId: string, emoji: string) =
    try:
      let response = status_go.addReaction(chatId, messageId, emoji)

      let errorString = response.result{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var reactionsArr: JsonNode
      var reactions: seq[ReactionDto]
      if response.result.getProp("emojiReactions", reactionsArr):
        reactions = map(reactionsArr.getElems(), proc(x: JsonNode): ReactionDto = x.toReactionDto())

      var reactionId: string
      if reactions.len > 0:
        reactionId = reactions[0].id

      let data = MessageAddRemoveReactionArgs(chatId: chatId, messageId: messageId,
        reactionId: reactionId, emoji: emoji)
      self.events.emit(SIGNAL_MESSAGE_REACTION_ADDED, data)

    except Exception as e:
      error "error: ", procName="addReaction", errName = e.name, errDesription = e.msg

  proc removeReaction*(self: Service, reactionId: string, chatId: string, messageId: string, emoji: string) =
    try:
      let response = status_go.removeReaction(reactionId)

      let errorString = response.result{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      let data = MessageAddRemoveReactionArgs(chatId: chatId, messageId: messageId, emoji: emoji,
      reactionId: reactionId)
      self.events.emit(SIGNAL_MESSAGE_REACTION_REMOVED, data)

    except Exception as e:
      error "error: ", procName="removeReaction", errName = e.name, errDesription = e.msg

  proc pinUnpinMessage*(self: Service, chatId: string, messageId: string, pin: bool) =
    try:
      let response = status_go.pinUnpinMessage(chatId, messageId, pin)

      let errorString = response.result{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var pinMessagesObj: JsonNode
      if response.result.getProp("pinMessages", pinMessagesObj):
        let pinnedMessagesArr = pinMessagesObj.getElems()
        if pinnedMessagesArr.len > 0: # an array is returned
          let pinMessageObj = pinnedMessagesArr[0]
          var doneBy: string
          discard pinMessageObj.getProp("from", doneBy)
          let data = MessagePinUnpinArgs(chatId: chatId, messageId: messageId, actionInitiatedBy: doneBy)
          var pinned = false
          if pinMessageObj.getProp("pinned", pinned):
            if pinned and pin:
              self.numOfPinnedMessagesPerChat[chatId] = self.getNumOfPinnedMessages(chatId) + 1
              self.events.emit(SIGNAL_MESSAGE_PINNED, data)
          else:
            if not pinned and not pin:
              self.numOfPinnedMessagesPerChat[chatId] = self.getNumOfPinnedMessages(chatId) - 1
              self.events.emit(SIGNAL_MESSAGE_UNPINNED, data)
          discard self.chatService.processMessengerResponse(response)

    except Exception as e:
      error "error: ", procName="pinUnpinMessage", errName = e.name, errDesription = e.msg

  proc asyncMarkMessageAsUnread*(self: Service, chatId: string, messageId: string) =
    if (chatId.len == 0):
      error "empty chat id", procName="markAllMessagesRead"
      return

    let arg = AsyncMarkMessageAsUnreadTaskArg(
      tptr: asyncMarkMessageAsUnreadTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncMarkMessageAsUnread",
      messageId: messageId,
      chatId: chatId
    )
    self.threadpool.start(arg)

  proc getMessageByMessageId*(self: Service, messageId: string): GetMessageResult =
    try:
      result = GetMessageResult()
      let msgResponse = status_go.getMessageByMessageId(messageId)
      if not msgResponse.error.isNil:
        let error = Json.decode($msgResponse.error, RpcError)
        raise newException(RpcException, "Error resending chat message: " & error.message)

      result.message = msgResponse.result.toMessageDto()
      if result.message.id.len == 0:
        result.error = "message with id: " & messageId & " doesn't exist"
        return
    except Exception as e:
      result.error = e.msg
      error "error: ", procName="getMessageByMessageId", errName = e.name, errDesription = e.msg

  proc onAsyncGetMessageById*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj.kind != JObject:
        raise newException(RpcException, "getMessageById response is not an json object")

      var signalData = GetMessageResult(
        requestId: parseUUID(responseObj["requestId"].getStr),
        messageId: responseObj["messageId"].getStr,
        error: responseObj["error"].getStr,
      )

      if signalData.error == "":
        signalData.message = responseObj["message"].toMessageDto()

      if signalData.message.id.len == 0:
        signalData.error = "message doesn't exist"

      self.events.emit(SIGNAL_GET_MESSAGE_FINISHED, signalData)

    except Exception as e:
      error "response processing failed", procName="asyncGetMessageByMessageId", errName = e.name, errDesription = e.msg
      self.events.emit(SIGNAL_GET_MESSAGE_FINISHED, GetMessageResult( error: e.msg ))

  proc asyncGetMessageById*(self: Service, messageId: string): UUID =
    let requestId = genUUID()
    let arg = AsyncGetMessageByMessageIdTaskArg(
      tptr: asyncGetMessageByMessageIdTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncGetMessageById",
      requestId: $requestId,
      messageId: messageId,
    )
    self.threadpool.start(arg)
    return requestId

  proc onAsyncSearchMessages*(self: Service, response: string) {.slot.} =
    var chatId = ""
    try:
      let responseObj = response.parseJson
      if responseObj.kind != JObject:
        raise newException(CatchableError, "search messages response is not an json object")

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      discard responseObj.getProp("chatId", chatId)

      var messagesObj: JsonNode
      if (not responseObj.getProp("messages", messagesObj)):
        raise newException(CatchableError, "search messages response doesn't contain messages property")

      var messagesArray: JsonNode
      if (not messagesObj.getProp("messages", messagesArray)):
        raise newException(CatchableError, "search messages response doesn't contain messages array")

      if (messagesArray.kind notin {JArray, JNull}):
        raise newException(CatchableError, "expected messages json array is neither of JArray nor JNull type")

      var messages = map(messagesArray.getElems(), proc(x: JsonNode): MessageDto = x.toMessageDto())

      let data = MessagesArgs(chatId: chatId, messages: messages)
      self.events.emit(SIGNAL_SEARCH_MESSAGES_LOADED, data)
    except Exception as e:
      error "error: ", procName="onAsyncSearchMessages", errDescription = e.msg
      self.events.emit(SIGNAL_SEARCH_MESSAGES_LOADED, MessagesArgs(chatId: chatId))

  proc asyncSearchMessages*(self: Service, chatId: string, searchTerm: string, caseSensitive: bool) =
    ## Asynchronous search for messages which contain the searchTerm and belong to the chat with chatId.
    if (chatId.len == 0):
      error "error: empty channel id set for fetching more messages", procName="asyncSearchMessages"
      return

    if (searchTerm.len == 0):
      error "the searched term cannot be empty", procName="asyncSearchMessages"
      return

    let arg = AsyncSearchMessagesInChatTaskArg(
      tptr: asyncSearchMessagesInChatTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncSearchMessages",
      chatId: chatId,
      searchTerm: searchTerm,
      caseSensitive: caseSensitive
    )
    self.threadpool.start(arg)

  proc asyncSearchMessages*(self: Service, communityIds: seq[string], chatIds: seq[string], searchTerm: string,
    caseSensitive: bool) =
    ## Asynchronous search for messages which contain the searchTerm and belong to any chat/channel from chatIds array
    ## or any channel of community from communityIds array.

    if (communityIds.len == 0 and chatIds.len == 0):
      error "either community ids or chat ids or both must be set", procName="asyncSearchMessages"
      return

    if (searchTerm.len == 0):
      error "the searched term cannot be empty", procName="asyncSearchMessages"
      return

    let arg = AsyncSearchMessagesInChatsAndCommunitiesTaskArg(
      tptr: asyncSearchMessagesInChatsAndCommunitiesTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncSearchMessages",
      communityIds: communityIds,
      chatIds: chatIds,
      searchTerm: searchTerm,
      caseSensitive: caseSensitive
    )
    self.threadpool.start(arg)

  proc onMarkAllMessagesRead*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if (responseObj.kind != JObject):
        raise newException(CatchableError, "mark all messages read response is not an json object")

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId: string
      discard responseObj.getProp("chatId", chatId)

      let data = MessagesMarkedAsReadArgs(chatId: chatId, allMessagesMarked: true)
      self.events.emit(SIGNAL_MESSAGES_MARKED_AS_READ, data)
      checkAndEmitACNotificationsFromResponse(self.events, responseObj{"activityCenterNotifications"})
    except Exception as e:
      error "error: ", procName="onMarkAllMessagesRead", errDesription = e.msg
      self.events.emit(SIGNAL_SEARCH_MESSAGES_LOADED, MessagesArgs(chatId: ""))

  proc markAllMessagesRead*(self: Service, chatId: string) =
    if (chatId.len == 0):
      error "empty chat id", procName="markAllMessagesRead"
      return

    let arg = AsyncMarkAllMessagesReadTaskArg(
      tptr: asyncMarkAllMessagesReadTask,
      vptr: cast[uint](self.vptr),
      slot: "onMarkAllMessagesRead",
      chatId: chatId
    )

    self.threadpool.start(arg)

  proc onAsyncMarkMessageAsUnread*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson

      if responseObj.kind != JObject:
        raise newException(RpcException, "markMessageAsUnread response is not a json object")

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId, messageId: string
      var count, countWithMentions: int

      discard responseObj.getProp("chatId", chatId)
      discard responseObj.getProp("messageId", messageId)
      discard responseObj.getProp("messagesCount", count)
      discard responseObj.getProp("messagesWithMentionsCount", countWithMentions)

      let data = MessageMarkMessageAsUnreadArgs(
        chatId: chatId,
        messageId: messageId,
        messagesCount: count,
        messagesWithMentionsCount: countWithMentions
      )

      self.chatService.updateUnreadMessage(chatId, count, countWithMentions)

      self.events.emit(SIGNAL_MESSAGE_MARKED_AS_UNREAD, data)
      checkAndEmitACNotificationsFromResponse(self.events, responseObj{"activityCenterNotifications"})

    except Exception as e:
      error "error: ", procName="markMessageAsUnread", errName = e.name, errDesription = e.msg

  proc onMarkCertainMessagesRead*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId: string
      discard responseObj.getProp("chatId", chatId)

      var messagesIdsArr: JsonNode
      var messagesIds: seq[string]
      if(responseObj.getProp("messagesIds", messagesIdsArr)):
        for id in messagesIdsArr:
          messagesIds.add(id.getStr)

      var count: int
      discard responseObj.getProp("count", count)

      if count < len(messagesIds):
        warn "warning: ", procName="onMarkCertainMessagesRead", errDescription="not all messages has been marked as read"

      var countWithMentions: int
      discard responseObj.getProp("countWithMentions", countWithMentions)

      let data = MessagesMarkedAsReadArgs(
        chatId: chatId,
        allMessagesMarked: false,
        messagesIds: messagesIds,
        messagesCount: count,
        messagesWithMentionsCount: countWithMentions)
      self.events.emit(SIGNAL_MESSAGES_MARKED_AS_READ, data)
      checkAndEmitACNotificationsFromResponse(self.events, responseObj{"activityCenterNotifications"})
    except Exception as e:
      error "error: ", procName="onMarkCertainMessagesRead", errDesription = e.msg

  proc markCertainMessagesRead*(self: Service, chatId: string, messagesIds: seq[string]) =
    if (chatId.len == 0):
      error "empty chat id", procName="markCertainMessagesRead"
      return

    let arg = AsyncMarkCertainMessagesReadTaskArg(
      tptr: asyncMarkCertainMessagesReadTask,
      vptr: cast[uint](self.vptr),
      slot: "onMarkCertainMessagesRead",
      chatId: chatId,
      messagesIds: messagesIds
    )

    self.threadpool.start(arg)

  proc getAsyncFirstUnseenMessageId*(self: Service, chatId: string) =
    let arg = AsyncGetFirstUnseenMessageIdForTaskArg(
      tptr: asyncGetFirstUnseenMessageIdForTaskArg,
      vptr: cast[uint](self.vptr),
      slot: "onGetFirstUnseenMessageIdFor",
      chatId: chatId,
    )

    self.threadpool.start(arg)

  proc onGetFirstUnseenMessageIdFor*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson

      let errorString = responseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      var chatId: string
      discard responseObj.getProp("chatId", chatId)

      var messageId = ""
      discard responseObj.getProp("messageId", messageId)

      self.events.emit(SIGNAL_FIRST_UNSEEN_MESSAGE_LOADED, FirstUnseenMessageLoadedArgs(chatId: chatId, messageId: messageId))
    except Exception as e:
      error "error: ", procName="onGetFirstUnseenMessageIdFor", errName = e.name, errDesription = e.msg

  proc onAsyncGetTextURLsToUnfurl*(self: Service, responseString: string) {.slot.} =
    let response = responseString.parseJson()
    if response.kind != JObject:
      warn "expected response is not a json object", methodName = "onAsyncGetTextURLsToUnfurl"
      return
    let errMessage = response{"error"}.getStr()
    if errMessage != "":
      error "asyncGetTextURLsToUnfurl failed", errMessage
      return

    let args = UrlsUnfurlingPlanDataArgs(
      plan: toUrlUnfurlingPlan(response{"response"}),
      requestUuid: response{"requestUuid"}.getStr
    )
    self.events.emit(SIGNAL_URLS_UNFURLING_PLAN_READY, args)

  proc asyncGetTextURLsToUnfurl*(self: Service, text: string): string =
    let uuid = $genUUID()
    let arg = AsyncGetTextURLsToUnfurlTaskArg(
      tptr: asyncGetTextURLsToUnfurlTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncGetTextURLsToUnfurl",
      text: text,
      requestUuid: uuid,
    )
    self.threadpool.start(arg)
    return uuid

  proc onAsyncUnfurlUrlsFinished*(self: Service, response: string) {.slot.}=
    let responseObj = response.parseJson
    if responseObj.kind != JObject:
      warn "expected response is not a json object", methodName = "onAsyncUnfurlUrlsFinished"
      return

    let errMessage = responseObj{"error"}.getStr
    if errMessage != "":
      error "asyncUnfurlUrls failed", errMessage
      return

    var requestedUrlsArr: JsonNode
    var requestedUrls: seq[string]
    if responseObj.getProp("requestedUrls", requestedUrlsArr):
      requestedUrls = map(requestedUrlsArr.getElems(), proc(x: JsonNode): string = x.getStr)

    let unfurlResponse = responseObj["response"]

    var linkPreviews: Table[string, LinkPreview]
    var linkPreviewsArr: JsonNode
    var statusLinkPreviewsArr: JsonNode

    if unfurlResponse.getProp("linkPreviews", linkPreviewsArr):
      for element in linkPreviewsArr.getElems():
        let linkPreview = element.toLinkPreview(true)
        linkPreviews[linkPreview.url] = linkPreview

    if unfurlResponse.getProp("statusLinkPreviews", statusLinkPreviewsArr):
      for element in statusLinkPreviewsArr.getElems():
        let linkPreview = element.toLinkPreview(false)
        linkPreviews[linkPreview.url] = linkPreview

    for url in requestedUrls:
      if not linkPreviews.hasKey(url):
        linkPreviews[url] = initLinkPreview(url)

    let args = LinkPreviewDataArgs(
      linkPreviews: linkPreviews,
      requestUuid: responseObj["requestUuid"].getStr
    )
    self.events.emit(SIGNAL_URLS_UNFURLED, args)

  proc asyncUnfurlUrls*(self: Service, urls: seq[string]): string =
    if len(urls) == 0:
      return ""
    let uuid = $genUUID()
    let arg = AsyncUnfurlUrlsTaskArg(
      tptr: asyncUnfurlUrlsTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncUnfurlUrlsFinished",
      urls: urls,
      requestUuid: uuid,
    )
    self.threadpool.start(arg)
    return uuid

# See render-inline in status-mobile/src/status_im/ui/screens/chat/message/message.cljs
proc renderInline(self: Service, parsedText: ParsedText, communityChats: seq[ChatDto]): string =
  let value = escape_html(parsedText.literal)
    .multiReplace(("\r\n", "<br/>"))
    .multiReplace(("\n", "<br/>"))
    .multiReplace(("  ", "&nbsp;&nbsp;"))

  case parsedText.type:
    of "":
      result = value
    of PARSED_TEXT_CHILD_TYPE_CODE:
      result = fmt("<code>{value}</code>")
    of PARSED_TEXT_CHILD_TYPE_EMPH:
      result = fmt("<em>{value}</em>")
    of PARSED_TEXT_CHILD_TYPE_STRONG:
      result = fmt("<strong>{value}</strong>")
    of PARSED_TEXT_CHILD_TYPE_STRONG_EMPH:
      result = fmt(" <strong><em>{value}</em></strong> ")
    of PARSED_TEXT_CHILD_TYPE_MENTION:
      var id = value
      if isSystemMention(id):
        var tag = id
        for pair in SystemTagMapping:
          if pair[1] == "@" & id:
            tag = pair[0]
            break
        result = fmt("<a href=\"#\" class=\"mention\">{tag}</a>")
      else:
        if isCompressedPubKey(id):
          id = status_accounts.decompressPk(id).result
        let contactDto = self.contactService.getContactById(id)
        result = fmt("<a href=\"//{id}\" class=\"mention\">@{contactDto.userDefaultDisplayName()}</a>")
    of PARSED_TEXT_CHILD_TYPE_STATUS_TAG:
      result = fmt("<span>#{value}</span>")
      for chat in communityChats:
        if chat.name == value:
          result = fmt("<a href=\"#{value}\" class=\"status-tag\">#{value}</a>")
          break
    of PARSED_TEXT_CHILD_TYPE_DEL:
      result = fmt("<del>{value}</del>")
    of PARSED_TEXT_CHILD_TYPE_LINK:
      result = fmt("{parsedText.destination}")
    else:
      result = fmt(" {value} ")

# See render-block in status-mobile/src/status_im/ui/screens/chat/message/message.cljs
proc getRenderedText*(self: Service, parsedTextArray: seq[ParsedText], communityChats: seq[ChatDto]): string =
  for parsedText in parsedTextArray:
    case parsedText.type:
      of PARSED_TEXT_TYPE_PARAGRAPH:
        result = result & "<p>"
        for child in parsedText.children:
          result = result & self.renderInline(child, communityChats)
        result = result & "</p>"
      of PARSED_TEXT_TYPE_BLOCKQUOTE:
        result = result & "<blockquote>" & escape_html(parsedText.literal) & "</blockquote>"
      of PARSED_TEXT_TYPE_CODEBLOCK:
        result = result & "<code>" & escape_html(parsedText.literal) & "</code>"
    result = result.strip()

# Parses the message and returns the plain text representation of it.
# If the message is a sticker or an image with no text, it returns "🖼️".
proc getMessagesParsedPlainText*(self: Service, message: MessageDto, communityChats: seq[ChatDto]): string =
  if message.contentType == ContentType.BridgeMessage:
    return message.bridgeMessage.content
  if message.contentType == ContentType.Sticker or (message.contentType == ContentType.Image and len(message.text) == 0):
    return "🖼️"

  let renderedMessageText = self.getRenderedText(message.parsedText, communityChats)
  return singletonInstance.utils.plainText(renderedMessageText)

proc deleteMessage*(self: Service, messageId: string) =
  try:
    let response = status_go.deleteMessageAndSend(messageId)

    var removesMessagesObj: JsonNode
    if(not response.result.getProp("removedMessages", removesMessagesObj) or removesMessagesObj.kind != JArray):
      error "error: ", procName="removeMessage", errDesription = "no messages remove or it's not an array"
      return

    let removedMessagesArr = removesMessagesObj.getElems()
    if(removedMessagesArr.len == 0): # an array is returned
      error "error: ", procName="removeMessage", errDesription = "array has no message to remove"
      return

    let removedMessageObj = removedMessagesArr[0]
    var chat_Id, message_Id: string
    if not removedMessageObj.getProp("chatId", chat_Id) or not removedMessageObj.getProp("messageId", message_Id):
      error "error: ", procName="removeMessage", errDesription = "there is no set chat id or message id in response"
      return

    let data = MessageRemovedArgs(
      chatId: chat_Id,
      messageId: message_Id,
      deletedBy: singletonInstance.userProfile.getPubKey(),
    )
    self.events.emit(SIGNAL_MESSAGE_REMOVED, data)

  except Exception as e:
    error "error: ", procName="deleteMessage", errName = e.name, errDesription = e.msg

proc replacePubKeysWithDisplayNames*(self: Service, message: string): string =
  let allKnownContacts = self.contactService.getContactsByGroup(ContactsGroup.AllKnownContacts)
  return message_common.replacePubKeysWithDisplayNames(allKnownContacts, message)

proc bulkReplacePubKeysWithDisplayNames(self: Service, messages: var seq[MessageDto]) =
  let allKnownContacts = self.contactService.getContactsByGroup(ContactsGroup.AllKnownContacts)
  for i in 0..<messages.len:
    messages[i].text = message_common.replacePubKeysWithDisplayNames(allKnownContacts, messages[i].text)

proc editMessage*(self: Service, messageId: string, msg: string) =
  try:
    let allKnownContacts = self.contactService.getContactsByGroup(ContactsGroup.AllKnownContacts)
    let processedMsg = message_common.replaceMentionsWithPubKeys(allKnownContacts, msg)

    let response = status_go.editMessage(messageId, processedMsg)

    var messagesArr: JsonNode
    var messages: seq[MessageDto]
    if(response.result.getProp("messages", messagesArr) and messagesArr.kind == JArray):
      messages = map(messagesArr.getElems(), proc(x: JsonNode): MessageDto = x.toMessageDto())

    if(messages.len == 0):
      error "error: ", procName="editMessage", errDesription = "messages array is empty"
      return

    if messages[0].editedAt <= 0:
      error "error: ", procName="editMessage", errDesription = "message is not edited"
      return

    self.bulkReplacePubKeysWithDisplayNames(messages)

    let data = MessageEditedArgs(chatId: messages[0].chatId, message: messages[0])
    self.events.emit(SIGNAL_MESSAGE_EDITED, data)

  except Exception as e:
    error "error: ", procName="editMessage", errName = e.name, errDesription = e.msg

proc getWalletAccounts*(self: Service): seq[wallet_account_service.WalletAccountDto] =
  return self.walletAccountService.getWalletAccounts()

proc resendChatMessage*(self: Service, messageId: string): string =
  try:
    let response = status_go.resendChatMessage(messageId)

    if response.error != nil:
        let error = Json.decode($response.error, RpcError)
        raise newException(RpcException, "Error resending chat message: " & error.message)

    return
  except Exception as e:
    error "error: ", procName="resendChatMessage", errName = e.name, errDesription = e.msg
    return fmt"{e.name}: {e.msg}"

# TODO: would be nice to make it async but in this case we will need to show come spinner in the UI during deleting the message
proc deleteCommunityMemberMessages*(self: Service, communityId: string, memberPubKey: string, messageId: string, chatId: string) =
  try:
    let response = status_go.deleteCommunityMemberMessages(communityId, memberPubKey, messageId, chatId)

    let errorString = response.result{"error"}.getStr()
    if errorString != "":
      raise newException(CatchableError, errorString)

    var deletedMessages = initTable[string, seq[string]]()
    if response.result.contains("deletedMessages"):
      let deletedMessagesObj = response.result["deletedMessages"]
      for chatId, messageIdsArrayJson in deletedMessagesObj:
        if not deletedMessages.hasKey(chatId):
          deletedMessages[chatId] = @[]
        for messageId in messageIdsArrayJson:
          deletedMessages[chatId].add(messageId.getStr())

      self.handleDeletedMessagesUpdate(deletedMessages, communityId)

  except Exception as e:
    error "error: ", procName="deleteCommunityMemberMessages", errName = e.name, errDesription = e.msg

proc delete*(self: Service) =
  self.QObject.delete

