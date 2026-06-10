import nimqml, tables, json, sequtils, chronicles, os, strutils, uuids, base64
import dotherside_ext
import std/[times, os]

import app/core/tasks/[qt, threadpool]
import ./dto/chat as chat_dto
import ../message/dto/message as message_dto
import ../message/dto/[link_preview, standard_link_preview, status_link_preview]
import ../message/dto/payment_request
import ../activity_center/dto/notification as notification_dto
import ../community/dto/community as community_dto
import ../contacts/service as contact_service
import backend/chat as status_chat
import backend/communities as status_communities
import backend/group_chat as status_group_chat
import app/global/[global_singleton, utils]
import app/core/eventemitter
import app/core/signals/types

import ../../common/message as message_common

export chat_dto

logScope:
  topics = "chat-service"

include ../../common/json_utils
include app/core/tasks/common
include async_tasks

type
  ChatUpdateArgs* = ref object of Args
    chats*: seq[ChatDto]

  CreatedChatArgs* = ref object of Args
    chat*: ChatDto

  ChatArgs* = ref object of Args
    communityId*: string # This param should be renamed to `sectionId`, that will avoid some confusions one may have.
    chatId*: string

  ChatExtArgs* = ref object of ChatArgs
    ensName*: string

  MessageSendingSuccess* = ref object of Args
    chat*: ChatDto
    message*: MessageDto

  MessageSendingFailure* = ref object of Args
    chatId*: string
    error*: string

  MessageArgs* = ref object of Args
    id*: string
    channel*: string

  ChatRenameArgs* = ref object of Args
    id*: string
    newName*: string

  ChatUpdateDetailsArgs* = ref object of Args
    id*: string
    newName*: string
    newColor*: string
    newImage*: string

  ChatMembersAddedArgs* = ref object of Args
    chatId*: string
    ids*: seq[string]

  ChatMemberRemovedArgs* = ref object of Args
    chatId*: string
    id*: string

  ChatMembersChangedArgs* = ref object of Args
    chatId*: string
    members*: seq[ChatMember]

  ChatMemberUpdatedArgs* = ref object of Args
    chatId*: string
    id*: string
    role*: MemberRole
    joined*: bool

  CheckChannelPermissionsResponseArgs* = ref object of Args
    communityId*: string
    chatId*: string
    checkChannelPermissionsResponse*: CheckChannelPermissionsResponseDto

  CheckAllChannelsPermissionsResponseArgs* = ref object of Args
    communityId*: string
    checkAllChannelsPermissionsResponse*: CheckAllChannelsPermissionsResponseDto

  CheckChannelsPermissionsErrorArgs* = ref object of Args
    communityId*: string
    error*: string

# Signals which may be emitted by this service:
const SIGNAL_ACTIVE_CHATS_LOADED* = "activeChatsLoaded"
const SIGNAL_CHATS_LOADING_FAILED* = "chatsLoadingFailed"
const SIGNAL_CHAT_UPDATE* = "chatUpdate"
const SIGNAL_CHAT_LEFT* = "channelLeft"
const SIGNAL_SENDING_FAILED* = "messageSendingFailed"
const SIGNAL_SENDING_SUCCESS* = "messageSendingSuccess"
const SIGNAL_MESSAGE_REMOVE* = "messageRemove"
const SIGNAL_CHAT_MUTED* = "chatMuted"
const SIGNAL_CHAT_UNMUTED* = "chatUnmuted"
const SIGNAL_CHAT_HISTORY_CLEARED* = "chatHistoryCleared"
const SIGNAL_CHAT_RENAMED* = "chatRenamed"
const SIGNAL_GROUP_CHAT_DETAILS_UPDATED* = "groupChatDetailsUpdated"
const SIGNAL_CHAT_MEMBERS_ADDED* = "chatMemberAdded"
const SIGNAL_CHAT_MEMBERS_CHANGED* = "chatMembersChanged"
const SIGNAL_CHAT_MEMBER_REMOVED* = "chatMemberRemoved"
const SIGNAL_CHAT_MEMBER_UPDATED* = "chatMemberUpdated"
const SIGNAL_CHAT_SWITCH_TO_OR_CREATE_1_1_CHAT* = "switchToOrCreateOneToOneChat"
const SIGNAL_CHAT_ADDED_OR_UPDATED* = "chatAddedOrUpdated"
const SIGNAL_CHAT_CREATED* = "chatCreated"
const SIGNAL_CHECK_CHANNEL_PERMISSIONS_RESPONSE* = "checkChannelPermissionsResponse"
const SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_RESPONSE* = "checkAllChannelsPermissionsResponse"
const SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_FAILED* = "checkAllChannelsPermissionsFailed"

