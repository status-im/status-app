import app_service/service/chat/dto/chat as chat_dto

type
  EnrichedConversationType* = enum
    ectOneToOne = "oneToOne"
    ectGroup = "group"
    ectCommunity = "community"

  EnrichedNotificationPayload* = object
    title*, body*, identifier*, threadId*: string
    senderName*, senderId*: string
    avatarBase64*: string
    conversationName*: string
    conversationImageBase64*: string   # group/community icon (base64) for the speakableGroupName image
    deepLink*: string   # status-app:// URL; opens the conversation when the notification is tapped

proc conversationTypeFor*(chatType: chat_dto.ChatType, communityId: string): EnrichedConversationType =
  if communityId.len > 0:
    return ectCommunity
  if chatType == chat_dto.ChatType.PrivateGroupChat:
    return ectGroup
  return ectOneToOne
