import unittest, json
import app/modules/main/enriched_notification
import app_service/service/chat/dto/chat as chat_dto

suite "enriched notification payload":
  test "community wins over chat type":
    check conversationTypeFor(chat_dto.ChatType.PrivateGroupChat, "0xcommunity") == ectCommunity
  test "private group -> group":
    check conversationTypeFor(chat_dto.ChatType.PrivateGroupChat, "") == ectGroup
  test "one-to-one default":
    check conversationTypeFor(chat_dto.ChatType.OneToOne, "") == ectOneToOne
  test "toJson round-trips key fields":
    let p = EnrichedNotificationPayload(
      title: "t", body: "b", identifier: "abc", threadId: "0xconv",
      senderName: "Alice", senderId: "0xsender",
      avatarBase64: "data:image/png;base64,AAAA", conversationType: ectGroup,
      conversationName: "My Group", badgeKind: ebkImage, badgeUrl: "http://x/y")
    let j = parseJson(p.toJson())
    check j["conversationType"].getStr() == "group"
    check j["badgeKind"].getStr() == "image"
    check j["avatarBase64"].getStr() == "data:image/png;base64,AAAA"