QtObject:
  type Service* = ref object of QObject
    threadpool: ThreadPool
    events: EventEmitter
    chats: Table[string, ChatDto] # [chat_id, ChatDto]
    contactService: contact_service.Service
    # Read-only sentinel returned via `lent` borrow when a lookup misses.
    # Mutation is observable across all callers and will corrupt subsequent
    # miss results — never pass to procs that take `var T`.
    emptyChat: ChatDto

  proc delete*(self: Service)
  proc newService*(
      events: EventEmitter,
      threadpool: ThreadPool,
      contactService: contact_service.Service
    ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.contactService = contactService
    result.chats = initTable[string, ChatDto]()

  # Forward declarations
  proc updateOrAddChat*(self: Service, chat: ChatDto)
  proc processMessengerResponse*(self: Service, response: RpcResponse[JsonNode]): (seq[ChatDto], seq[MessageDto])
  proc getChatById*(self: Service, chatId: string, showWarning: bool = true): lent ChatDto

  proc parseChatsInMessengerResponse*(self: Service, chatsInResponse: seq[ChatDto]) =
    var chats: seq[ChatDto] = @[]
    for chatDto in chatsInResponse:
      if chatDto.active:
        var updatedChat = chatDto
        # Handling members update for non-community chats
        let isCommunityChat = chatDto.chatType == ChatType.CommunityChat
        if not isCommunityChat and self.chats.hasKey(chatDto.id) and self.chats[chatDto.id].members != chatDto.members:
          self.events.emit(SIGNAL_CHAT_MEMBERS_CHANGED, ChatMembersChangedArgs(chatId: chatDto.id, members: chatDto.members))

        if isCommunityChat and self.chats.hasKey(chatDto.id):
          updatedChat.updateMissingFields(self.chats[chatDto.id])

        chats.add(updatedChat)
        self.updateOrAddChat(updatedChat)

      elif self.chats.hasKey(chatDto.id) and self.chats[chatDto.id].active:
        # We left the chat
        self.events.emit(SIGNAL_CHAT_LEFT, ChatArgs(chatId: chatDto.id))

    self.events.emit(SIGNAL_CHAT_UPDATE, ChatUpdateArgs(chats: chats))

  proc doConnect(self: Service) =
    self.events.on(SignalType.Message.event) do(e: Args):
      var receivedData = MessageSignal(e)

      # Handling chat updates
      if (receivedData.chats.len > 0):
        self.parseChatsInMessengerResponse(receivedData.chats)

      if (receivedData.clearedHistories.len > 0):
        for clearedHistoryDto in receivedData.clearedHistories:
          self.events.emit(SIGNAL_CHAT_HISTORY_CLEARED, ChatArgs(chatId: clearedHistoryDto.chatId))

  proc asyncGetActiveChats*(self: Service) =
    let arg = AsyncGetActiveChatsTaskArg(
      tptr: asyncGetActiveChatsTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncGetActiveChatsResponse",
    )
    self.threadpool.start(arg)

  proc hydrateChats(self: Service, data: JsonNode) =
    for chatJson in data:
      let chat = chatJson.toChatDto()
      if chat.active and chat.chatType != chat_dto.ChatType.Unknown:
          self.chats[chat.id] = chat

  proc onAsyncGetActiveChatsResponse*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson

      if (rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != ""):
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      if rpcResponseObj["chats"].kind != JNull:
        self.hydrateChats(rpcResponseObj["chats"])

      self.events.emit(SIGNAL_ACTIVE_CHATS_LOADED, Args())
    except Exception as e:
      error "error get active chats: ", msg = e.msg
      self.events.emit(SIGNAL_CHATS_LOADING_FAILED, Args())

  proc init*(self: Service) =
    self.doConnect()

    self.asyncGetActiveChats()

  proc hasChannel*(self: Service, chatId: string): bool =
    self.chats.hasKey(chatId)

  proc sectionUnreadMessagesAndMentionsCount*(self: Service, sectionId: string, sectionIsMuted: bool):
      tuple[unviewedMessagesCount: int, unviewedMentionsCount: int] =

    result.unviewedMentionsCount = 0
    result.unviewedMessagesCount = 0

    let myPubKey = singletonInstance.userProfile.getPubKey()
    var sectionIdToFind = sectionId
    if sectionId == myPubKey:
      # If the section is the personal one (ID == pubKey), then we set the sectionIdToFind to ""
      # because personal chats have communityId == ""
      sectionIdToFind = ""
    for _, chat in self.chats:
      if chat.communityId != sectionIdToFind:
        continue
      result.unviewedMentionsCount += chat.unviewedMentionsCount
      # We count the unread messages if we are unmuted and it's not a mention, we want to show a badge on mentions
      if chat.unviewedMentionsCount == 0 and (chat.muted or sectionIsMuted):
        continue
      if chat.unviewedMessagesCount > 0:
        result.unviewedMessagesCount = result.unviewedMessagesCount + chat.unviewedMessagesCount

  proc updateOrAddChat*(self: Service, chat: ChatDto) =
    # status-go doesn't seem to preserve categoryIDs from chat
    # objects received via new messages. So we rely on what we
    # have in memory.

    if chat.id == "":
      return
    var categoryId = ""
    if self.chats.hasKey(chat.id):
      categoryId = self.chats[chat.id].categoryId
    self.chats[chat.id] = chat
    self.chats[chat.id].categoryId = categoryId
    self.events.emit(SIGNAL_CHAT_ADDED_OR_UPDATED, ChatArgs(communityId: chat.communityId, chatId: chat.id))

  proc updateChannelMembers*(self: Service, channel: ChatDto) =
    if not self.chats.hasKey(channel.id):
      return

    var chat = self.chats[channel.id]
    chat.members = channel.members
    self.updateOrAddChat(chat)
    self.events.emit(SIGNAL_CHAT_MEMBERS_CHANGED, ChatMembersChangedArgs(chatId: chat.id, members: chat.members))

  proc parseChatResponse*(self: Service, response: RpcResponse[JsonNode]): (seq[ChatDto], seq[MessageDto]) =
    var chats: seq[ChatDto] = @[]
    var messages: seq[MessageDto] = @[]
    let errDesription = response.result{"error"}.getStr
    if errDesription != "":
      error "Error in parseGroupChatResponse: ", errDesription
    else:
      if response.result{"messages"} != nil:
        for jsonMsg in response.result["messages"]:
          messages.add(jsonMsg.toMessageDto)
      if response.result{"chats"} != nil:
        for jsonChat in response.result["chats"]:
          let chat = chat_dto.toChatDto(jsonChat)
          # TODO add the channel back to `chat` when it is refactored
          self.updateOrAddChat(chat)
          chats.add(chat)
    return (chats, messages)

  proc signalChatsAndMessagesUpdates*(self: Service, chats: seq[ChatDto], messages: seq[MessageDto]) =
    if chats.len == 0 or messages.len == 0:
      error "no chats or messages in the parsed response"
      return
    for chat in chats:
      if chat.active:
        var existingChat = self.getChatById(chat.id)
        if existingChat.id == "" or not existingChat.active:
          # Chat is now created
          self.events.emit(SIGNAL_CHAT_CREATED, CreatedChatArgs(chat: chat))
    var chatMap: Table[string, ChatDto] = initTable[string, ChatDto]()
    for chat in chats:
      chatMap[chat.id] = chat
    for msg in messages:
      if chatMap.hasKey(msg.chatId):
        let chat = chatMap[msg.chatId]
        self.events.emit(SIGNAL_SENDING_SUCCESS, MessageSendingSuccess(message: msg, chat: chat))

  proc processMessengerResponse*(self: Service, response: RpcResponse[JsonNode]): (seq[ChatDto], seq[MessageDto]) =
    result = self.parseChatResponse(response)
    var (chats, messages) = result
    self.signalChatsAndMessagesUpdates(chats, messages)

  proc processGroupChatResponse*(self: Service, response: RpcResponse[JsonNode]) =
    proc parseGroupChatResponse(response: RpcResponse[JsonNode]): (ChatDto, seq[MessageDto], string) =
      var chat: ChatDto
      var messages: seq[MessageDto] = @[]

      let errorDescription = response.result{"error"}.getStr

      if response.result{"chat"} != nil:
        chat = chat_dto.toChatDto(response.result["chat"])
      if response.result{"messages"} != nil:
        for jsonMsg in response.result["messages"]:
          messages.add(jsonMsg.toMessageDto)
      return (chat, messages, errorDescription)

    var (chat, messages, errorDescription) = parseGroupChatResponse(response)
    if errorDescription != "":
      error "Received an error in the ProcessGroupChatResponse: ", errorDescription
    else:
      self.updateOrAddChat(chat)
      self.signalChatsAndMessagesUpdates(@[chat], messages)

  proc parseChatResponseAndEmit*(self: Service, response: RpcResponse[JsonNode]) =
    var (chats, _) = self.parseChatResponse(response)
    self.events.emit(SIGNAL_CHAT_UPDATE, ChatUpdateArgs(chats: chats))

  proc getAllChats*(self: Service): seq[ChatDto] =
    return toSeq(self.chats.values)

  proc getChatsOfChatTypes*(self: Service, types: seq[chat_dto.ChatType]): seq[ChatDto] =
    return self.getAllChats().filterIt(it.chatType in types)

  proc getChatsForPersonalSection*(self: Service): seq[ChatDto] =
    return self.getAllChats().filterIt(it.isActivePersonalChat())

  proc getChatsForCommunity*(self: Service, communityId: string): seq[ChatDto] =
    return self.getAllChats().filterIt(it.communityId == communityId)

  proc getChatById*(self: Service, chatId: string, showWarning: bool = true): lent ChatDto =
    if(not self.chats.contains(chatId)):
      if (showWarning):
        warn "trying to get chat data for an unexisting chat id", chatId
      return self.emptyChat

    return self.chats[chatId]

  proc getChatsByIds*(self: Service, chatIds: seq[string]): seq[ChatDto] =
    if chatIds.len == 0:
      return
    return self.getAllChats().filterIt(it.id in chatIds)

  proc getOneToOneChatNameAndImage*(self: Service, chatId: string):
      tuple[name: string, image: string, largeImage: string] =
    return self.contactService.getContactNameAndImage(chatId)

  proc createChatFromResponse(self: Service, response: RpcResponse[JsonNode]): tuple[chatDto: ChatDto, success: bool] =
    var jsonChat: JsonNode
    if (not response.result.getProp("chat", jsonChat)):
      error "error: response of creating chat doesn't contain created chats"
      result.success = false
      return

    result.chatDto = jsonChat.toChatDto()
    self.updateOrAddChat(result.chatDto)
    result.success = true

  proc createOneToOneChat*(self: Service, communityID: string, chatId: string, ensName: string): tuple[chatDto: ChatDto, success: bool] =
    try:
      if self.hasChannel(chatId):
        # We want to show the chat to the user and for that we activate the chat
        discard status_group_chat.createOneToOneChat(
          communityID,
          chatId,
          ensName=ensName)
        result.success = true
        result.chatDto = self.chats[chatId]
        return

      let response =  status_group_chat.createOneToOneChat(communityID, chatId, ensName)
      result = self.createChatFromResponse(response)
      if result.success:
        self.events.emit(SIGNAL_CHAT_CREATED, CreatedChatArgs(chat: result.chatDto))
    except Exception as e:
      let errDesription = e.msg
      error "error: ", errDesription
      return

  proc switchToOrCreateOneToOneChat*(self: Service, chatId: string, ensName: string) =
    self.events.emit(SIGNAL_CHAT_SWITCH_TO_OR_CREATE_1_1_CHAT, ChatExtArgs(chatId: chatId, ensName: ensName))

  proc leaveChat*(self: Service, chatId: string) =
    try:
      if self.chats.len == 0:
        return
      if(not self.chats.contains(chatId)):
        error "trying to leave chat for an unexisting chat id", chatId
        return

      let chat = self.chats[chatId]
      if chat.chatType == chat_dto.ChatType.PrivateGroupChat:
        let leaveGroupResponse = status_chat.leaveGroupChat(chatId)
        self.parseChatResponseAndEmit(leaveGroupResponse)

      discard status_chat.deactivateChat(chatId, preserveHistory = chat.chatType == chat_dto.ChatType.OneToOne)

      self.chats.del(chatId)
      self.events.emit(SIGNAL_CHAT_LEFT, ChatArgs(chatId: chatId))
    except Exception as e:
      error "Error deleting channel", chatId, msg = e.msg
      return

  proc asyncSendImages*(self: Service,
                   chatId: string,
                   imagePathsJson: string,
                   msg: string,
                   replyTo: string,
                   preferredUsername: string = "",
                   linkPreviews: seq[LinkPreview] = @[],
                   paymentRequests: seq[PaymentRequest] = @[]) =
    try:
      let (standardLinkPreviews, statusLinkPreviews) = extractLinkPreviewsLists(linkPreviews)

      let arg = AsyncSendImagesTaskArg(
        tptr: asyncSendImagesTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncSendImagesDone",
        chatId: chatId,
        imagePathsJson: imagePathsJson,
        msg: msg,
        replyTo: replyTo,
        preferredUsername: preferredUsername,
        standardLinkPreviews: %standardLinkPreviews,
        statusLinkPreviews: %statusLinkPreviews,
        paymentRequests: %paymentRequests,
      )

      self.threadpool.start(arg)
    except Exception as e:
      error "Error sending images", msg = e.msg
      self.events.emit(SIGNAL_SENDING_FAILED, MessageSendingFailure(chatId: chatId, error: e.msg))


  proc onAsyncSendImagesDone*(self: Service, rpcResponseJson: string) {.slot.} =
    let rpcResponseObj = rpcResponseJson.parseJson
    try:

      let errorString = rpcResponseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      let rpcResponse = Json.decode($rpcResponseObj["response"], RpcResponse[JsonNode])

      let (chats, messages) = self.processMessengerResponse(rpcResponse)
      if chats.len == 0 or messages.len == 0:
        raise newException(CatchableError, "no chat or message returned")
    except Exception as e:
      error "Error sending images", msg = e.msg
      self.events.emit(SIGNAL_SENDING_FAILED, MessageSendingFailure(chatId: rpcResponseObj["chatId"].getStr, error: e.msg))

  proc asyncSendChatMessage*(self: Service,
      chatId: string,
      msg: string,
      replyTo: string,
      contentType: int,
      preferredUsername: string = "",
      linkPreviews: seq[LinkPreview] = @[],
      paymentRequests: seq[PaymentRequest] = @[],
      communityId: string = "") =
    try:
      let allKnownContacts = self.contactService.getContactsByGroup(ContactsGroup.AllKnownContacts)
      let processedMsg = message_common.replaceMentionsWithPubKeys(allKnownContacts, msg)

      let (standardLinkPreviews, statusLinkPreviews) = extractLinkPreviewsLists(linkPreviews)

      let arg = AsyncSendMessageTaskArg(
        tptr: asyncSendMessageTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncSendMessageDone",
        chatId: chatId,
        processedMsg: processedMsg,
        replyTo: replyTo,
        contentType: contentType,
        preferredUsername: preferredUsername,
        communityId: communityId, # Only send a community ID for the community invites
        standardLinkPreviews: %standardLinkPreviews,
        statusLinkPreviews: %statusLinkPreviews,
        paymentRequests: %paymentRequests,
      )

      self.threadpool.start(arg)
    except Exception as e:
      error "Error sending message", msg = e.msg
      self.events.emit(SIGNAL_SENDING_FAILED, MessageSendingFailure(chatId: chatId, error: e.msg))

  proc onAsyncSendMessageDone*(self: Service, rpcResponseJson: string) {.slot.} =
    let rpcResponseObj = rpcResponseJson.parseJson
    try:

      let errorString = rpcResponseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      let rpcResponse = Json.decode($rpcResponseObj["response"], RpcResponse[JsonNode])
      
      let (chats, messages) = self.processMessengerResponse(rpcResponse)
      if chats.len == 0 or messages.len == 0:
        raise newException(CatchableError, "no chat or message returned")
    except Exception as e:
      error "Error sending message", msg = e.msg
      self.events.emit(SIGNAL_SENDING_FAILED, MessageSendingFailure(chatId: rpcResponseObj["chatId"].getStr, error: e.msg))

  proc muteChat*(self: Service, chatId: string, interval: int) =
    try:
      if(chatId.len == 0):
        error "error trying to mute chat with an empty id"
        return

      let response = status_chat.muteChat(chatId, interval)
      if(not response.error.isNil):
        let msg = response.error.message & " chatId=" & chatId
        error "error while mute chat ", msg
        return

      # There is no response except an error, so we can just modify the chat ourselves
      var chat = self.chats[chatID]
      chat.muted = true
      self.updateOrAddChat(chat)

      self.events.emit(SIGNAL_CHAT_MUTED, ChatArgs(chatId: chatId))
    except Exception as e:
      let errDesription = e.msg
      error "error: ", errDesription
      return

  proc unmuteChat*(self: Service, chatId: string) =
    try:
      if(chatId.len == 0):
        error "error trying to unmute chat with an empty id"
        return

      let response = status_chat.unmuteChat(chatId)
      if(not response.error.isNil):
        let msg = response.error.message & " chatId=" & chatId
        error "error while unmute chat ", msg
        return

      # There is no response except an error, so we can just modify the chat ourselves
      var chat = self.chats[chatID]
      chat.muted = false
      self.updateOrAddChat(chat)

      self.events.emit(SIGNAL_CHAT_UNMUTED, ChatArgs(chatId: chatId))
    except Exception as e:
      let errDesription = e.msg
      error "error: ", errDesription
      return

  proc clearChatHistory*(self: Service, chatId: string) =
    try:
      let response = status_chat.clearChatHistory(chatId)
      if(not response.error.isNil):
        let msg = response.error.message & " chatId=" & chatId
        error "error while clearing chat history ", msg
        return

      self.events.emit(SIGNAL_CHAT_HISTORY_CLEARED, ChatArgs(chatId: chatId))
    except Exception as e:
      let errDesription = e.msg
      error "error: ", errDesription
      return

  proc addGroupMembers*(self: Service, communityID: string, chatID: string, members: seq[string]) =
    try:
      let response = status_group_chat.addMembers(communityID, chatId, members)
      if (response.error.isNil):
        self.events.emit(SIGNAL_CHAT_MEMBERS_ADDED, ChatMembersAddedArgs(chatId: chatId, ids: members))
        self.processGroupChatResponse(response)
    except Exception as e:
      error "error while adding group members: ", msg = e.msg

  proc removeMemberFromGroupChat*(self: Service, communityID: string, chatID: string, member: string) =
    try:
      let response = status_group_chat.removeMember(communityID, chatId, member)
      if (response.error.isNil):
        self.events.emit(SIGNAL_CHAT_MEMBER_REMOVED, ChatMemberRemovedArgs(chatId: chatId, id: member))
        self.processGroupChatResponse(response)
    except Exception as e:
      error "error while removing member from group: ", msg = e.msg

  proc removeMembersFromGroupChat*(self: Service, communityID: string, chatID: string, members: seq[string]) =
      try:
        for member in members:
          self.removeMemberFromGroupChat(communityID, chatID, member)
      except Exception as e:
        error "error while removing members from group: ", msg = e.msg

  proc renameGroupChat*(self: Service, communityID: string, chatID: string, name: string) =
    try:
      let response = status_group_chat.renameChat(communityID, chatId, name)
      if (not response.error.isNil):
        let msg = response.error.message & " chatId=" & chatId
        error "error while renaming group chat", msg
        return

      var chat = self.chats[chatID]
      chat.name = name
      self.updateOrAddChat(chat)

      self.events.emit(SIGNAL_CHAT_RENAMED, ChatRenameArgs(id: chatId, newName: name))
    except Exception as e:
      error "error while renaming group chat: ", msg = e.msg

  proc updateGroupChatDetails*(self: Service, communityID: string, chatID: string, name: string, color: string, imageJson: string) =
    try:
      var parsedImage = imageJson.parseJson
      parsedImage["imagePath"] = %singletonInstance.utils.fromPathUri(parsedImage["imagePath"].getStr)
      let response = status_chat.editChat(communityID, chatID, name, color, $parsedImage)

      discard self.processMessengerResponse(response)

      let chat = self.chats[chatID]
      self.events.emit(SIGNAL_GROUP_CHAT_DETAILS_UPDATED, ChatUpdateDetailsArgs(id: chatID, newName: name, newColor: color, newImage: chat.icon))
    except Exception as e:
      error "error while updating group chat: ", msg = e.msg

  proc makeAdmin*(self: Service, communityID: string, chatID: string, memberId: string) =
    try:
      discard status_group_chat.makeAdmin(communityID, chatId, memberId)
      for member in self.chats[chatId].members.mitems:
        if (member.id == memberId):
          member.role = MemberRole.Admin
          self.events.emit(
            SIGNAL_CHAT_MEMBER_UPDATED,
            ChatMemberUpdatedArgs(id: member.id, role: member.role, chatId: chatId, joined: member.joined)
          )
          break
    except Exception as e:
      error "error while making user admin: ", msg = e.msg

  proc createGroupChat*(self: Service, communityID: string, name: string, members: seq[string]): tuple[chatDto: ChatDto, success: bool] =
    try:
      let response = status_group_chat.createGroupChat(communityID, name, members)
      result = self.createChatFromResponse(response)
      if result.success:
        self.events.emit(SIGNAL_CHAT_CREATED, CreatedChatArgs(chat: result.chatDto))
    except Exception as e:
      error "error while creating group chat", msg = e.msg

  proc updateUnreadMessage*(self: Service, chatID: string, messagesCount:int, messagesWithMentionsCount:int) =
    var chat = self.getChatById(chatID)
    if chat.id == "":
      return

    chat.unviewedMessagesCount = messagesCount
    chat.unviewedMentionsCount = messagesWithMentionsCount
    self.updateOrAddChat(chat)

  proc updateUnreadMessagesAndMentions*(self: Service, chatID: string, markAllAsRead: bool, markAsReadCount: int, markAsReadMentionsCount: int) =
    var chat = self.getChatById(chatID)
    if chat.id == "":
      return
    let previousUnreadMessagesCount = chat.unviewedMessagesCount
    let previousUnreadMentionsCount = chat.unviewedMentionsCount
    if markAllAsRead:
      chat.unviewedMessagesCount = 0
      chat.unviewedMentionsCount = 0
    else:
      chat.unviewedMessagesCount = max(0, chat.unviewedMessagesCount - markAsReadCount)
      chat.unviewedMentionsCount = max(0, chat.unviewedMentionsCount - markAsReadMentionsCount)

    if chat.unviewedMessagesCount == previousUnreadMessagesCount and
        chat.unviewedMentionsCount == previousUnreadMentionsCount:
      return

    self.updateOrAddChat(chat)

  proc asyncCheckChannelPermissions*(self: Service, communityId: string, chatId: string) =
    let arg = AsyncCheckChannelPermissionsTaskArg(
      tptr: asyncCheckChannelPermissionsTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCheckChannelPermissionsDone",
      communityId: communityId,
      chatId: chatId
    )

    self.threadpool.start(arg)

  proc onAsyncCheckChannelPermissionsDone*(self: Service, rpcResponse: string) {.slot.} =
    try:
      let rpcResponseObj = rpcResponse.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        let error = Json.decode($rpcResponseObj["error"], RpcError)
        error "Error checking community channel permissions", msg = error.message
        return

      let communityId = rpcResponseObj{"communityId"}.getStr()
      let chatId = rpcResponseObj{"chatId"}.getStr()
      let checkChannelPermissionsResponse = rpcResponseObj["response"].toCheckChannelPermissionsResponseDto()
      self.events.emit(SIGNAL_CHECK_CHANNEL_PERMISSIONS_RESPONSE, CheckChannelPermissionsResponseArgs(communityId: communityId, chatId: chatId, checkChannelPermissionsResponse: checkChannelPermissionsResponse))
    except Exception as e:
      let errMsg = e.msg
      error "error checking all channel permissions: ", errMsg

  proc asyncCheckAllChannelsPermissions*(self: Service, communityId: string, addresses: seq[string]) =
    let arg = AsyncCheckAllChannelsPermissionsTaskArg(
      tptr: asyncCheckAllChannelsPermissionsTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncCheckAllChannelsPermissionsDone",
      communityId: communityId,
      addresses: addresses,
    )

    self.threadpool.start(arg)

  proc onAsyncCheckAllChannelsPermissionsDone*(self: Service, rpcResponse: string) {.slot.} =
    let rpcResponseObj = rpcResponse.parseJson
    let communityId = rpcResponseObj{"communityId"}.getStr()
    try:
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj["error"].getStr)

      let checkAllChannelsPermissionsResponse = rpcResponseObj["response"].toCheckAllChannelsPermissionsResponseDto()
      # TODO save it
      self.events.emit(SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_RESPONSE, CheckAllChannelsPermissionsResponseArgs(communityId: communityId, checkAllChannelsPermissionsResponse: checkAllChannelsPermissionsResponse))
    except Exception as e:
      let errMsg = e.msg
      error "error checking all channels permissions: ", errMsg
      self.events.emit(SIGNAL_CHECK_ALL_CHANNELS_PERMISSIONS_FAILED, CheckChannelsPermissionsErrorArgs(
        communityId: communityId,
        error: errMsg,
      ))

  proc delete*(self: Service) =
    self.QObject.delete

