import std/[json, unittest]

import app_service/service/message/dto/thread

suite "thread dto":
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
