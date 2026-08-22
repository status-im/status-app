import json
import core, ../app_service/common/utils
import response_type
import ../app_service/service/message/message_window

export response_type

proc fetchMessages*(chatId: string, cursorVal: string, limit: int): RpcResponse[JsonNode] =
  let payload = %* [chatId, cursorVal, limit]
  result = callPrivateRPC("chatMessages".prefix, payload)

proc fetchMessagesAroundMessage*(chatId: string, messageId: string, limit: int): RpcResponse[JsonNode] =
  result = callPrivateRPC("chatMessagesAroundMessage".prefix, aroundMessageParams(chatId, messageId, limit))

proc fetchMessagesAtRank*(chatId: string, rank: int, limit: int): RpcResponse[JsonNode] =
  result = callPrivateRPC("chatMessagesAtRank".prefix, atRankParams(chatId, rank, limit))

proc fetchMessagesCount*(chatId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("chatMessagesCount".prefix, messagesCountParams(chatId))

proc fetchPinnedMessages*(chatId: string, cursorVal: string, limit: int): RpcResponse[JsonNode] =
  let payload = %* [chatId, cursorVal, limit]
  result = callPrivateRPC("chatPinnedMessages".prefix, payload)

proc addReaction*(chatId: string, messageId: string, emoji: string): RpcResponse[JsonNode] =
  let payload = %* [chatId, messageId, emoji]
  result = callPrivateRPC("sendEmojiReaction".prefix, payload)

proc removeReaction*(reactionId: string): RpcResponse[JsonNode] =
  let payload = %* [reactionId]
  result = callPrivateRPC("sendEmojiReactionRetraction".prefix, payload)

proc pinUnpinMessage*(chatId: string, messageId: string, pin: bool): RpcResponse[JsonNode] =
  let payload = %*[{
    "message_id": messageId,
    "pinned": pin,
    "chat_id": chatId
  }]
  result = callPrivateRPC("sendPinMessage".prefix, payload)

proc markMessageAsUnread*(chatId: string, messageId: string): RpcResponse[JsonNode] =
  let payload = %*[chatId, messageId]
  result = callPrivateRPC("markMessageAsUnread".prefix, payload)

proc getMessageByMessageId*(messageId: string): RpcResponse[JsonNode] =
  let payload = %* [messageId]
  result = callPrivateRPC("messageByMessageID".prefix, payload)

proc fetchReactionsForMessageWithId*(chatId: string, messageId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId, messageId]
  result = callPrivateRPC("emojiReactionsByChatIDMessageID".prefix, payload)

proc fetchAllMessagesFromChatWhichMatchTerm*(chatId: string, searchTerm: string, caseSensitive: bool):
  RpcResponse[JsonNode] =
  let payload = %* [chatId, searchTerm, caseSensitive]
  result = callPrivateRPC("allMessagesFromChatWhichMatchTerm".prefix, payload)

proc fetchAllMessagesFromChatsAndCommunitiesWhichMatchTerm*(communityIds: seq[string], chatIds: seq[string],
  searchTerm: string, caseSensitive: bool): RpcResponse[JsonNode] =
  let payload = %* [communityIds, chatIds, searchTerm, caseSensitive]
  result = callPrivateRPC("allMessagesFromChatsAndCommunitiesWhichMatchTerm".prefix, payload)

proc markAllMessagesFromChatWithIdAsRead*(chatId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId]
  result = callPrivateRPC("markAllRead".prefix, payload)

proc markCertainMessagesFromChatWithIdAsRead*(chatId: string, messageIds: seq[string]):
  RpcResponse[JsonNode] =
  let payload = %* [chatId, messageIds]
  result = callPrivateRPC("markMessagesRead".prefix, payload)

proc deleteMessageAndSend*(messageID: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("deleteMessageAndSend".prefix, %* [messageID])

proc editMessage*(messageId: string, msg: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("editMessage".prefix, %* [{"id": messageId, "text": msg}])

proc resendChatMessage*(messageId: string): RpcResponse[JsonNode] =
  result = callPrivateRPC("reSendChatMessage".prefix, %* [messageId])

proc firstUnseenMessageID*(chatId: string): RpcResponse[JsonNode] =
  let payload = %* [chatId]
  result = callPrivateRPC("firstUnseenMessageID".prefix, payload)

proc getCommunityMemberAllMessages*(communityId: string, memberPublicKey: string): RpcResponse[JsonNode] =
  let payload = %* [{"communityId": communityId, "memberPublicKey": memberPublicKey}]
  result = callPrivateRPC("getCommunityMemberAllMessages".prefix, payload)


proc deleteCommunityMemberMessages*(communityId: string, memberPubKey: string, messageId: string, chatId: string): RpcResponse[JsonNode] =
  var messages: seq[JsonNode] = @[]
  if messageId != "" and chatId != "":
    messages.add(%*{
      "id": messageId,
      "chat_id": chatId,
    })

  let payload = %* [{
    "communityId": communityId,
    "memberPubKey": memberPubKey,
    "messages": messages,
    "deleteAll": messages.len() == 0
    }]
  result = callPrivateRPC("deleteCommunityMemberMessages".prefix, payload)