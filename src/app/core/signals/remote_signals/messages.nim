import json, chronicles, tables

import base

import app_service/service/message/dto/[message, pinned_message_update, reaction, removed_message]
import app_service/service/chat/dto/[chat]
import app_service/service/bookmarks/dto/[bookmark]
import app_service/service/community/dto/[community]
import app_service/service/activity_center/dto/[notification]
import app_service/service/contacts/dto/[contacts, status_update]
import app_service/service/devices/dto/[installation]
import app_service/service/settings/dto/[settings]
import app_service/service/saved_address/dto as saved_address_dto
import app_service/service/wallet_account/dto/[keypair_dto]
import app_service/service/accounts/dto/[accounts]

include app_service/common/json_utils

type MessageSignal* = ref object of Signal
  bookmarks*: seq[BookmarkDto]
  messages*: seq[MessageDto]
  pinnedMessages*: seq[PinnedMessageUpdateDto]
  chats*: seq[ChatDto]
  contacts*: seq[ContactsDto]
  installations*: seq[InstallationDto]
  emojiReactions*: seq[ReactionDto]
  communities*: seq[CommunityDto]
  communitiesSettings*: seq[CommunitySettingsDto]
  membershipRequests*: seq[CommunityMembershipRequestDto]
  activityCenterNotifications*: seq[ActivityCenterNotificationDto]
  statusUpdates*: seq[StatusUpdateDto]
  removedMessages*: seq[RemovedMessageDto]
  deletedMessages*: Table[string, seq[string]]
  removedChats*: seq[string]
  currentStatus*: seq[StatusUpdateDto]
  settings*: seq[SettingsFieldDto]
  identityImages*: contacts.Images
  clearedHistories*: seq[ClearedHistoryDto]
  savedAddresses*: seq[SavedAddressDto]
  keypairs*: seq[KeypairDto]
  watchOnlyAccounts*: seq[WalletAccountDto]
  accountsPositions*: seq[WalletAccountDto]
  updatedProfileShowcaseContactIDs*: seq[string]

type MessageDeliveredSignal* = ref object of Signal
  chatId*: string
  messageId*: string

type NotificationReplySentSignal* = ref object of Signal
  ## Full successful JSON-RPC response from an Android notification reply.
  response*: JsonNode

proc fromEvent*(T: type MessageDeliveredSignal, event: JsonNode): MessageDeliveredSignal =
  result = MessageDeliveredSignal()
  result.signalType = SignalType.MessageDelivered
  result.chatId = event["event"]["chatID"].getStr
  result.messageId = event["event"]["messageID"].getStr

proc fromEvent*(T: type NotificationReplySentSignal, event: JsonNode): NotificationReplySentSignal =
  result = NotificationReplySentSignal()
  result.signalType = SignalType.NotificationReplySent
  result.response = if event.contains("event"): event["event"] else: newJNull()

proc fromEvent*(T: type MessageSignal, event: JsonNode): MessageSignal =
  var signal:MessageSignal = MessageSignal()
  signal.signalType = SignalType.Message
  signal.messages = @[]
  signal.contacts = @[]

  if not event.contains("event"):
    return signal

  let e = event["event"]

  if e.contains("contacts"):
    for jsonContact in e["contacts"]:
      signal.contacts.add(jsonContact.toContactsDto())

  if e.contains("messages"):
    for jsonMsg in e["messages"]:
      var message = jsonMsg.toMessageDto()
      signal.messages.add(message)
      info "received", signal="messages.new", messageID=message.id

  if e.contains("chats"):
    for jsonChat in e["chats"]:
      var chat = jsonChat.toChatDto()
      signal.chats.add(chat)

  if e.contains("clearedHistories"):
    for jsonClearedHistory in e["clearedHistories"]:
      var clearedHistoryDto = jsonClearedHistory.toClearedHistoryDto()
      signal.clearedHistories.add(clearedHistoryDto)

  if e.contains("statusUpdates"):
    for jsonStatusUpdate in e["statusUpdates"]:
      var statusUpdate = jsonStatusUpdate.toStatusUpdateDto()
      signal.statusUpdates.add(statusUpdate)

  if e.contains("currentStatus"):
      var currentStatus = e["currentStatus"].toStatusUpdateDto()
      signal.currentStatus.add(currentStatus)

  if e.contains("bookmarks"):
    for jsonBookmark in e["bookmarks"]:
      var bookmark = jsonBookmark.toBookmarkDto()
      signal.bookmarks.add(bookmark)

  if e.contains("installations"):
    for jsonDevice in e["installations"]:
      signal.installations.add(jsonDevice.toInstallationDto())

  if e.contains("emojiReactions"):
    for jsonReaction in e["emojiReactions"]:
      signal.emojiReactions.add(jsonReaction.toReactionDto())

  if e.contains("communities"):
    for jsonCommunity in e["communities"]:
      signal.communities.add(jsonCommunity.toCommunityDto())

  if e.contains("communitiesSettings"):
    for jsonCommunitySettings in e["communitiesSettings"]:
      signal.communitiesSettings.add(jsonCommunitySettings.toCommunitySettingsDto())

  if e.contains("requestsToJoinCommunity"):
    for jsonCommunity in e["requestsToJoinCommunity"]:
      signal.membershipRequests.add(jsonCommunity.toCommunityMembershipRequestDto())

  if e.contains("removedMessages"):
    for jsonRemovedMessage in e["removedMessages"]:
      signal.removedMessages.add(jsonRemovedMessage.toRemovedMessageDto())

  if e.contains("deletedMessages"):
    let deletedMessagesObj = e["deletedMessages"]
    for chatId, messageIdsArrayJson in deletedMessagesObj:
      if not signal.deletedMessages.hasKey(chatId):
        signal.deletedMessages[chatId] = @[]
      for messageId in messageIdsArrayJson:
        signal.deletedMessages[chatId].add(messageId.getStr())

  if e.contains("removedChats"):
    for removedChatID in e["removedChats"]:
      signal.removedChats.add(removedChatID.getStr())

  if e.contains("activityCenterNotifications"):
    for jsonNotification in e["activityCenterNotifications"]:
      signal.activityCenterNotifications.add(jsonNotification.toActivityCenterNotificationDto())

  if e.contains("pinMessages"):
    for jsonPinnedMessage in e["pinMessages"]:
      signal.pinnedMessages.add(jsonPinnedMessage.toPinnedMessageUpdateDto())

  if e.contains("settings"):
    for jsonSettingsField in e["settings"]:
      signal.settings.add(jsonSettingsField.toSettingsFieldDto())

  var imagesObj: JsonNode
  if e.getProp("identityImages", imagesObj):
    signal.identityImages = contacts.toImages(imagesObj)

  if e.contains("savedAddresses"):
    for jsonSavedAddress in e["savedAddresses"]:
      signal.savedAddresses.add(jsonSavedAddress.toSavedAddressDto())

  if e.contains("keypairs"):
    for jsonKc in e["keypairs"]:
      signal.keypairs.add(jsonKc.toKeypairDto())

  if e.contains("watchOnlyAccounts"):
    for jsonAcc in e["watchOnlyAccounts"]:
      signal.watchOnlyAccounts.add(jsonAcc.toWalletAccountDto())

  if e.contains("accountsPositions"):
    for jsonAcc in e["accountsPositions"]:
      signal.accountsPositions.add(jsonAcc.toWalletAccountDto())

  if e.contains("updatedProfileShowcaseContactIDs"):
    for contactId in e["updatedProfileShowcaseContactIDs"]:
      signal.updatedProfileShowcaseContactIDs.add(contactId.getStr())
  result = signal
