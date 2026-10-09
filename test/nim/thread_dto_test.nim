import std/[json, unittest]

import app_service/service/message/dto/thread

suite "thread dto":
  test "accepts batch thread data without participant previews":
    let dto = parseJson("""{
      "threadId": "thread-id",
      "chatId": "inactive-channel",
      "parentMessageId": "parent-id",
      "name": "Thread title",
      "unviewedMessagesCount": 2,
      "unviewedMentionsCount": 1,
      "messagesCount": 0,
      "participantsCount": 0,
      "participantsPreviewIds": null
    }""").toThreadDto()

    check(dto.threadId == "thread-id")
    check(dto.chatId == "inactive-channel")
    check(dto.parentMessageId == "parent-id")
    check(dto.name == "Thread title")
    check(dto.unviewedMessagesCount == 2)
    check(dto.unviewedMentionsCount == 1)
    check(dto.participantsPreviewIds.len == 0)
    check(dto.participantsCount == 0)

  test "parses participant total independently from displayed participants":
    let dto = parseJson("""{
      "threadId": "thread-id",
      "messagesCount": 12,
      "participantsCount": 8,
      "participantsPreviewIds": ["creator", "alice", "bob"]
    }""").toThreadDto()

    check(dto.threadId == "thread-id")
    check(dto.messagesCount == 12)
    check(dto.participantsCount == 8)
    check(dto.participantsPreviewIds == @["creator", "alice", "bob"])

  test "falls back to participant ids when the total is missing":
    let dto = parseJson("""{
      "participantsPreviewIds": ["creator", "alice"]
    }""").toThreadDto()

    check(dto.participantsCount == 2)

  test "accepts a missing last message":
    let dto = parseJson("""{
      "threadId": "empty-thread",
      "participantsPreviewIds": []
    }""").toThreadDto()

    check(dto.lastMessage.`from` == "")
    check(dto.lastMessage.text == "")
    check(dto.lastMessage.timestamp == 0)
