import std/[json, unittest]

import app/core/notifications/details

suite "OS notification details":
  test "round trips a thread message target":
    let details = NotificationDetails(
      notificationType: NotificationType.NewMessage,
      sectionId: "community-id",
      isCommunitySection: true,
      sectionActive: false,
      chatId: "chat-id",
      chatActive: false,
      messageId: "message-id",
      threadId: "thread-id",
    )

    let parsed = toNotificationDetails(parseJson($details.toJsonNode()))

    check(parsed.chatId == "chat-id")
    check(parsed.messageId == "message-id")
    check(parsed.threadId == "thread-id")

  test "accepts legacy identifiers without a thread":
    let parsed = toNotificationDetails(parseJson("""{
      "notificationType": 8,
      "sectionId": "section-id",
      "isCommunitySection": false,
      "sectionActive": false,
      "chatId": "chat-id",
      "chatActive": false,
      "isOneToOne": false,
      "isGroupChat": true,
      "messageId": "message-id"
    }"""))

    check(parsed.notificationType == NotificationType.NewMessage)
    check(parsed.threadId == "")
