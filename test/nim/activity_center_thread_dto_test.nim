import std/[json, unittest]

import app_service/service/activity_center/dto/notification

suite "activity center thread metadata":
  test "mentions and replies use the notifying message thread":
    for notificationType in [ActivityCenterNotificationType.Mention, ActivityCenterNotificationType.Reply]:
      let dto = (%* {
        "type": notificationType.int,
        "threadName": "Release planning",
        "message": {"id": "message", "threadId": "thread"},
        "replyMessage": {"id": "quoted", "threadId": "other-thread"}
      }).toActivityCenterNotificationDto()
      check dto.threadId == "thread"
      check dto.threadName == "Release planning"

  test "legacy payloads and missing titles are accepted":
    let legacy = (%* {"type": 3, "message": {"id": "message"}}).toActivityCenterNotificationDto()
    check legacy.threadId == ""
    check legacy.threadName == ""
    let unnamed = (%* {"type": 4, "message": {"threadId": "thread"}}).toActivityCenterNotificationDto()
    check unnamed.threadId == "thread"
    check unnamed.threadName == ""

  test "quoted threads and unrelated notification types do not add context":
    for payload in [
      %* {"type": 4, "threadName": "Stale title", "message": {}, "replyMessage": {"threadId": "thread"}},
      %* {"type": 5, "threadName": "Ignored", "message": {"threadId": "thread"}},
      %* {"type": 3, "threadName": "Ignored", "message": nil}
    ]:
      let dto = payload.toActivityCenterNotificationDto()
      check dto.threadId == ""
      check dto.threadName == ""

  test "paginated responses preserve thread metadata":
    let (cursor, notifications) = parseActivityCenterNotifications(%* {
      "cursor": "next-page",
      "notifications": [{"type": 3, "threadName": "Planning", "message": {"threadId": "thread"}}]
    })
    check cursor == "next-page"
    check notifications.len == 1
    check notifications[0].threadName == "Planning"
