import json
import app_service/service/chat/dto/chat as chat_dto

type
  EnrichedConversationType* = enum
    ectOneToOne = "oneToOne"
    ectGroup = "group"
    ectCommunity = "community"

  EnrichedBadgeKind* = enum
    ebkStatus = "status"
    ebkImage = "image"

  EnrichedNotificationPayload* = object
    title*, body*, identifier*, threadId*: string
    senderName*, senderId*: string
    avatarBase64*, avatarUrl*: string
    conversationType*: EnrichedConversationType
    conversationName*: string
    badgeKind*: EnrichedBadgeKind
    badgeBase64*, badgeUrl*: string

proc conversationTypeFor*(chatType: chat_dto.ChatType, communityId: string): EnrichedConversationType =
  if communityId.len > 0:
    return ectCommunity
  if chatType == chat_dto.ChatType.PrivateGroupChat:
    return ectGroup
  return ectOneToOne

proc toJson*(p: EnrichedNotificationPayload): string =
  result = $(%* {
    "title": p.title, "body": p.body, "identifier": p.identifier, "threadId": p.threadId,
    "senderName": p.senderName, "senderId": p.senderId,
    "avatarBase64": p.avatarBase64, "avatarUrl": p.avatarUrl,
    "conversationType": $p.conversationType, "conversationName": p.conversationName,
    "badgeKind": $p.badgeKind, "badgeBase64": p.badgeBase64, "badgeUrl": p.badgeUrl,
  })
